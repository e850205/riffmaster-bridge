import Foundation

/// HID gamepad that the virtual device presents to games.
///
/// Input report (5 bytes, no report ID):
///   byte 0  bits 0-7  buttons 1-8: green, red, yellow, blue, orange, start, select, share
///   byte 1  bits 0-2  buttons 9-11: guide, strum up, strum down; bits 3-7 padding
///   byte 2  bits 0-3  hat switch (0 = up, clockwise in 45° steps, 8 = centred/null); bits 4-7 padding
///   byte 3            Z axis  = whammy (0-255)
///   byte 4            Rz axis = tilt   (0-255)
public enum GamepadReport {
    public static let descriptor = Data([
        0x05, 0x01,        // Usage Page (Generic Desktop)
        0x09, 0x05,        // Usage (Game Pad)
        0xA1, 0x01,        // Collection (Application)
        0x05, 0x09,        //   Usage Page (Button)
        0x19, 0x01,        //   Usage Minimum (1)
        0x29, 0x0B,        //   Usage Maximum (11)
        0x15, 0x00,        //   Logical Minimum (0)
        0x25, 0x01,        //   Logical Maximum (1)
        0x75, 0x01,        //   Report Size (1)
        0x95, 0x0B,        //   Report Count (11)
        0x81, 0x02,        //   Input (Data, Var, Abs)
        0x95, 0x05,        //   Report Count (5)
        0x81, 0x03,        //   Input (Const) padding
        0x05, 0x01,        //   Usage Page (Generic Desktop)
        0x09, 0x39,        //   Usage (Hat Switch)
        0x15, 0x00,        //   Logical Minimum (0)
        0x25, 0x07,        //   Logical Maximum (7)
        0x35, 0x00,        //   Physical Minimum (0)
        0x46, 0x3B, 0x01,  //   Physical Maximum (315)
        0x65, 0x14,        //   Unit (Degrees)
        0x75, 0x04,        //   Report Size (4)
        0x95, 0x01,        //   Report Count (1)
        0x81, 0x42,        //   Input (Data, Var, Abs, Null State)
        0x65, 0x00,        //   Unit (None)
        0x81, 0x03,        //   Input (Const) padding, 4 bits
        0x09, 0x32,        //   Usage (Z)
        0x09, 0x35,        //   Usage (Rz)
        0x15, 0x00,        //   Logical Minimum (0)
        0x26, 0xFF, 0x00,  //   Logical Maximum (255)
        0x35, 0x00,        //   Physical Minimum (0)
        0x46, 0xFF, 0x00,  //   Physical Maximum (255)
        0x75, 0x08,        //   Report Size (8)
        0x95, 0x02,        //   Report Count (2)
        0x81, 0x02,        //   Input (Data, Var, Abs)
        0xC0,              // End Collection
    ])

    public static func encode(_ s: GuitarState) -> Data {
        let low: [Bool] = [s.frets.contains(.green), s.frets.contains(.red), s.frets.contains(.yellow),
                           s.frets.contains(.blue), s.frets.contains(.orange), s.start, s.select, s.share]
        let high: [Bool] = [s.guide, s.strumUp, s.strumDown]
        return Data([bits(low), bits(high), hat(s), s.whammy, s.tilt])
    }

    private static func bits(_ flags: [Bool]) -> UInt8 {
        flags.enumerated().reduce(0) { $0 | ($1.element ? 1 << $1.offset : 0) }
    }

    private static func hat(_ s: GuitarState) -> UInt8 {
        let x = (s.dpadRight ? 1 : 0) - (s.dpadLeft ? 1 : 0)
        let y = (s.strumDown ? 1 : 0) - (s.strumUp ? 1 : 0)
        switch (x, y) {
        case (0, -1):  return 0   // up
        case (1, -1):  return 1
        case (1, 0):   return 2   // right
        case (1, 1):   return 3
        case (0, 1):   return 4   // down
        case (-1, 1):  return 5
        case (-1, 0):  return 6   // left
        case (-1, -1): return 7
        default:       return 8   // centred (out of range = null state)
        }
    }
}
