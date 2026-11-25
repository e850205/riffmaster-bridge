import CLibUSB

/// Physical USB position of a dongle; stable while it stays plugged into the same port.
struct DongleLocation: Hashable, Sendable, CustomStringConvertible {
    let bus: UInt8
    let ports: [UInt8]
    var description: String { "\(bus)-" + ports.map(String.init).joined(separator: ".") }
}

struct USBFailure: Error, CustomStringConvertible {
    let code: Int32
    var description: String { String(cString: libusb_strerror(code)) }
    var isBusy: Bool { code == LIBUSB_ERROR_ACCESS.rawValue || code == LIBUSB_ERROR_BUSY.rawValue }
}

private func check(_ code: Int32) throws {
    if code < 0 { throw USBFailure(code: code) }
}

/// libusb session used to find and open RiffMaster dongles.
/// libusb contexts are thread-safe, hence @unchecked Sendable.
final class USBSession: @unchecked Sendable {
    static let vendorID: UInt16 = 0x0e6f
    static let productID: UInt16 = 0x0248

    private let context: OpaquePointer

    init() throws {
        var ctx: OpaquePointer?
        try check(libusb_init(&ctx))
        context = ctx!
    }

    deinit { libusb_exit(context) }

    func connectedDongles() -> [DongleLocation] {
        withDongleDevices { $0.map(\.location) }
    }

    func open(_ location: DongleLocation) throws -> Dongle {
        let handle: OpaquePointer = try withDongleDevices { devices in
            guard let device = devices.first(where: { $0.location == location })?.device else {
                throw USBFailure(code: LIBUSB_ERROR_NO_DEVICE.rawValue)
            }
            var handle: OpaquePointer?
            try check(libusb_open(device, &handle))
            return handle!
        }
        return try Dongle(handle: handle)
    }

    private func withDongleDevices<T>(_ body: ([(device: OpaquePointer, location: DongleLocation)]) throws -> T) rethrows -> T {
        var list: UnsafeMutablePointer<OpaquePointer?>?
        let count = libusb_get_device_list(context, &list)
        defer { if let list { libusb_free_device_list(list, 1) } }
        var found: [(device: OpaquePointer, location: DongleLocation)] = []
        for i in 0..<max(count, 0) {
            guard let device = list?[i] else { continue }
            var desc = libusb_device_descriptor()
            guard libusb_get_device_descriptor(device, &desc) == 0,
                  desc.idVendor == Self.vendorID, desc.idProduct == Self.productID else { continue }
            var ports = [UInt8](repeating: 0, count: 7)
            let depth = libusb_get_port_numbers(device, &ports, Int32(ports.count))
            let location = DongleLocation(bus: libusb_get_bus_number(device), ports: Array(ports.prefix(Int(max(depth, 0)))))
            found.append((device, location))
        }
        return try body(found)
    }
}

/// An opened, initialised dongle streaming GIP packets.
/// Owned by exactly one player thread after hand-off, hence @unchecked Sendable.
final class Dongle: @unchecked Sendable {
    private let handle: OpaquePointer
    private var claimed = false

    fileprivate init(handle: OpaquePointer) throws {
        self.handle = handle
        var config: Int32 = 0
        // Only reconfigure when needed: setting the configuration on a device
        // another process is using would disrupt it.
        if libusb_get_configuration(handle, &config) != 0 || config != 1 {
            try check(libusb_set_configuration(handle, 1))
        }
        try check(libusb_claim_interface(handle, 0))
        claimed = true
        try write([0x05, 0x20, 0x00, 0x01, 0x00])        // GIP power on
        try write([0x06, 0x20, 0x01, 0x02, 0x01, 0x00])  // PDP auth: starts the input stream
    }

    deinit {
        if claimed { libusb_release_interface(handle, 0) }
        libusb_close(handle)
    }

    /// Next packet, or nil if none arrived within the timeout.
    func read() throws -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: 64)
        var transferred: Int32 = 0
        let rc = libusb_interrupt_transfer(handle, 0x81, &buffer, Int32(buffer.count), &transferred, 500)
        if rc == LIBUSB_ERROR_TIMEOUT.rawValue { return nil }
        try check(rc)
        return Array(buffer.prefix(Int(transferred)))
    }

    private func write(_ packet: [UInt8]) throws {
        var bytes = packet
        var transferred: Int32 = 0
        try check(libusb_interrupt_transfer(handle, 0x02, &bytes, Int32(bytes.count), &transferred, 1000))
    }
}
