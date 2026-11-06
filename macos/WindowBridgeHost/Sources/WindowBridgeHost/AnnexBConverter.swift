import CoreMedia
import Foundation

enum AnnexBConverter {
    static func convert(_ sampleBuffer: CMSampleBuffer) throws -> Data {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            throw NSError(domain: "WindowBridge", code: 1)
        }

        let totalLength = CMBlockBufferGetDataLength(blockBuffer)
        guard totalLength > 0 else {
            throw NSError(domain: "WindowBridge", code: 2)
        }

        var bytes = [UInt8](repeating: 0, count: totalLength)

        let status = bytes.withUnsafeMutableBytes { buffer in
            CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: totalLength,
                destination: buffer.baseAddress!
            )
        }

        guard status == noErr else {
            throw NSError(domain: "WindowBridge", code: Int(status))
        }

        return try convertAVCC(Data(bytes))
    }

    static func convertAVCC(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        let totalLength = bytes.count

        guard totalLength > 0 else {
            throw NSError(domain: "WindowBridge", code: 2)
        }

        var output = Data()
        var offset = 0

        while offset < totalLength {
            guard totalLength - offset >= 4 else {
                throw NSError(domain: "WindowBridge", code: 3)
            }

            var nalLength = 0

            for _ in 0..<4 {
                nalLength = (nalLength << 8) | Int(bytes[offset])
                offset += 1
            }

            guard nalLength > 0, nalLength <= totalLength - offset else {
                throw NSError(domain: "WindowBridge", code: 4)
            }

            output.append(contentsOf: [0, 0, 0, 1])
            output.append(contentsOf: bytes[offset..<(offset + nalLength)])

            offset += nalLength
        }

        return output
    }

    static func parameterSets(from format: CMFormatDescription) throws -> Data {
        var count = 0

        let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &count,
            nalUnitHeaderLengthOut: nil
        )

        guard status == noErr else {
            throw NSError(domain: "WindowBridge.H264", code: Int(status))
        }

        var output = Data()

        for index in 0..<count {
            var pointer: UnsafePointer<UInt8>?
            var size = 0

            let result = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                format,
                parameterSetIndex: index,
                parameterSetPointerOut: &pointer,
                parameterSetSizeOut: &size,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            )

            guard result == noErr, let pointer else {
                throw NSError(domain: "WindowBridge.H264", code: Int(result))
            }

            output.append(contentsOf: [0, 0, 0, 1])
            output.append(
                contentsOf: UnsafeBufferPointer(
                    start: pointer,
                    count: size
                ))
        }

        return output
    }

}
