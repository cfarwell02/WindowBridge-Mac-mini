import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

final class H264Encoder {
    private let session: VTCompressionSession

    init(width: Int32, height: Int32) throws {
        var newSession: VTCompressionSession?

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &newSession
        )

        guard status == noErr, let newSession else {
            throw NSError(
                domain: "WindowBridge.Encoder",
                code: Int(status)
            )
        }

        self.session = newSession
    }

    func encode(_ pixelBuffer: CVPixelBuffer, at timestamp: CMTime) throws {
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: .invalid,
            frameProperties: nil,
            infoFlagsOut: nil
        ) { status, _, sampleBuffer in
            guard status == noErr, let sampleBuffer else {
                print("Encoding failed: \(status)")
                return
            }

            let bytes = CMSampleBufferGetTotalSampleSize(sampleBuffer)
            print("Encoded frame: \(bytes) bytes")
        }

        guard status == noErr else {
            throw NSError(
                domain: "WindowBridge.Encoder",
                code: Int(status)
            )
        }
    }

    deinit {
        VTCompressionSessionInvalidate(session)
    }
}
