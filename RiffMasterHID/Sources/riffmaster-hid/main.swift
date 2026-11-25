import Foundation

let playerCount = 2
let dryRun = CommandLine.arguments.contains("--dry-run")

let outputs: [any GuitarOutput]
if dryRun {
    outputs = (1...playerCount).map { ConsoleOutput(player: $0) }
} else {
    let pads = (1...playerCount).compactMap { VirtualGamepad(player: $0) }
    guard pads.count == playerCount else {
        fputs("""
        Virtual HID device creation blocked: app is not signed with the com.apple.developer.hid.virtual.device entitlement
        Run with --dry-run to test the guitars without creating controllers.

        """, stderr)
        exit(1)
    }
    outputs = pads
}

let usb: USBSession
do { usb = try USBSession() } catch {
    fputs("Could not start libusb: \(error)\n", stderr)
    exit(1)
}

signal(SIGINT) { _ in _exit(0) }   // the OS releases USB interfaces and virtual devices on exit
setvbuf(stdout, nil, _IOLBF, 0)
print(dryRun ? "riffmaster-hid (dry run) running. Ctrl+C to stop." : "riffmaster-hid running: \(playerCount) virtual guitars created. Ctrl+C to stop.")
Supervisor(usb: usb, outputs: outputs).run()
