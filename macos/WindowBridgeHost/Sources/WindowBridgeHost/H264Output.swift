import Foundation

protocol H264Output: Sendable {
    func append(_ data: Data) throws
    func appendFrame(_ data: Data, isKeyframe: Bool) throws
}

extension H264Output {
    func appendFrame(_ data: Data, isKeyframe: Bool) throws {
        try append(data)
    }
}
