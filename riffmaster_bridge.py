"""RiffMaster (Xbox, PDP 0e6f:0248) -> macOS keyboard bridge."""
import ctypes, threading, time, usb.core, usb.util

AS = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
AS.CGEventCreateKeyboardEvent.restype = ctypes.c_void_p
AS.CGEventCreateKeyboardEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint16, ctypes.c_bool]
AS.CGEventPost.argtypes = [ctypes.c_uint32, ctypes.c_void_p]
AS.CFRelease.argtypes = [ctypes.c_void_p]

def key(code, down):
    e = AS.CGEventCreateKeyboardEvent(None, code, down)
    AS.CGEventPost(0, e); AS.CFRelease(e)

# (byte index in input report body, bit mask) -> mac virtual keycode
MAP = {
    (5, 0x01): 18, (6, 0x01): 18,  # green  (upper / solo) -> 1
    (5, 0x02): 19, (6, 0x02): 19,  # red    -> 2
    (5, 0x04): 20, (6, 0x04): 20,  # yellow -> 3
    (5, 0x08): 21, (6, 0x08): 21,  # blue   -> 4
    (5, 0x10): 23, (6, 0x10): 23,  # orange -> 5
    (1, 0x02): 126,  # strum / d-pad up (as seen by player)   -> Up arrow
    (1, 0x01): 125,  # strum / d-pad down (as seen by player) -> Down arrow
    (1, 0x04): 123,  # d-pad left  -> Left arrow
    (1, 0x08): 124,  # d-pad right -> Right arrow
    (0, 0x04): 36,   # Menu (three lines)  -> Return
    (0, 0x08): 49,   # View (two windows)  -> Space (star power)
    (14, 0x01): 51,  # Share               -> Delete
}
# (byte index, threshold) -> keycode, for analog controls
ANALOG = {
    (3, 0x80): 13,   # whammy past halfway -> W
    (2, 0xa0): 49,   # tilt neck up        -> Space (star power)
}
GUIDE_KEY = 53       # Xbox button -> Escape

# Player 2 keys: P1 keycode -> P2 keycode
P2 = {18: 6, 19: 7, 20: 8, 21: 9, 23: 11,   # frets 1-5 -> Z X C V B
      126: 34, 125: 40, 123: 38, 124: 37,    # arrows -> I K J L
      36: 35, 49: 45, 13: 46, 51: 12}        # Return->P, Space->N, W->M, Delete->Q

def run(d, keys, held):
    d.write(2, bytes([5, 0x20, 0, 1, 0]))     # GIP power on
    d.write(2, bytes([6, 0x20, 1, 2, 1, 0]))  # PDP auth -> starts input stream
    want, guide = set(), False
    while True:
        try: r = bytes(d.read(0x81, 64, timeout=500))
        except usb.core.USBTimeoutError: continue
        if r[0] == 0x07: guide = bool(r[4] & 1)
        elif r[0] == 0x20:
            body = r[4:]
            want = {c for (i, m), c in MAP.items() if body[i] & m}
            want |= {c for (i, t), c in ANALOG.items() if body[i] >= t}
            want = {keys.get(c, c) for c in want}
        else: continue
        want = (want - {GUIDE_KEY}) | ({GUIDE_KEY} if guide else set())
        for code in want - held: key(code, True)
        for code in held - want: key(code, False)
        held.clear(); held.update(want)

slots = [None, None]   # USB location of the dongle each player is using
helds = [set(), set()]

def player(n, d):
    try:
        d.set_configuration(); usb.util.claim_interface(d, 0)
        print(f"Player {n+1} connected", flush=True)
        run(d, {} if n == 0 else P2, helds[n])
    except usb.core.USBError as e:
        print(f"Player {n+1} disconnected ({e}); waiting for it to come back", flush=True)
    finally:
        for code in list(helds[n]): key(code, False)
        helds[n].clear(); usb.util.dispose_resources(d); slots[n] = None

print("RiffMaster bridge running. Ctrl+C to stop.", flush=True)
try:
    while True:
        devs = sorted(usb.core.find(find_all=True, idVendor=0x0e6f, idProduct=0x0248),
                      key=lambda d: (d.bus, d.port_numbers or ()))
        for d in devs:
            loc = (d.bus, d.port_numbers, d.address)
            if loc in slots or None not in slots: continue
            n = slots.index(None); slots[n] = loc
            threading.Thread(target=player, args=(n, d), daemon=True).start()
        time.sleep(2)
finally:
    for held in helds:
        for code in list(held): key(code, False)
