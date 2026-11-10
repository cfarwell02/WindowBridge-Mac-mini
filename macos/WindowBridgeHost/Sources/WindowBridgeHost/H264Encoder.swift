import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

final class H264Encoder {
    private let session: VTCompressionSession
    private let fileWriter: H264Output?

    init(
        width: Int32,
        height: Int32,
        fileWriter: H264Output? = nil
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

        let properties: [(CFString, CFTypeRef)] = [
            (
                kVTCompressionPropertyKey_RealTime,
                kCFBooleanTrue
            ),
            (
                kVTCompressionPropertyKey_AllowFrameReordering,
                kCFBooleanFalse
            ),
            (
                kVTCompressionPropertyKey_MaxKeyFrameInterval,
                NSNumber(value: 60)
            ),
            (
                kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
                NSNumber(value: 1.0)
            ),
        ]

        for (key, value) in properties {
            let propertyStatus = VTSessionSetProperty(
                session,
                key: key,
                value: value
            )

            guard propertyStatus == noErr else {
                throw NSError(
                    domain: "WindowBridge.Encoder",
                    code: Int(propertyStatus),
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not set encoder property \(key)"
                    ]
                )
            }
        }
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

                    var frameData = Data()

                    if isKeyframe {
                        guard
                            let format =
                                CMSampleBufferGetFormatDescription(sampleBuffer)
                        else {
                            throw NSError(
                                domain: "WindowBridge.Encoder",
                                code: 1,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Keyframe is missing its format description"
                                ]
                            )
                        }

                        let headers = try AnnexBConverter.parameterSets(
                            from: format
                        )
                        frameData.append(headers)
                    }

                    frameData.append(annexB)

                    try writer.appendFrame(
                        frameData,
                        isKeyframe: isKeyframe
                    )
                }

            } catch {
                print("Annex B conversion failed: \(error)")
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
