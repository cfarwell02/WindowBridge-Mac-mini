import CoreGraphics
import Foundation
import Network

final class TCPInputServer: @unchecked Sendable {
    private var activeInput: InputConnection?
    private let listener: NWListener

    private let queue = DispatchQueue(
        label: "com.windowbridge.input-server"
    )

    init(port: UInt16, windowFrame: CGRect) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(
                domain: "WindowBridge.InputServer",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid TCP port"
                ]
            )
        }

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: "127.0.0.1",
            port: nwPort
        )

        listener = try NWListener(using: parameters)

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Input server listening on port \(port)")
            case .failed(let error):
                print("Input server failed: \(error)")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }

            self.activeInput?.stop()

            let input = InputConnection(
                connection: connection,
                windowFrame: windowFrame
            )
            self.activeInput = input
            input.start()
        }
    }

    func start() {
        listener.start(queue: queue)
    }

    func stop() {
        queue.async {
            self.listener.cancel()
            self.activeInput?.stop()
            self.activeInput = nil
        }
    }
}
