# riffmaster-hid

Turns up to two PDP RiffMaster (Xbox) guitar dongles into two separate virtual
HID gamepads ("RiffMaster Guitar 1" and "RiffMaster Guitar 2") so games such as
Clone Hero see two controllers, with an analog whammy bar and tilt.

## Build

```bash
swift build -c release
swift test
```

The binary is `.build/release/riffmaster-hid`. libusb is linked statically from
`/opt/homebrew/lib/libusb-1.0.a` (`brew install libusb`), so the binary has no
Homebrew dylib dependency.

## Run

Stop the Python keyboard bridge first: only one program can hold a dongle.

```bash
.build/release/riffmaster-hid --dry-run   # prints each guitar's state; no controllers created
.build/release/riffmaster-hid             # creates the virtual controllers
```

Without the entitlement below, the second command prints
"Virtual HID device creation blocked: ..." and exits.

## Controller layout

| Gamepad control | Guitar |
|---|---|
| Buttons 1–5 | Green, red, yellow, blue, orange (upper and solo frets) |
| Button 6 / 7 / 8 / 9 | Start (≡) / Select, star power (⧉) / Share / Xbox |
| Button 10 / 11 | Strum up / strum down |
| Hat switch | Strum up/down + d-pad left/right |
| Z axis | Whammy (0–255) |
| Rz axis | Tilt (0–255) |

## Signing once Apple grants the entitlement

Creating virtual HID devices requires the restricted entitlement
`com.apple.developer.hid.virtual.device`, requested through Apple's DriverKit
entitlement request form. The steps below are the expected path for a
restricted entitlement; **verify each against Apple's instructions when the
approval arrives**, since Apple's process may differ.

1. In Certificates, Identifiers & Profiles, create an App ID (e.g.
   `com.example.riffmaster-hid`) and enable the granted HID virtual device
   capability on it.
2. Create a provisioning profile for that App ID (Developer ID for running
   outside development, or Apple Development for this Mac only) and download it.
3. Restricted entitlements are only honoured when a provisioning profile is
   embedded, which for a command-line tool most likely means wrapping it in an
   app bundle:

   ```
   RiffMasterHID.app/Contents/Info.plist              (CFBundleIdentifier = the App ID)
   RiffMasterHID.app/Contents/MacOS/riffmaster-hid
   RiffMasterHID.app/Contents/embedded.provisionprofile
   ```

4. Sign with the matching identity and the entitlements file:

   ```bash
   codesign --force --options runtime --timestamp \
     --entitlements Resources/riffmaster-hid.entitlements \
     --sign "Developer ID Application: <Your Name> (<TEAMID>)" \
     RiffMasterHID.app
   ```

5. Check the result and run it:

   ```bash
   codesign -d --entitlements - RiffMasterHID.app
   RiffMasterHID.app/Contents/MacOS/riffmaster-hid
   ```

   If macOS still refuses, check Console for AMFI / entitlement errors.
