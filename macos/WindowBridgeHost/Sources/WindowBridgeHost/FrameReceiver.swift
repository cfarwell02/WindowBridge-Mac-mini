import CoreMedia
import Foundation
import ScreenCaptureKit

final class FrameReceiver: NSObject, SCStreamOutput {
    private var frameCount = 0

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen, sampleBuffer.isValid else {
            return
        }

        frameCount += 1

        if frameCount == 1 {
            print("WindowBridge received its first video frame!")
        }
    }
}
