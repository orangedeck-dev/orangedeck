"""Alle Ansichten unter Android abbilden -- das Gegenstueck zu
`ansichten.py` am Rechner.

    export ANDROID_SERIAL=emulator-5554
    adb install -r orangedeck-x86_64-debug.apk
    python3 tools/ansichten-android.py /tmp/bilder a14p

Reiter und Unterreiter werden wie am Rechner per Texterkennung gesucht und
angetippt; die Groesse des Bildschirms kommt aus `wm size`, das Skript
laeuft also in jeder Groesse. Telefon, Tablett hoch und Tablett quer sind
nur drei Aufrufe mit `adb shell wm size` dazwischen.

**Auch das Fehlen wird gemeldet.** Bleibt ein Unterreiter aus, steht er am
Ende im Protokoll -- so wurde am 11.09.2026 gesehen, dass Markt und Wallet
unter Android Einstellungsseiten hatten, obwohl es beide Ansichten dort
nicht gibt (und danach, dass sie weg sind).

Braucht `tesseract` und eine englische Oberflaeche im Geraet.

Aufruf: ansichten-android.py AUSGABE PRAEFIX
"""
import os, subprocess, sys, time
from PIL import Image

OUT, PRE = sys.argv[1], sys.argv[2]
ENV = dict(os.environ)
os.makedirs(OUT, exist_ok=True)
protokoll = []


def adb(*a, roh=False):
    r = subprocess.run(["adb", *a], env=ENV, capture_output=True, text=not roh)
    return r.stdout


def bild(name):
    p = f"{OUT}/{PRE}_{name}.png"
    open(p, "wb").write(adb("exec-out", "screencap", "-p", roh=True))
    return p


def woerter(p, y0=0, y1=None):
    im = Image.open(p).convert("L")
    y1 = y1 or im.height
    teil = im.crop((0, y0, im.width, y1))
    tmp = f"{OUT}/.ocr_{PRE}.png"
    teil.save(tmp)
    r = subprocess.run(["tesseract", tmp, "-", "--psm", "11", "tsv"],
                       capture_output=True, text=True).stdout
    out = []
    for z in r.splitlines()[1:]:
        f = z.split("\t")
        if len(f) < 12 or not f[11].strip():
            continue
        try:
            conf = float(f[10])
        except ValueError:
            continue
        if conf < 20:
            continue
        x, y, w, h = (int(v) for v in f[6:10])
        out.append((f[11].strip(), x + w // 2, y0 + y + h // 2))
    return out


def tippe_auf(text, y0=0, y1=None, nr=0):
    p = bild("_suche")
    t = [w for w in woerter(p, y0, y1) if w[0].lower().startswith(text.lower())]
    t.sort(key=lambda w: (w[2], w[1]))
    if len(t) <= nr:
        protokoll.append(f"NICHT GEFUNDEN: {text}")
        return None
    x, y = t[nr][1], t[nr][2]
    adb("shell", "input", "tap", str(x), str(y))
    return y


def gerollt(name, hoehe):
    """Abbilden und seitenweise wischen, solange sich etwas aendert.

    Am Ende so oft zurueck nach oben, wie es Seiten waren -- sonst beginnt
    der naechste Reiter mitten in der Seite."""
    vorher = Image.open(bild(name)).convert("RGB")
    for k in range(2, 6):
        adb("shell", "input", "swipe", "540", str(int(hoehe * 0.8)),
            "540", str(int(hoehe * 0.25)), "400")
        time.sleep(2)
        p = f"{OUT}/{PRE}_{name}_{k}.png"
        open(p, "wb").write(adb("exec-out", "screencap", "-p", roh=True))
        jetzt = Image.open(p).convert("RGB")
        if list(jetzt.getdata()) == list(vorher.getdata()):
            os.remove(p)
            break
        vorher = jetzt
    for _ in range(6):
        adb("shell", "input", "swipe", "540", str(int(hoehe * 0.25)),
            "540", str(int(hoehe * 0.85)), "300")
    time.sleep(1.5)


groesse = adb("shell", "wm", "size").strip().split(":")[-1].strip()
BREITE, HOEHE = (int(v) for v in groesse.split("x"))
print("Bildschirm", BREITE, HOEHE)

adb("shell", "am", "force-stop", "dev.orangedeck.OrangeDeck")
adb("shell", "monkey", "-p", "dev.orangedeck.OrangeDeck", "-c",
    "android.intent.category.LAUNCHER", "1")
time.sleep(22)

ytab = tippe_auf("Feed", 0, HOEHE // 4) or 0
time.sleep(4)
gerollt("01_feed", HOEHE)
for nr, (name, text) in enumerate((("02_uhr", "Clock"), ("03_mining", "Mining"),
                                   ("04_explorer", "Explorer"))):
    if tippe_auf(text, max(0, ytab - 40), ytab + 40):
        time.sleep(7)
        gerollt(name, HOEHE)

# Netzwerkseite im Mining-Reiter, falls der Umschalter da ist
if tippe_auf("Mining", max(0, ytab - 40), ytab + 40):
    time.sleep(5)
    if tippe_auf("Network", ytab, ytab + 260):
        time.sleep(6)
        gerollt("03b_mining_netz", HOEHE)

# Explorer: Block suchen
if tippe_auf("Explorer", max(0, ytab - 40), ytab + 40):
    time.sleep(5)
    adb("shell", "input", "tap", str(BREITE // 2), str(ytab + 110))
    time.sleep(2)
    adb("shell", "input", "text", "966500")
    time.sleep(1)
    bild("04b_block_hinweis")
    adb("shell", "input", "keyevent", "66")
    time.sleep(12)
    gerollt("04b_block", HOEHE)
    adb("shell", "input", "keyevent", "111")   # Escape: Tastatur weg

# Einstellungen samt Unterreitern. Seit dem 13.09.2026 kein Reiter
# "Settings" mehr, sondern das Zahnrad; ohne Wort zum Suchen geht es ueber
# die Taste dahinter (KEYCODE_COMMA). Das Escape oben hat den Fokus aus dem
# Suchfeld schon zurueckgegeben.
adb("shell", "input", "keyevent", "55")
time.sleep(5)
gerollt("06_einst", HOEHE)
def unterreiter_suchen(text):
    """Den Unterreiter finden, notfalls die Reiterzeile weiterschieben.

    **Die Zeile ist laenger als der Bildschirm.** Am 18.09.2026 meldete das
    Werkzeug am Galaxy "Unterreiter fehlt: Market" -- den Reiter gibt es, er
    stand nur rechts ausserhalb des Bildes ("Ma..." am Rand). Wer nur das
    Sichtbare durchsucht, haelt jeden Reiter dahinter fuer nicht vorhanden.
    Geschoben wird auf der Hoehe der Zeile selbst, sonst rollt die Seite."""
    y = ytab + 90
    for versuch in range(4):
        kand = [w for w in woerter(bild("_suche"), ytab + 20, ytab + 160)
                if w[0].lower().startswith(text.lower())]
        # Am Rand angeschnittene Reiter nicht antippen -- der Treffer waere
        # halb ausserhalb, und getippt wird daneben.
        kand = [w for w in kand if 40 < w[1] < BREITE - 40]
        if kand:
            return kand[0]
        adb("shell", "input", "swipe", str(int(BREITE * 0.8)), str(y),
            str(int(BREITE * 0.25)), str(y), "400")
        time.sleep(1.5)
    return None


for i, text in enumerate(("Layout", "Feed", "Clock", "Mining", "Explorer", "Market")):
    treffer = unterreiter_suchen(text)
    if not treffer:
        protokoll.append(f"Unterreiter fehlt: {text}")
        continue
    x, y = treffer[1], treffer[2]
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(2)
    gerollt(f"06{chr(ord('b') + i)}_{text.lower()}", HOEHE)

if os.path.exists(f"{OUT}/{PRE}__suche.png"):
    os.remove(f"{OUT}/{PRE}__suche.png")
print("\n".join(protokoll) or "alles gefunden")
