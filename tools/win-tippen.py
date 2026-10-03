"""Text in die Windows-VM tippen, deutsche Belegung.

**Warum es das gibt.** Im Gast darf in "Ausfuehren" nur der Pfad eines
`.cmd` stehen, keine Schalter -- eine lange getippte Befehlszeile haelt
Defender fuer ClickFix (13.09.2026). Der Pfad muss also Zeichen fuer Zeichen
hinein, und `virsh send-key` kennt nur Keycodes einer **deutschen** Tastatur:
`Z` liegt auf `KEY_Y`, `\\` ist AltGr und `ß`, `:` ist Umschalt und `.`.

**Ein Aufruf je Zeichen.** `send-key` schickt mehrere Keycodes *gleichzeitig*
als Kombination -- "KEY_1 KEY_2" ergibt keine 12. Umschalt und AltGr gehoeren
deshalb in denselben Aufruf wie ihr Zeichen, alles andere einzeln.

**Und langsam.** Am 17.09.2026 ging bei 0,4 s Abstand eine Ziffer der PIN
verloren, ohne jede Meldung; die Eingabe stand dann drei Zeichen lang da.
0,45 s haelt seither durch.

    python3 tools/win-tippen.py 'Z:\\orangedeck\\build\\od-start.cmd'
    virsh -c qemu:///system send-key win11 --holdtime 80 KEY_ENTER

Die Domain kommt aus `ORANGEDECK_WIN_VM`, Vorgabe `win11`.
"""
import os
import subprocess
import sys
import time

VM = os.environ.get("ORANGEDECK_WIN_VM", "win11")

EINFACH = {"-": "KEY_SLASH", ".": "KEY_DOT", ",": "KEY_COMMA", " ": "KEY_SPACE"}
UM = {":": "KEY_DOT", "_": "KEY_SLASH", ";": "KEY_COMMA", "/": "KEY_7"}   # mit Umschalt
ALTGR = {"\\": "KEY_MINUS", "@": "KEY_Q"}                   # mit AltGr
TAUSCH = {"z": "y", "y": "z", "Z": "Y", "Y": "Z"}           # deutsche Lage


def codes(c):
    if c in ALTGR:
        return ["KEY_RIGHTALT", ALTGR[c]]
    if c in UM:
        return ["KEY_LEFTSHIFT", UM[c]]
    if c in EINFACH:
        return [EINFACH[c]]
    if c.isdigit():
        return ["KEY_" + c]
    b = TAUSCH.get(c, c)
    if b.isalpha():
        k = "KEY_" + b.upper()
        return ["KEY_LEFTSHIFT", k] if b.isupper() else [k]
    raise SystemExit("unbekanntes Zeichen: " + repr(c))


def tippe(text, pause=0.45, vm=VM):
    for c in text:
        subprocess.run(["virsh", "-c", "qemu:///system", "send-key", vm,
                        "--holdtime", "80"] + codes(c), capture_output=True)
        time.sleep(pause)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    tippe(sys.argv[1])
