import Foundation
import Network

final class TCPVideoServer: H264Output, @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(
        label: "com.windowbridge.tcp-server"
    )

    private var activeConnection: NWConnection?
    private var waitingForKeyframe = true

    init(port: UInt16) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(
                domain: "WindowBridge.TCP",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid TCP port"
                ]
            )
        }

        listener = try NWListener(
            using: .tcp,
            on: nwPort
        )

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("TCP server listening on port \(port)")

            case .failed(let error):
                print("TCP server failed: \(error)")

            case .cancelled:
                print("TCP server stopped")

            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }

            self.activeConnection?.cancel()
            self.activeConnection = connection
            self.waitingForKeyframe = true

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("TCP client connected")

                case .failed(let error):
                    print("TCP client failed: \(error)")

                case .cancelled:
                    print("TCP client disconnected")

                default:
                    break
                }
            }

            connection.start(queue: self.queue)
        }
    }

    func append(_ data: Data) throws {
        try appendFrame(data, isKeyframe: false)
    }

    func appendFrame(_ data: Data, isKeyframe: Bool) throws {
        queue.async { [weak self] in
            guard let self,
                let connection = self.activeConnection
            else {
                return
            }

            guard case .ready = connection.state else {
                return
            }

            if self.waitingForKeyframe {
                guard isKeyframe else { return }

                self.waitingForKeyframe = false
                print("Starting video client with headers and keyframe")
            }

            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error {
                        print("TCP video send failed: \(error)")
                        connection.cancel()
                    }
                }
            )
        }
    }

    func start() {
        listener.start(queue: queue)
    }

    func stop() {
        queue.async {
            self.activeConnection?.cancel()
            self.activeConnection = nil
            self.listener.cancel()
        }
    }
}
