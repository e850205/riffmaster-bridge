"""Guided capture: prompts for each control, logs which report bytes change."""
import threading, time, usb.core, usb.util

STEPS = ["WHAMMY bar: push it all the way and release, a few times",
         "TILT: raise the neck straight up, then lower it",
         "D-PAD: press up, down, left, right",
         "XBOX (guide) button: press it once",
         "START / MENU button: press it",
         "SELECT / VIEW button: press it",
         "LOWER (solo) frets near the body: green, red, yellow, blue, orange",
         "Any OTHER small buttons, one at a time (remember their order)"]

d = usb.core.find(idVendor=0x0e6f, idProduct=0x0248)
d.set_configuration(); usb.util.claim_interface(d, 0)
d.write(2, bytes([5, 0x20, 0, 1, 0])); d.write(2, bytes([6, 0x20, 1, 2, 1, 0]))
events = []
def reader():
    while True:
        try: r = bytes(d.read(0x81, 64, timeout=500))
        except usb.core.USBTimeoutError: continue
        events.append((time.time(), r))
threading.Thread(target=reader, daemon=True).start()

log = open("calibrate.log", "w")
for i, step in enumerate(STEPS, 1):
    input(f"\n[{i}/{len(STEPS)}] {step}\n    Press Enter, then do it within 6 seconds...")
    start = time.time(); print("    GO", flush=True); time.sleep(6)
    log.write(f"== {step}\n")
    last = None
    for t, r in events:
        if t < start: continue
        tag = r[:4].hex(' ') if r[0] != 0x20 else ""
        body = r[4:].hex(' ') if r[0] == 0x20 else r.hex(' ')
        if (tag, body) != last: log.write(f"{t-start:5.2f} {tag} | {body}\n"); last = (tag, body)
    log.flush(); print("    recorded.")
print("\nDone. You can go back to the chat.")
