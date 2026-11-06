import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

final class H264Encoder {
    private let session: VTCompressionSession
    private let fileWriter: H264FileWriter?

    init(
        width: Int32,
        height: Int32,
        fileWriter: H264FileWriter? = nil
    ) throws {
        self.fileWriter = fileWriter
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
        let writer = fileWriter
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

            let attachments =
                CMSampleBufferGetSampleAttachmentsArray(
                    sampleBuffer,
                    createIfNecessary: false
                ) as? [CFDictionary]

            if let attachment = attachments?.first {
                let isKeyframe = !CFDictionaryContainsKey(
                    attachment,
                    Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque()
                )

                if isKeyframe {
                    print("H.264 KEYFRAME detected!")
                }
            }

            do {
                let annexB = try AnnexBConverter.convert(sampleBuffer)

                if let writer {
                    let attachments =
                        CMSampleBufferGetSampleAttachmentsArray(
                            sampleBuffer,
                            createIfNecessary: false
                        ) as? [CFDictionary]

                    let isKeyframe =
                        attachments?.first.map {
                            !CFDictionaryContainsKey(
                                $0,
                                Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque()
                            )
                        } ?? false

                    if isKeyframe,
                        let format = CMSampleBufferGetFormatDescription(sampleBuffer)
                    {
                        let headers = try AnnexBConverter.parameterSets(from: format)
                        try writer.append(headers)
                    }

                    try writer.append(annexB)
                }

                if annexB.starts(with: [0, 0, 0, 1]) {
                    print("Annex B conversion successful: \(annexB.count) bytes")
                } else {
                    print("Invalid Annex B start code")
                }
            } catch {
                print("Annex B conversion failed: \(error)")
            }

            if let format = CMSampleBufferGetFormatDescription(sampleBuffer) {
                var parameterSetCount = 0

                var nalUnitHeaderLength: Int32 = 0

                let result = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                    format,
                    parameterSetIndex: 0,
                    parameterSetPointerOut: nil,
                    parameterSetSizeOut: nil,
                    parameterSetCountOut: &parameterSetCount,
                    nalUnitHeaderLengthOut: &nalUnitHeaderLength
                )

                if result == noErr {
                    print(
                        "Parameter sets: \(parameterSetCount) | NAL length: \(nalUnitHeaderLength) bytes"
                    )

                    do {
                        let headers = try AnnexBConverter.parameterSets(from: format)

                        print("Extracted SPS/PPS: \(headers.count) bytes")

                        if headers.starts(with: [0, 0, 0, 1]) {
                            print("SPS/PPS Annex B formatting verified")
                        }
                    } catch {
                        print("Failed to extract SPS/PPS: \(error)")
                    }

                } else {
                    print("Failed to read H.264 metadata: \(result)")
                }
            }

        }

        guard status == noErr else {
            throw NSError(
                domain: "WindowBridge.Encoder",
                code: Int(status)
            )
        }
    }

    func finish() throws {
        let status = VTCompressionSessionCompleteFrames(
            session,
            untilPresentationTimeStamp: .invalid
        )

        guard status == noErr else {
            throw NSError(
                domain: "WindowBridge.Encoder",
                code: Int(status)
            )
        }

        print("H.264 encoder finished processing pending frames")
    }

    deinit {
        VTCompressionSessionInvalidate(session)
    }
}
