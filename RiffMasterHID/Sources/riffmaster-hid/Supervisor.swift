import Foundation
import RiffMasterCore
import Synchronization

/// Assigns connected dongles to player slots and runs one read loop per player.
final class Supervisor: Sendable {
    private let usb: USBSession
    private let outputs: [any GuitarOutput]
    private let slots: Mutex<[DongleLocation?]>

    init(usb: USBSession, outputs: [any GuitarOutput]) {
        self.usb = usb
        self.outputs = outputs
        slots = Mutex(Array(repeating: nil, count: outputs.count))
    }

    /// Scans for dongles every 2 seconds, forever.
    func run() -> Never {
        var reportedBusy = Set<DongleLocation>()
        while true {
            for location in usb.connectedDongles() {
                guard let slot = claimSlot(for: location) else { continue }
                do {
                    let dongle = try usb.open(location)
                    reportedBusy.remove(location)
                    Thread.detachNewThread { self.play(slot: slot, dongle: dongle, location: location) }
                } catch let failure as USBFailure where failure.isBusy {
                    releaseSlot(slot)
                    if reportedBusy.insert(location).inserted {
                        print("Dongle \(location) is in use by another program (stop the Python bridge first).")
                    }
                } catch {
                    releaseSlot(slot)
                    print("Could not open dongle \(location): \(error)")
                }
            }
            Thread.sleep(forTimeInterval: 2)
        }
    }

    private func play(slot: Int, dongle: Dongle, location: DongleLocation) {
        let output = outputs[slot]
        print("Player \(slot + 1) connected (USB \(location))")
        var state = GuitarState()
        do {
            while true {
                guard let packet = try dongle.read(), let next = state.applying(packet: packet), next != state else { continue }
                state = next
                output.publish(state)
            }
        } catch {
            print("Player \(slot + 1) disconnected (\(error)); waiting for it to come back")
        }
        output.publish(GuitarState())   // release everything the guitar was holding
        releaseSlot(slot)
    }

    /// Reserves the first free slot for a dongle that isn't already playing.
    private func claimSlot(for location: DongleLocation) -> Int? {
        slots.withLock { slots in
            guard !slots.contains(location), let free = slots.firstIndex(of: nil) else { return nil }
            slots[free] = location
            return free
        }
    }

    private func releaseSlot(_ slot: Int) {
        slots.withLock { $0[slot] = nil }
    }
}
