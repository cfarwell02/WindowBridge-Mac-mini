import Foundation

final class H264FileWriter: @unchecked Sendable {
    private let fileHandle: FileHandle
    private let lock = NSLock()

    init(url: URL) throws {
        // Create an empty file, replacing any previous recording.
        try Data().write(to: url, options: .atomic)

        fileHandle = try FileHandle(forWritingTo: url)
    }

    func append(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        try fileHandle.write(contentsOf: data)
    }

    deinit {
        try? fileHandle.close()
    }
}
