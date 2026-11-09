import Foundation

struct MouseMoveMessage: Decodable {
    let type: MessageType
    let x: Double
    let y: Double

    enum MessageType: String, Decodable {
        case mouseMove
        case leftMouseDown
        case leftMouseUp
        case rightMouseDown
        case rightMouseUp
    }
}
