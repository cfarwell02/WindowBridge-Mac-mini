import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

final class FrameReceiver: NSObject, SCStreamOutput, @unchecked Sendable {
    private var frameCount = 0
    private var encoder: H264Encoder?
    private let output: H264Output?
    let frameQueue = DispatchQueue(label: "com.windowbridge.frames")
    private var latestFrame: CVPixelBuffer?
    private var idleTimer: DispatchSourceTimer?
    private let idleInterval: DispatchTimeInterval = .milliseconds(500)

    init(output: H264Output? = nil) {
        self.output = output
        super.init()
    }
    private var firstFrameTime: TimeInterval?
    private var completeFrameCount = 0

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen, sampleBuffer.isValid else {
            return
        }

        frameCount += 1

        let isComplete: Bool

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
            let rawStatus = attachments.first?[SCStreamFrameInfo.status] as? Int,
            SCFrameStatus(rawValue: rawStatus) == .complete
        {

            completeFrameCount += 1
            isComplete = true
        } else {
            isComplete = false
        }

        let now = ProcessInfo.processInfo.systemUptime

        if firstFrameTime == nil {
            firstFrameTime = now
        }

        guard isComplete else { return }

        if completeFrameCount == 1 {
            print("WindowBridge received its first video frame!")

            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

                print("Resolution: \(width)x\(height)")
                print("Pixel format: \(String(format, radix: 16))")

                do {

                    let destination: H264Output

                    if let output {
                        destination = output
                        print("H.264 output configured for network streaming")
                    } else {
                        let recordingURL = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Desktop/windowbridge-test.h264")

                        destination = try H264FileWriter(url: recordingURL)
                        print("Recording H.264 to: \(recordingURL.path)")
                    }

                    let encoder = try H264Encoder(
                        width: Int32(width),
                        height: Int32(height),
                        fileWriter: destination
                    )

                    self.encoder = encoder

                    try submitCapturedFrame(
                        pixelBuffer,
                        using: encoder,
                        capturedAt: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    )

                    print("Submitted first frame for H.264 encoding")
                } catch {
                    print("H.264 encoding error: \(error)")
                }

            }
        }

        if completeFrameCount > 1,
            let encoder,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        {

            do {
                try submitCapturedFrame(
                    pixelBuffer,
                    using: encoder,
                    capturedAt: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                )
            } catch {
                print("Failed to encode frame \(frameCount): \(error)")
            }
        }

    }

    func finishEncoding() throws {
        try frameQueue.sync {
            idleTimer?.cancel()
            idleTimer = nil
            latestFrame = nil

            guard let encoder else {
                print("No encoder to finalize")
                return
            }

            try encoder.finish()
        }
    }

    private func submitCapturedFrame(
        _ pixelBuffer: CVPixelBuffer,
        using encoder: H264Encoder,
        capturedAt: CMTime
    ) throws {
        guard output != nil else {
            try encoder.encode(pixelBuffer, at: capturedAt)
            return
        }

        try encodeLiveFrame(pixelBuffer, using: encoder)
        latestFrame = pixelBuffer

        let deadline = DispatchTime.now() + idleInterval
        if let idleTimer {
            idleTimer.schedule(deadline: deadline, repeating: idleInterval)
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: frameQueue)
        timer.schedule(deadline: deadline, repeating: idleInterval)
        timer.setEventHandler { [weak self] in
            self?.repeatLatestFrame()
        }
        idleTimer = timer
        timer.activate()
    }

    private func repeatLatestFrame() {
        guard let latestFrame, let encoder else { return }

        do {
            try encodeLiveFrame(latestFrame, using: encoder)
        } catch {
            print("Failed to encode idle frame: \(error)")
        }
    }

    private func encodeLiveFrame(
        _ pixelBuffer: CVPixelBuffer,
        using encoder: H264Encoder
    ) throws {
        let timestamp = CMClockGetTime(CMClockGetHostTimeClock())
        try encoder.encode(pixelBuffer, at: timestamp)
    }

}
