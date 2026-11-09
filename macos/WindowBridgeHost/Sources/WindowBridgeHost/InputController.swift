import CoreGraphics
import Foundation

enum InputController {
    static func moveMouse(
        to position: CGPoint,
        dragging: Bool = false
    ) throws {
        guard CGPreflightPostEventAccess() else {
            throw NSError(
                domain: "WindowBridge.Input",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Input permission not granted"
                ]
            )
        }

        guard
            let event = CGEvent(
                mouseEventSource: nil,
                mouseType: dragging ? .leftMouseDragged : .mouseMoved,
                mouseCursorPosition: position,
                mouseButton: .left
            )
        else {
            throw NSError(
                domain: "WindowBridge.Input",
                code: 2
            )
        }

        event.post(tap: .cghidEventTap)
    }

    static func setLeftButton(
        pressed: Bool,
        at position: CGPoint
    ) throws {
        try setButton(
            right: false,
            pressed: pressed,
            at: position
        )
    }

    static func setRightButton(
        pressed: Bool,
        at position: CGPoint
    ) throws {
        try setButton(
            right: true,
            pressed: pressed,
            at: position
        )
    }

    private static func setButton(
        right: Bool,
        pressed: Bool,
        at position: CGPoint
    ) throws {
        guard CGPreflightPostEventAccess() else {
            throw NSError(
                domain: "WindowBridge.Input",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Input permission not granted"
                ]
            )
        }

        let eventType: CGEventType

        if right {
            eventType = pressed ? .rightMouseDown : .rightMouseUp
        } else {
            eventType = pressed ? .leftMouseDown : .leftMouseUp
        }

        guard
            let event = CGEvent(
                mouseEventSource: nil,
                mouseType: eventType,
                mouseCursorPosition: position,
                mouseButton: right ? .right : .left
            )
        else {
            throw NSError(
                domain: "WindowBridge.Input",
                code: 2
            )
        }

        event.setIntegerValueField(
            .mouseEventClickState,
            value: 1
        )
        event.post(tap: .cghidEventTap)
    }

    static func screenPosition(
        normalizedX: CGFloat,
        normalizedY: CGFloat,
        windowFrame: CGRect
    ) throws -> CGPoint {
        guard normalizedX.isFinite,
            normalizedY.isFinite,
            (0...1).contains(normalizedX),
            (0...1).contains(normalizedY),
            windowFrame.width > 0,
            windowFrame.height > 0
        else {
            throw NSError(
                domain: "WindowBridge.Input",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid mouse coordinates"
                ]
            )
        }

        return CGPoint(
            x: windowFrame.minX + normalizedX * windowFrame.width,
            y: windowFrame.minY + normalizedY * windowFrame.height
        )
    }

}
