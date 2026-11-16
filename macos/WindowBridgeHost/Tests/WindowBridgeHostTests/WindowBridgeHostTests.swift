import Foundation
import Testing

@testable import WindowBridgeHost

@Test func convertsSingleNALUnitToAnnexB() throws {
    let avcc = Data([
        0x00, 0x00, 0x00, 0x03,
        0x65, 0x88, 0x84,
    ])

    let expected = Data([
        0x00, 0x00, 0x00, 0x01,
        0x65, 0x88, 0x84,
    ])

    let actual = try AnnexBConverter.convertAVCC(avcc)

    #expect(actual == expected)
}

@Test func convertsMultipleNALUnitsToAnnexB() throws {
    let avcc = Data([
        0x00, 0x00, 0x00, 0x02,
        0x67, 0x42,

        0x00, 0x00, 0x00, 0x03,
        0x68, 0xCE, 0x06,
    ])

    let expected = Data([
        0x00, 0x00, 0x00, 0x01,
        0x67, 0x42,

        0x00, 0x00, 0x00, 0x01,
        0x68, 0xCE, 0x06,
    ])

    let actual = try AnnexBConverter.convertAVCC(avcc)

    #expect(actual == expected)
}

@Test func rejectsTruncatedNALLengthPrefix() {
    let malformed = Data([0x00, 0x00, 0x00])

    var didThrow = false

    do {
        _ = try AnnexBConverter.convertAVCC(malformed)
    } catch {
        didThrow = true
    }

    #expect(didThrow)
}

@Test func rejectsNALLengthLargerThanAvailablePayload() {
    let malformed = Data([
        0x00, 0x00, 0x00, 0x05,
        0x65, 0x88,
    ])

    var didThrow = false

    do {
        _ = try AnnexBConverter.convertAVCC(malformed)
    } catch {
        didThrow = true
    }

    #expect(didThrow)
}

@Test func mapsNormalizedCoordinatesToScreen() throws {
    let windowFrame = CGRect(
        x: 260,
        y: 105,
        width: 940,
        height: 750
    )

    let position = try InputController.screenPosition(
        normalizedX: 0.5,
        normalizedY: 0.5,
        windowFrame: windowFrame
    )

    #expect(position == CGPoint(x: 730, y: 480))
}

@Test func retainIncompleteData() throws {
    var buffer = InputLineBuffer()

    let firstLines = try buffer.append(Data("hel".utf8))
    #expect(firstLines.isEmpty)

    let secondLines = try buffer.append(Data("lo\n".utf8))
    #expect(secondLines == [Data("hello".utf8)])
}

@Test func splitMultipleMessagesInOneAppend() throws {
    var buffer = InputLineBuffer()

    let lines: [Data] = try buffer.append(Data("first\nsecond\n".utf8))
    #expect(lines == [Data("first".utf8), Data("second".utf8)])
}

@Test func rejectsOversizedMessageAcrossAppends() throws {
    var buffer = InputLineBuffer()

    let lines = try buffer.append(Data(repeating: 0x41, count: 4096))  // 4096 bytes of 'A'
    #expect(lines.isEmpty)

    var didThrow = false

    do {
        _ = try buffer.append(Data([0x41]))
    } catch {
        didThrow = true
    }

    #expect(didThrow)

}
