// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import ScreenCaptureKit

do {
    let content = try await SCShareableContent.excludingDesktopWindows(
        false,
        onScreenWindowsOnly: true
    )

    let xcodeWindows = content.windows.filter {
        $0.owningApplication?.bundleIdentifier == "com.apple.dt.Xcode"
    }

    for window in xcodeWindows {
        print("Window ID: \(window.windowID)")
        print("Title: \(window.title ?? "Untitled")")
        print("Size: \(Int(window.frame.width)) x \(Int(window.frame.height))")
    }

    if xcodeWindows.isEmpty {
        print("No Xcode windows found.")
    }

    if let window = xcodeWindows.first {
        if #available(macOS 14.0, *) {

            guard let display = content.displays.first else {
                fatalError("No available display found")
            }

            let filter = SCContentFilter(display: display, including: [window])

            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width)
            config.height = Int(window.frame.height)

            let image: CGImage = try await withCheckedThrowingContinuation { continuation in
                SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                ) { image, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "WindowBridgeHost",
                                code: 1,
                                userInfo: [
                                    NSLocalizedDescriptionKey: "Screenshot returned no image"
                                ]
                            ))
                    }
                }
            }

            if let png = NSBitmapImageRep(cgImage: image)
                .representation(using: .png, properties: [:])
            {

                let url = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Desktop/windowbridge-test.png")

                try png.write(to: url)
                print("Screenshot saved: \(url.path)")
            }

            let receiver = FrameReceiver()

            let stream = SCStream(
                filter: filter,
                configuration: config,
                delegate: nil
            )

            try stream.addStreamOutput(
                receiver,
                type: .screen,
                sampleHandlerQueue: DispatchQueue(label: "com.windowbridge.frames")
            )

            let startCapture: () async throws -> Void = stream.startCapture
            try await startCapture()

            print("Capturing Xcode for 5 seconds...")
            try await Task.sleep(for: .seconds(5))

            let stopCapture: () async throws -> Void = stream.stopCapture
            try await stopCapture()

            print("Capture stopped.")

        }
    }

} catch {
    print("Failed to discover windows: \(error)")
}
