import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

final class FrameReceiver: NSObject, SCStreamOutput {
    private var frameCount = 0
    private var encoder: H264Encoder?

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen, sampleBuffer.isValid else {
            return
        }

        frameCount += 1

        if frameCount == 1 {
            print("WindowBridge received its first video frame!")

            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

                print("Resolution: \(width)x\(height)")
                print("Pixel format: \(String(format, radix: 16))")

                do {
                    let encoder = try H264Encoder(
                        width: Int32(width),
                        height: Int32(height)
                    )

                    self.encoder = encoder

                    try encoder.encode(
                        pixelBuffer,
                        at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    )

                    print("Submitted first frame for H.264 encoding")
                } catch {
                    print("H.264 encoding error: \(error)")
                }

            }
        }

        if frameCount > 1,
            let encoder,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        {

            do {
                try encoder.encode(
                    pixelBuffer,
                    at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                )
            } catch {
                print("Failed to encode frame \(frameCount): \(error)")
            }
        }

    }
}
