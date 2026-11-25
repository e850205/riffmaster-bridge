# RiffMaster Bridge

Use the **PDP RiffMaster wireless guitar for Xbox** (USB dongle `0e6f:0248`) on macOS, which has no driver for it.

## Two guitars in Clone Hero (OpenJoystickDriver) — recommended

[OpenJoystickDriver](https://github.com/xsyetopz/OpenJoystickDriver) (OJD) already holds Apple's virtual-HID entitlement and speaks the dongle's Xbox (GIP) protocol, so each guitar shows up as its own gamepad. No code from this repo runs in this setup; keep the keyboard bridge stopped, because OJD needs the dongles.

1. Install OJD, open it, and grant the permissions it asks for. Each dongle appears under Controllers.
2. Publish the guitars as "Xbox Wireless Controller" (the form Clone Hero reads):
   ```sh
   ojd virtual set game-controller-compatible 0E6F:0248
   ```
3. Import and activate the profile in this repo:
   ```sh
   ojd profile import ojd-guitar-profile.plist
   ojd profile activate Guitar
   ```
4. In Clone Hero press Space, pick a player, **Assign Controller**, then bind in the **Controller** column (not Keyboard): the five frets, Strum Up/Down, Start (Menu), Star Power (View) and Whammy.

`ojd` is the app's own binary (`/Applications/OpenJoystickDriver.app/Contents/MacOS/OpenJoystickDriver`) unless you install its command-line tool.

Why the profile is needed: OJD reads the guitar as a standard Xbox pad, so the fret bytes also land on the right trigger (yellow, blue and orange collide) and tilt and whammy share the left trigger. The profile passes only the real buttons, drops the right trigger, and splits the left trigger: tilt alone moves it to 16–25 %, which presses View (star power); any whammy pushes it to 100 %.

| Guitar | Virtual gamepad |
|---|---|
| Green, red, yellow, blue, orange | A, B, Y, X, LB |
| Strum / d-pad | D-pad |
| Menu, View | Start, Back |
| Whammy | Left trigger (effectively on/off) |
| Tilt neck up | Back (star power) |

## Keyboard bridge (single player, no extra software)

`riffmaster_bridge.py` talks to the dongle with libusb, sends the Xbox (GIP) power-on and PDP auth packets that start the input stream, and turns guitar input into key presses. Supports up to two dongles and reconnects automatically.

```sh
brew install libusb
python3 -m venv .venv && .venv/bin/pip install pyusb
./run.sh
```

The terminal app needs Accessibility permission (System Settings → Privacy & Security → Accessibility).

| Control | Player 1 | Player 2 |
|---|---|---|
| Frets (upper and solo) | 1 2 3 4 5 | Z X C V B |
| Strum / d-pad up, down | ↑ ↓ | I K |
| D-pad left, right | ← → | J L |
| Menu (Start) | Return | P |
| View or tilt (star power) | Space | N |
| Whammy past halfway | W | M |
| Share | Delete | Q |
| Xbox button | Esc | Esc |

`set_clonehero_binds.py` writes matching keyboard binds into Clone Hero (quit Clone Hero first; it backs up your settings). Clone Hero only lets one player use the keyboard, so the keyboard bridge is effectively single-player.

`calibrate.py` is a guided capture for mapping controls.

## Virtual gamepad helper (`RiffMasterHID/`)

A Swift tool that presents each guitar as its own HID gamepad via CoreHID `HIDVirtualDevice`, with an analog whammy bar, so two players work in Clone Hero without OJD. It requires the `com.apple.developer.hid.virtual.device` entitlement from Apple. Until that's granted, `--dry-run` prints decoded guitar input. See [RiffMasterHID/README.md](RiffMasterHID/README.md).

## Input report reference

Type `0x20` packets; body = bytes after the 4-byte header:

| Body byte | Meaning |
|---|---|
| 0 | `0x04` Menu, `0x08` View (face bits `0x10`–`0x80` mirror frets) |
| 1 | `0x01` down, `0x02` up (strum / d-pad, as seen by the player), `0x04` left, `0x08` right |
| 2 | Tilt, 0–255 |
| 3 | Whammy, 0–255 |
| 5 | Upper frets: `0x01` green, `0x02` red, `0x04` yellow, `0x08` blue, `0x10` orange |
| 6 | Solo frets, same bits |
| 14 | `0x01` Share |

Type `0x07` packets: Xbox button, pressed when `bytes[4] & 1`.
