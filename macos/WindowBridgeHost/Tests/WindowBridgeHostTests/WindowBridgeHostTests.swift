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
