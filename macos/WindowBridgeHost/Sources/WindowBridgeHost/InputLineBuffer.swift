import Foundation

struct InputLineBuffer {
    private var pending = Data()
    private let maximumLineBytes = 4096

    mutating func append(_ data: Data) throws -> [Data] {
        var lines: [Data] = []

        for byte in data {
            if byte == 0x0A {
                if !pending.isEmpty {
                    lines.append(pending)
                }
                pending = Data()
            } else {
                guard pending.count < maximumLineBytes else {
                    throw NSError(
                        domain: "WindowBridge.Input",
                        code: 4,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Input message too large"
                        ]
                    )
                }

                pending.append(byte)
            }
        }

        return lines
    }
}
