import Testing
@testable import RiffMasterCore

/// Builds a type 0x20 input packet: 4-byte GIP header + 32-byte body.
private func input(_ set: [Int: UInt8]) -> [UInt8] {
    var body = [UInt8](repeating: 0, count: 32)
    for (i, v) in set { body[i] = v }
    return [0x20, 0x00, 0x05, 0x20] + body
}

@Test func greenFretFromUpperFrets() {
    let s = GuitarState().applying(packet: input([0: 0x10, 5: 0x01]))
    #expect(s?.frets == .green)
}

@Test func soloFretsMergeWithUpperFrets() {
    let s = GuitarState().applying(packet: input([5: 0x01, 6: 0x10]))
    #expect(s?.frets == [.green, .orange])
}

@Test func strumUpAndAnalogAxes() {
    let s = GuitarState().applying(packet: input([1: 0x02, 2: 0xb2, 3: 0xff]))
    #expect(s?.strumUp == true)
    #expect(s?.strumDown == false)
    #expect(s?.whammy == 255)
    #expect(s?.tilt == 0xb2)
}

@Test func smallButtons() {
    let s = GuitarState().applying(packet: input([0: 0x0c, 14: 0x01]))
    #expect(s?.start == true)
    #expect(s?.select == true)
    #expect(s?.share == true)
}

@Test func guidePacketKeepsOtherState() {
    let held = GuitarState().applying(packet: input([5: 0x02]))!
    let pressed = held.applying(packet: [0x07, 0x20, 0xcb, 0x02, 0x01, 0x5b])
    #expect(pressed?.guide == true)
    #expect(pressed?.frets == .red)
    #expect(pressed?.applying(packet: [0x07, 0x20, 0xd4, 0x02, 0x00, 0x5b])?.guide == false)
}

@Test func unrelatedPacketsAreIgnored() {
    #expect(GuitarState().applying(packet: [0x03, 0x20, 0x01, 0x04, 0x89, 0x00, 0x00, 0x00]) == nil)
    #expect(GuitarState().applying(packet: []) == nil)
}

@Test func encodesButtonsHatAndAxes() {
    var s = GuitarState()
    s.frets = [.green, .orange]
    s.select = true
    s.guide = true
    s.strumUp = true
    s.whammy = 200
    s.tilt = 10
    #expect(Array(GamepadReport.encode(s)) == [0b0101_0001, 0b0000_0011, 0, 200, 10])
}

@Test func hatDirections() {
    func hat(up: Bool = false, down: Bool = false, left: Bool = false, right: Bool = false) -> UInt8 {
        var s = GuitarState()
        (s.strumUp, s.strumDown, s.dpadLeft, s.dpadRight) = (up, down, left, right)
        return GamepadReport.encode(s)[2]
    }
    #expect(hat() == 8)
    #expect(hat(up: true) == 0)
    #expect(hat(up: true, right: true) == 1)
    #expect(hat(right: true) == 2)
    #expect(hat(down: true) == 4)
    #expect(hat(left: true) == 6)
    #expect(hat(up: true, left: true) == 7)
}

@Test func descriptorDescribesFiveByteReport() {
    // 11 buttons + 5 pad + 4 hat + 4 pad + 2 × 8 axes = 40 bits
    #expect(GamepadReport.encode(GuitarState()).count == 5)
    #expect(GamepadReport.descriptor.first == 0x05 && GamepadReport.descriptor.last == 0xC0)
}
