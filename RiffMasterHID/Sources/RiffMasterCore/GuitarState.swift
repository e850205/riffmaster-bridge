/// Snapshot of every control on a RiffMaster guitar.
public struct GuitarState: Equatable, Sendable {
    public struct Frets: OptionSet, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }
        public static let green  = Frets(rawValue: 0x01)
        public static let red    = Frets(rawValue: 0x02)
        public static let yellow = Frets(rawValue: 0x04)
        public static let blue   = Frets(rawValue: 0x08)
        public static let orange = Frets(rawValue: 0x10)
    }

    public var frets: Frets = []
    public var strumUp = false
    public var strumDown = false
    public var dpadLeft = false
    public var dpadRight = false
    public var start = false
    public var select = false   // View button: star power
    public var share = false
    public var guide = false    // Xbox button
    public var whammy: UInt8 = 0
    public var tilt: UInt8 = 0

    public init() {}

    /// Returns the state after applying one GIP packet from the dongle,
    /// or nil if the packet carries no input.
    ///
    /// Type 0x20 (input), body = packet[4...]:
    ///   body[0] 0x04 start, 0x08 select     body[1] 0x02 up, 0x01 down, 0x04 left, 0x08 right
    ///   body[2] tilt   body[3] whammy       body[5] upper frets, body[6] solo frets
    ///   body[14] 0x01 share
    /// Type 0x07 (guide): packet[4] & 0x01 pressed.
    public func applying(packet: [UInt8]) -> GuitarState? {
        guard let type = packet.first else { return nil }
        var next = self
        switch type {
        case 0x07 where packet.count >= 5:
            next.guide = packet[4] & 0x01 != 0
        case 0x20 where packet.count >= 4 + 15:
            let body = Array(packet[4...])
            next.start = body[0] & 0x04 != 0
            next.select = body[0] & 0x08 != 0
            next.strumUp = body[1] & 0x02 != 0
            next.strumDown = body[1] & 0x01 != 0
            next.dpadLeft = body[1] & 0x04 != 0
            next.dpadRight = body[1] & 0x08 != 0
            next.tilt = body[2]
            next.whammy = body[3]
            next.frets = Frets(rawValue: (body[5] | body[6]) & 0x1f)
            next.share = body[14] & 0x01 != 0
        default:
            return nil
        }
        return next
    }
}
