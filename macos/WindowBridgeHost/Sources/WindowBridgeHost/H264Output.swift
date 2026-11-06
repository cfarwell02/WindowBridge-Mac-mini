import Foundation

protocol H264Output: Sendable {
    func append(_ data: Data) throws
}
