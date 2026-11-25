import CoreHID
import Foundation
import RiffMasterCore

/// Destination for a player's guitar state.
protocol GuitarOutput: Sendable {
    func publish(_ state: GuitarState)
}

/// --dry-run output: prints each state change.
struct ConsoleOutput: GuitarOutput {
    let player: Int

    func publish(_ s: GuitarState) {
        let frets = [("G", GuitarState.Frets.green), ("R", .red), ("Y", .yellow), ("B", .blue), ("O", .orange)]
            .map { s.frets.contains($0.1) ? $0.0 : "-" }.joined()
        var held: [String] = []
        if s.strumUp { held.append("strum-up") }
        if s.strumDown { held.append("strum-down") }
        if s.dpadLeft { held.append("left") }
        if s.dpadRight { held.append("right") }
        if s.start { held.append("start") }
        if s.select { held.append("select") }
        if s.share { held.append("share") }
        if s.guide { held.append("guide") }
        print("P\(player) frets \(frets) whammy \(s.whammy) tilt \(s.tilt) \(held.joined(separator: " "))")
    }
}

/// A CoreHID virtual gamepad that games see as "RiffMaster Guitar N".
final class VirtualGamepad: GuitarOutput {
    private let reports: AsyncStream<Data>.Continuation

    /// Returns nil when macOS refuses to create the device (missing entitlement).
    init?(player: Int) {
        let properties = HIDVirtualDevice.Properties(
            descriptor: GamepadReport.descriptor,
            vendorID: UInt32(USBSession.vendorID),
            productID: UInt32(USBSession.productID),
            transport: .virtual,
            product: "RiffMaster Guitar \(player)",
            manufacturer: "Performance Designed Products",
            serialNumber: "riffmaster-hid-player-\(player)",
            uniqueID: "riffmaster-hid-player-\(player)"
        )
        guard let device = HIDVirtualDevice(properties: properties) else { return nil }
        let (stream, continuation) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .bufferingNewest(64))
        reports = continuation
        Task {
            await device.activate(delegate: IgnoreReportRequests())
            var warned = false
            for await report in stream {
                do { try await device.dispatchInputReport(data: report, timestamp: .now) }
                catch where !warned { warned = true; print("Player \(player): sending report to virtual gamepad failed: \(error)") }
                catch {}
            }
        }
    }

    func publish(_ state: GuitarState) {
        reports.yield(GamepadReport.encode(state))
    }
}

/// The guitar has no output reports (LEDs, rumble), so host requests are ignored.
private struct IgnoreReportRequests: HIDVirtualDeviceDelegate {
    func hidVirtualDevice(_ device: HIDVirtualDevice, receivedSetReportRequestOfType type: HIDReportType,
                          id: HIDReportID?, data: Data) async throws {}
    func hidVirtualDevice(_ device: HIDVirtualDevice, receivedGetReportRequestOfType type: HIDReportType,
                          id: HIDReportID?, maxSize: Int) async throws -> Data { Data() }
}
