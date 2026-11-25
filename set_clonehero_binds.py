"""Write Clone Hero keyboard binds for Player 1 and 2 to match riffmaster_bridge.py.
Quit Clone Hero first. Backs up the prefs to clonehero_prefs_backup.plist."""
import json, os, plistlib, re, subprocess, sys

DOMAIN = "com.srylain.CloneHero"

# Clone Hero (Rewired) action ids, read from the game's data
GREEN, RED, YELLOW, BLUE, ORANGE, STRUM_UP, SELECT, STRUM_DOWN, START = 0, 1, 2, 3, 4, 5, 6, 14, 16
WHAMMY_BUTTON, DPAD_RIGHT, DPAD_LEFT = 30, 31, 32

# key -> (Rewired keyboard element id, Unity KeyCode)
KEYS = {"1": (28, 49), "2": (29, 50), "3": (30, 51), "4": (31, 52), "5": (32, 53),
        "space": (54, 32), "return": (58, 13), "up": (89, 273), "down": (90, 274),
        "right": (91, 275), "left": (92, 276)}
KEYS.update({c: (ord(c) - 96, ord(c)) for c in "abcdefghijklmnopqrstuvwxyz"})

BINDS = {
    "Player1": {GREEN: "1", RED: "2", YELLOW: "3", BLUE: "4", ORANGE: "5",
                STRUM_UP: "up", STRUM_DOWN: "down", DPAD_LEFT: "left", DPAD_RIGHT: "right",
                START: "return", SELECT: "space", WHAMMY_BUTTON: "w"},
    "Player2": {GREEN: "z", RED: "x", YELLOW: "c", BLUE: "v", ORANGE: "b",
                STRUM_UP: "i", STRUM_DOWN: "k", DPAD_LEFT: "j", DPAD_RIGHT: "l",
                START: "p", SELECT: "n", WHAMMY_BUTTON: "m"},
}

def entry(action, key):
    elem, code = KEYS[key]
    return ("<ActionElementMap><actionCategoryId>-1</actionCategoryId>"
            f"<actionId>{action}</actionId><elementType>1</elementType>"
            f"<elementIdentifierId>{elem}</elementIdentifierId><axisRange>0</axisRange>"
            "<invert>false</invert><axisContribution>0</axisContribution>"
            f"<keyboardKeyCode>{code}</keyboardKeyCode><modifierKey1>0</modifierKey1>"
            "<modifierKey2>0</modifierKey2><modifierKey3>0</modifierKey3>"
            "<enabled>true</enabled></ActionElementMap>")

if subprocess.run(["pgrep", "-x", "Clone Hero"], capture_output=True).returncode == 0:
    sys.exit("Quit Clone Hero first, then run this again.")

subprocess.run(["defaults", "export", DOMAIN, "clonehero_prefs_backup.plist"], check=True)
prefs = plistlib.load(open("clonehero_prefs_backup.plist", "rb"))

for player, binds in BINDS.items():
    key = next(k for k in prefs if f"playerName={player}|dataType=ControllerMap|" in k
               and "controllerMapType=KeyboardMap" in k and "categoryId=1" in k)
    maps = "<buttonMaps>" + "".join(entry(a, k) for a, k in binds.items()) + "</buttonMaps>"
    xml = re.sub(r"<buttonMaps>.*</buttonMaps>|<buttonMaps />", maps, prefs[key], flags=re.S)
    prefs[key] = xml.replace("<enabled>false</enabled><buttonMaps>", "<enabled>true</enabled><buttonMaps>")

assign = json.loads(prefs["RewiredSaveData_ControllerAssignments"])
for p in assign["players"]:
    if p["id"] in (0, 1): p["hasKeyboard"] = True
prefs["RewiredSaveData_ControllerAssignments"] = json.dumps(assign, separators=(",", ":"))

plistlib.dump(prefs, open("clonehero_prefs_new.plist", "wb"))
subprocess.run(["defaults", "import", DOMAIN, "clonehero_prefs_new.plist"], check=True)
os.remove("clonehero_prefs_new.plist")
print("Clone Hero keybinds written for Player 1 and Player 2.")
