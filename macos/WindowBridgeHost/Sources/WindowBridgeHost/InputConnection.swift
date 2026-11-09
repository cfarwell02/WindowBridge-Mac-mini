import CoreGraphics
import Foundation
import Network

final class InputConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let windowFrame: CGRect
    private let queue = DispatchQueue(
        label: "com.windowbridge.input-connection"
    )
    private var buffer = InputLineBuffer()
    private var isStopped = false
    private var leftButtonPressed = false
    private var rightButtonPressed = false
    private var lastPosition: CGPoint?

    init(connection: NWConnection, windowFrame: CGRect) {
        self.connection = connection
        self.windowFrame = windowFrame
    }

    func start() {
        connection.start(queue: queue)

        queue.async {
            self.receiveNext()
        }
    }

    func stop() {
        queue.async {
            self.stopOnQueue()
        }
    }

    private func stopOnQueue() {
        guard !isStopped else { return }
        isStopped = true

        if leftButtonPressed, let position = lastPosition {
            do {
                try InputController.setLeftButton(
                    pressed: false,
                    at: position
                )
                leftButtonPressed = false
                print("Released left button during cleanup")
            } catch {
                print("Could not release left button: \(error)")
            }
        }

        if rightButtonPressed, let position = lastPosition {
            do {
                try InputController.setRightButton(
                    pressed: false,
                    at: position
                )
                rightButtonPressed = false
                print("Released right button during cleanup")
            } catch {
                print("Could not release right button: \(error)")
            }
        }

        connection.cancel()
    }

    private func receiveNext() {
        guard !isStopped else { return }
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 4096
        ) { [self] data, _, isComplete, error in
            guard !isStopped else { return }
            if let data, !data.isEmpty {
                do {
                    let lines = try buffer.append(data)

                    for line in lines {
                        let message = try JSONDecoder().decode(
                            MouseMoveMessage.self,
                            from: line
                        )

                        let position = try InputController.screenPosition(
                            normalizedX: CGFloat(message.x),
                            normalizedY: CGFloat(message.y),
                            windowFrame: windowFrame
                        )

                        switch message.type {
                        case .mouseMove:
                            try InputController.moveMouse(
                                to: position,
                                dragging: leftButtonPressed
                            )
                            lastPosition = position

                        case .leftMouseDown:
                            guard !leftButtonPressed else { continue }

                            try InputController.setLeftButton(
                                pressed: true,
                                at: position
                            )
                            lastPosition = position
                            leftButtonPressed = true
                            print("Left button pressed")

                        case .leftMouseUp:
                            guard leftButtonPressed else { continue }

                            try InputController.setLeftButton(
                                pressed: false,
                                at: position
                            )
                            lastPosition = position
                            leftButtonPressed = false
                            print("Left button released")

                        case .rightMouseDown:
                            guard !rightButtonPressed else { continue }

                            try InputController.setRightButton(
                                pressed: true,
                                at: position
                            )
                            lastPosition = position
                            rightButtonPressed = true
                            print("Right button pressed")

                        case .rightMouseUp:
                            guard rightButtonPressed else { continue }

                            try InputController.setRightButton(
                                pressed: false,
                                at: position
                            )
                            lastPosition = position
                            rightButtonPressed = false
                            print("Right button released")

                        }

                    }
                } catch {
                    print("Invalid input: \(error)")
                    stopOnQueue()
                    return
                }
            }

            if let error {
                print("Input receive failed: \(error)")
                stopOnQueue()
                return
            }

            if isComplete {
                print("Input connection closed")
                stopOnQueue()
                return
            }

            receiveNext()
        }
    }
}
