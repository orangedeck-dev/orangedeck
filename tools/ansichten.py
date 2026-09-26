"""Alle Ansichten eines laufenden Fensters abbilden -- fuer den Vergleich
zwischen Systemen.

    xvfb-run -a --server-args="-screen 0 1400x900x24" bash -c \\
        'env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=xcb LANG=en_US.UTF-8 \\
             ./build/orangedeck-app --id pruef > /dev/null 2>&1 & \\
         python3 tools/ansichten.py /tmp/bilder nativ 1280 800; kill %1'

Dasselbe mit `flatpak run ... dev.orangedeck.OrangeDeck --id pruef` gibt die
Bilder des Buendels -- gleiche Groesse, gleiche Reihenfolge, also direkt
vergleichbar (`PIL.ImageChops.difference`).

**Warum Texterkennung und nicht feste Koordinaten.** Die Hauptreiter liegen
auf den Tasten 1 bis 6, die Einstellungen (das Zahnrad) auf dem Komma, die
Unterreiter von Markt und Einstellungen auf keiner Taste.
Feste Punkte waeren an jede Fenstergroesse und jede Schrift gebunden -- und
gerade die Schrift ist im Flatpak eine andere als am Rechner. `tesseract`
sucht das Wort, geklickt wird in seine Mitte. Gefunden wird so auch, was
**fehlt**: bleibt ein Unterreiter aus, steht er am Ende im Protokoll (so kam
heraus, dass Markt und Wallet unter Android Seiten hatten, die dort nichts
tun).

Braucht `tesseract`, `import` (ImageMagick), `python-xlib` und `libXtst`;
die Oberflaeche muss auf Englisch stehen (LANG=en_US.UTF-8).

Aufruf: ansichten.py AUSGABE PRAEFIX BREITE HOEHE
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xtest
from PIL import Image

OUT, PRE, W, H = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
os.makedirs(OUT, exist_ok=True)

# Eine alte Transaktion mit zwei Ausgaengen ohne Adresse und ohne Gebuehr
# (Block 170, die erste Ueberweisung ueberhaupt): genau daran zeigte sich am
# 11.09.2026 der halb gezeichnete Fluss.
TX = "f4184fc596403b9d638783cf57adfe4c75c605f6356fbc91338530e9831e9e16"
BLOCK = "966500"
protokoll = []


def bild(name):
    p = f"{OUT}/{PRE}_{name}.png"
    subprocess.run(["import", "-window", "root", "-crop", f"{W}x{H}+0+0", p])
    return p


def gerollt(name, x=None, y=None):
    """Abbilden, dann seitenweise nach unten rollen, solange sich etwas tut.

    Ohne das bleibt jede Seite, die laenger ist als das Fenster, halb
    ungeprueft -- die Einstellungen sind das durchweg."""
    vorher = Image.open(bild(name)).convert("RGB")
    # Am linken Rand: dort liegt kein Regler, der das Rad schluckt und dabei
    # einen Wert verstellt.
    xtest.maus_nach(x or 12, y or H // 2)
    for k in range(2, 6):
        xtest.rad(hoch=False, mal=6)
        time.sleep(1.2)
        p = f"{OUT}/{PRE}_{name}_{k}.png"
        subprocess.run(["import", "-window", "root", "-crop", f"{W}x{H}+0+0", p])
        jetzt = Image.open(p).convert("RGB")
        if list(jetzt.getdata()) == list(vorher.getdata()):
            os.remove(p)
            break
        vorher = jetzt
    xtest.rad(hoch=True, mal=40)
    time.sleep(0.8)


def woerter(p, y0=0, y1=None):
    """Erkannte Woerter mit Mittelpunkt, nur im Streifen y0..y1.

    Doppelte Groesse vor der Erkennung: die Reiterschrift misst elf
    Bildpunkte, und darunter faellt tesseract reihenweise aus."""
    im = Image.open(p).convert("L")
    y1 = y1 or im.height
    teil = im.crop((0, y0, im.width, y1)).resize((im.width * 2, (y1 - y0) * 2))
    tmp = f"{OUT}/.ocr.png"
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
        x, y, w, h = (int(v) // 2 for v in f[6:10])
        out.append((f[11].strip(), x + w // 2, y0 + y + h // 2))
    return out


def klicke_text(text, y0, y1, nr=0):
    p = bild("_suche")
    t = [w for w in woerter(p, y0, y1) if w[0].lower().startswith(text.lower())]
    t.sort(key=lambda w: (w[2], w[1]))
    if len(t) <= nr:
        protokoll.append(f"NICHT GEFUNDEN: {text} in {y0}..{y1}")
        return False
    xtest.klick(t[nr][1], t[nr][2])
    return True


def zeile_von(wort, y0=25, y1=200):
    """y der Zeile, in der `wort` steht -- so findet sich die Reihe der
    Unterreiter, ohne ihre Hoehe zu kennen."""
    p = bild("_suche")
    t = [w for w in woerter(p, y0, y1) if w[0].lower().startswith(wort.lower())]
    if not t:
        protokoll.append(f"Zeile von {wort} nicht gefunden")
        return None
    return min(t, key=lambda w: w[2])[2]


def reiter(n, warte):
    # Erst in eine leere Ecke klicken und Escape: sonst frisst das Suchfeld
    # des Explorers die Ziffer, und aus "5" wird der Markt-Reiter.
    xtest.klick(W - 5, H - 5)
    xtest.taste("Escape")
    time.sleep(0.3)
    xtest.taste(str(n))
    time.sleep(warte)


time.sleep(4)
f = xtest.fenster_suchen()
xtest.groesse(f, W, H)
time.sleep(10)

xtest.klick(W - 5, H - 5)
xtest.taste("Escape")
xtest.taste("1")
time.sleep(0.6)
bild("01a_tastenhilfe")           # die Hilfe blendet nach zwei Sekunden aus
reiter(1, 4)
bild("01_feed")
reiter(2, 5)
bild("02_uhr")
reiter(3, 6)
gerollt("03_mining")
# Umschalter Geraet | Netzwerk -- den gibt es nur mit eingetragenem Miner
if klicke_text("Network", 0, 200):
    time.sleep(6)
    gerollt("03b_mining_netz")
    klicke_text("Device", 0, 200)
    time.sleep(2)
reiter(4, 6)
gerollt("04_explorer")
for name, was in (("04b_block", BLOCK), ("04c_tx", TX)):
    # Mitte des Suchfelds, nicht darunter: ein Klick daneben nimmt ihm den
    # Fokus, und die Eingabe landet auf den Reitertasten.
    xtest.klick(W // 2, 58)
    time.sleep(1.5)
    for _ in range(80):
        xtest.taste("BackSpace")
    time.sleep(0.8)
    xtest.tippe(was)
    time.sleep(0.8)
    bild(name + "_hinweis")       # der Typ-Hinweis rechts im Feld
    xtest.taste("Return")
    time.sleep(20)                # der Fluss zeichnet erst mit den Ausgaengen
    gerollt(name)
reiter(5, 8)
bild("05_markt")
ym = zeile_von("Price") or 47
for name, text in (("05b_liq", "Liquidations"), ("05c_heat", "Heatmap")):
    if klicke_text(text, ym - 14, ym + 14):
        time.sleep(8)
        bild(name)
klicke_text("Price", ym - 14, ym + 14)
time.sleep(1)
# Die Einstellungen haben seit dem 13.09.2026 keinen Reiter mehr, sondern das
# Zahnrad -- auf der Tastatur das Komma. Die Ziffer 6 hat keinen Reiter mehr
# (bis 26.09.2026 die Wallet).
xtest.klick(W - 5, H - 5)
xtest.taste("Escape")
time.sleep(0.3)
xtest.taste("comma")
time.sleep(3)
gerollt("06_einst")
ys = zeile_von("General") or 47
for i, text in enumerate(("Layout", "Feed", "Clock", "Mining", "Explorer",
                          "Market")):
    if klicke_text(text, ys - 14, ys + 14, nr=0):
        time.sleep(1.5)
        gerollt(f"06{chr(ord('b') + i)}_{text.lower()}")
klicke_text("General", ys - 14, ys + 14)
time.sleep(0.5)
if os.path.exists(f"{OUT}/{PRE}__suche.png"):
    os.remove(f"{OUT}/{PRE}__suche.png")
print("\n".join(protokoll) or "alles gefunden")
