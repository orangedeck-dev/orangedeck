#!/usr/bin/env python3
"""Erzeugt das Anwendungssymbol fuer alle Plattformen aus einer Beschreibung.

**Warum erzeugt und nicht gepflegt.** Dasselbe Zeichen liegt am Ende in gut
zwanzig Dateien: als SVG fuer Linux, als adaptive Ikone samt monochromer
Ebene und fuenf Dichten fuer Android, als `.ico` fuer Windows, als
`.iconset` fuer macOS und dreimal als Verknuepfungssymbol. Von Hand haelt das
niemand zusammen -- die erste Aenderung wuerde die Haelfte davon vergessen.

    tools/symbole.py            alles erzeugen
    tools/symbole.py --pruefen  nur zeigen, was entstuende

**Das Bild kommt aus der Anwendung selbst**, nicht aus dem Zeichenprogramm:

- Die Kacheln setzt derselbe Packer wie `ui/qml/mondrian.js` -- erste freie
  Stelle von unten links, und ausschliesslich Quadrate (`r x r`). Rechtecke
  sind damit konstruktiv ausgeschlossen.
- Der Groessensatz fuellt das Raster **restlos** (ein 4x4, vier 2x2, vier
  1x1 = 36 von 36 Zellen). Ein geschuerfter Block ist voll; eine Packung mit
  Loch oben rechts saehe aus wie eine angefangene Halde.
- Die Toene stammen aus `ui/qml/colors.js`: `hclToCss()` ist hier nachgebaut,
  der Farbton steht fest auf ORANGE (h 0.181), variiert wird allein die
  Helligkeit um den Wert der Anwendung (0.472).
"""
import argparse, math, pathlib, subprocess, sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent

# --- Farbe: hclToCss() aus ui/qml/colors.js -------------------------------
CHROMA = 78.225
Xn, Yn, Zn = 0.96422, 1.0, 0.82521
_t0, _t1 = 4 / 29, 6 / 29
_t2 = 3 * _t1 * _t1

def _lab2xyz(t):
    return t ** 3 if t > _t1 else _t2 * (t - _t0)

def _lrgb(x):
    v = 12.92 * x if x <= 0.0031308 else 1.055 * (x ** (1 / 2.4)) - 0.055
    return max(0, min(255, round(255 * v)))

def hcl(h01, l01):
    hr = math.radians(h01 * 360)
    L = l01 * 150
    a, b = math.cos(hr) * CHROMA, math.sin(hr) * CHROMA
    y = (L + 16) / 116
    x, z = y + a / 500, y - b / 200
    x, y, z = Xn * _lab2xyz(x), Yn * _lab2xyz(y), Zn * _lab2xyz(z)
    return "#%02x%02x%02x" % (
        _lrgb(3.1338561 * x - 1.6168667 * y - 0.4906146 * z),
        _lrgb(-0.9787684 * x + 1.9161415 * y + 0.0334540 * z),
        _lrgb(0.0719453 * x - 0.2289914 * y + 1.4052427 * z))

H_ORANGE = 0.181          # ORANGE aus colors.js
L_APP = 0.472
GRUND = "#12101a"         # der Grund der Oberflaeche

# --- Packung: mondrian.js, auf das Noetige gekuerzt ------------------------
class Packung:
    def __init__(self, breite):
        self.breite, self.zeilen = breite, []

    def _bis(self, y):
        while len(self.zeilen) <= y:
            self.zeilen.append([0] * self.breite)

    def _passt(self, x, y, r):
        if x + r > self.breite:
            return False
        self._bis(y + r - 1)
        return all(not self.zeilen[yy][xx]
                   for yy in range(y, y + r) for xx in range(x, x + r))

    def setzen(self, r):
        y = 0
        while True:
            self._bis(y + r - 1)
            for x in range(self.breite - r + 1):
                if self._passt(x, y, r):
                    for yy in range(y, y + r):
                        for xx in range(x, x + r):
                            self.zeilen[yy][xx] = 1
                    return (x, y, r)
            y += 1

BREITE = 6
GROESSEN = [4, 2, 2, 2, 2, 1, 1, 1, 1]        # fuellt 36 von 36 Zellen

def kacheln():
    p = Packung(BREITE)
    gesetzt = [p.setzen(r) for r in GROESSEN]
    belegt = sum(sum(z) for z in p.zeilen)
    # Zusicherung statt Vertrauen: faellt der Satz je auseinander, soll es
    # laut scheitern und nicht still ein Loch ins Symbol setzen.
    assert len(p.zeilen) == BREITE and belegt == BREITE * BREITE, \
        "Der Groessensatz fuellt das Raster nicht mehr restlos: %d Zeilen, %d/%d Zellen" \
        % (len(p.zeilen), belegt, BREITE * BREITE)
    return gesetzt

def helligkeit(x, y, r):
    """Variante 4, diagonal: von unten links dunkel nach oben rechts hell."""
    mx, my = (x + r / 2) / BREITE, (y + r / 2) / BREITE
    return 0.34 + 0.30 * (mx * 0.5 + (1 - my) * 0.5)

# --- Geometrie -------------------------------------------------------------
# **Der Rahmen ist raus.** Er stand als Kontur mit 42 % Deckkraft um die
# Kacheln und las sich ueber dunklem Grund nicht als Orange, sondern als
# Braun -- in der Leiste, im Starter und auf der Projektseite gleichermassen.
# Ein Zeichen, dessen auffaelligstes Merkmal eine Farbe ist, die im Entwurf
# nicht vorkommt, ist unsauber.
#
# Damit das Zeichen dabei nicht schrumpft, uebernehmen die Kacheln die
# Flaeche, die vorher der Rahmen einnahm: der Rand faellt entsprechend
# kleiner aus (siehe `svg_voll` und `vektor_android`).
RAHMEN = False

def teile(seite, rand, luecke_anteil=0.15, mit_rahmen=RAHMEN):
    """Liefert (Rechtecke, Rahmen) in Nutzerkoordinaten der Kantenlaenge `seite`."""
    innen = seite - 2 * rand
    e = innen / BREITE
    l = e * luecke_anteil
    aus = []
    for (x, y, r) in kacheln():
        aus.append((rand + x * e + l / 2, rand + y * e + l / 2,
                    r * e - l, max(2.0, (r * e - l) * 0.15),
                    hcl(H_ORANGE, helligkeit(x, y, r))))
    rahmen = None
    if mit_rahmen:
        d = e * 0.36
        rahmen = (rand - d, rand - d, innen + 2 * d, seite * 0.086, e * 0.21)
    return aus, rahmen

def rundeck_pfad(x, y, w, h, r):
    """Abgerundetes Rechteck als Pfad. Androids <vector> kennt nur Pfade."""
    return ("M%.2f,%.2f H%.2f A%.2f,%.2f 0 0 1 %.2f,%.2f V%.2f "
            "A%.2f,%.2f 0 0 1 %.2f,%.2f H%.2f A%.2f,%.2f 0 0 1 %.2f,%.2f "
            "V%.2f A%.2f,%.2f 0 0 1 %.2f,%.2f Z"
            % (x + r, y, x + w - r, r, r, x + w, y + r, y + h - r,
               r, r, x + w - r, y + h, x + r, r, r, x, y + h - r,
               y + r, r, r, x + r, y))

# --- Ausgabe ---------------------------------------------------------------
# Mit Rahmen sassen die Kacheln bei 0,2266 und der Rahmen stand um 0,36
# Rastereinheiten darueber hinaus -- zusammen 157 von 256. Ohne ihn nehmen die
# Kacheln genau diese 157 ein, damit das Zeichen gleich gross bleibt.
RAND_ANTEIL = 0.2266 if RAHMEN else 0.1934

def svg_voll(seite=256, rand_anteil=RAND_ANTEIL, grund=True, eck=0.219):
    """Das ganze Symbol: dunkler Grund und Kacheln."""
    rand = seite * rand_anteil
    stuecke, rahmen = teile(seite, rand)
    aus = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
           'viewBox="0 0 %d %d">' % (seite, seite, seite, seite)]
    if grund:
        aus.append('  <rect width="%d" height="%d" rx="%.1f" fill="%s"/>'
                   % (seite, seite, seite * eck, GRUND))
    if rahmen:
        x, y, w, sw, rr = rahmen
        aus.append('  <rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" '
                   'fill="none" stroke="%s" stroke-width="%.1f" opacity="0.42"/>'
                   % (x, y, w, w, rr, hcl(H_ORANGE, L_APP), sw))
    for (x, y, sd, rr, farbe) in stuecke:
        aus.append('  <rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" '
                   'fill="%s"/>' % (x, y, sd, sd, rr, farbe))
    return "\n".join(aus) + "\n</svg>\n"

def vektor_android(name_kommentar, einfarbig=False):
    """Androids <vector>: 108 dp Kante, Inhalt im sicheren Bereich.

    Der Vordergrund einer adaptiven Ikone wird beschnitten -- je nach Geraet
    rund, als Squircle oder als Quadrat. Sicher ist nur der mittlere Kreis
    von 66 der 108 dp; alles Wesentliche liegt darin.
    """
    seite = 108.0
    # **Ueber die Diagonale gerechnet, nicht ueber die Breite.** Der sichere
    # Bereich ist ein *Kreis* von 66 der 108 dp. Ein Quadrat passt darin nur,
    # wenn seine **Diagonale** 66 misst, die Kante also 66/Wurzel(2) = 46,7.
    # Mit 62 dp Kante war die Diagonale 88 -- der Starter schnitt die Ecken
    # des Rahmens ab, und das sah aus wie ein Versehen. Es war eins.
    # Streng sicher waeren 66/Wurzel(2) = 46,7 dp -- das wirkt im Starter
    # aber verloren. 52 dp liegen darueber (Diagonale 73,5), ueberstehen die
    # Kreismaske trotzdem: die Ecken des Rahmens sind abgerundet, seine
    # wirksame Diagonale ist also kleiner als die geometrische. Nachgestellt
    # mit einer aufgelegten Kreismaske bei 47, 52, 58 und 66 dp; ab 58
    # beginnt sichtbares Anschneiden.
    aussen = 52.0
    # Der Rahmen stand um 0,36 Rastereinheiten nach aussen, das sind 6 % der
    # Blockkante auf jeder Seite. Ohne ihn fuellen die Kacheln die 52 dp
    # selbst aus -- der sichere Bereich bleibt derselbe.
    block = aussen / 1.12 if RAHMEN else aussen
    rand = (seite - block) / 2
    stuecke, rahmen = teile(seite, rand)
    zeilen = ['<!-- %s -->' % name_kommentar,
              '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
              '    android:width="108dp" android:height="108dp"',
              '    android:viewportWidth="108" android:viewportHeight="108">']
    if rahmen:
        x, y, w, sw, rr = rahmen
        zeilen.append('    <path android:strokeColor="%s" android:strokeWidth="%.2f"'
                      % ("#ffffff" if einfarbig else hcl(H_ORANGE, L_APP), sw))
        zeilen.append('        android:strokeAlpha="%s" android:fillColor="#00000000"'
                      % ("0.55" if einfarbig else "0.42"))
        zeilen.append('        android:pathData="%s"/>' % rundeck_pfad(x, y, w, w, rr))
    for (x, y, sd, rr, farbe) in stuecke:
        zeilen.append('    <path android:fillColor="%s" android:pathData="%s"/>'
                      % ("#ffffff" if einfarbig else farbe, rundeck_pfad(x, y, sd, sd, rr)))
    zeilen.append('</vector>')
    return "\n".join(zeilen) + "\n"

def vektor_verknuepfung(kommentar, koerper):
    """Ein Verknuepfungssymbol: 48 dp, dunkler Grund, orangefarbenes Zeichen.

    Sie erben sonst das Startsymbol -- drei gleiche Kacheln im Menue, an denen
    niemand die Ansichten auseinanderhaelt.
    """
    return ("<!-- %s -->\n"
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="48dp" android:height="48dp"\n'
            '    android:viewportWidth="48" android:viewportHeight="48">\n'
            '    <path android:fillColor="%s" android:pathData="%s"/>\n'
            "%s</vector>\n"
            % (kommentar, GRUND, rundeck_pfad(0, 0, 48, 48, 10.5), koerper))


def _pfad(farbe, d, alpha=None):
    a = ' android:fillAlpha="%.2f"' % alpha if alpha is not None else ""
    return '    <path android:fillColor="%s"%s android:pathData="%s"/>\n' % (farbe, a, d)


def verknuepfungen():
    """Feed, Uhr, Explorer -- dieselbe Familie, drei klar getrennte Umrisse."""
    o = hcl(H_ORANGE, 0.52)
    hell = hcl(H_ORANGE, 0.62)
    aus = {}

    # Feed: die Halde. Nur Quadrate, wie die Anwendung sie packt, ueber der
    # Grundlinie -- das Motiv des alten Zeichens, hier als Unterscheidung.
    k = (_pfad(o, rundeck_pfad(11, 24, 12, 12, 2.4))
         + _pfad(o, rundeck_pfad(25, 28, 8, 8, 1.8))
         + _pfad(hell, rundeck_pfad(15, 14, 8, 8, 1.8), 0.8)
         + _pfad(o, rundeck_pfad(25, 16, 8, 8, 1.8))
         + _pfad(o, rundeck_pfad(11, 38, 22, 2.6, 1.3), 0.85))
    aus["shortcut_feed"] = vektor_verknuepfung("Feed: der Mempool als Halde.", k)

    # Uhr: der Ring sagt Zeit, das Quadrat darin sagt, was sie zaehlt --
    # Bloecke, keine Minuten.
    ring = ('    <path android:strokeColor="%s" android:strokeWidth="3.6"\n'
            '        android:strokeAlpha="0.45" android:fillColor="#00000000"\n'
            '        android:pathData="M24,9 A15,15 0 1 1 23.99,9 Z"/>\n' % o)
    zeiger = ('    <path android:strokeColor="%s" android:strokeWidth="3.6"\n'
              '        android:strokeLineCap="round" android:fillColor="#00000000"\n'
              '        android:pathData="M24,9 A15,15 0 0 1 39,24"/>\n' % hell)
    aus["shortcut_clock"] = vektor_verknuepfung(
        "Uhr: der Ring die Zeit, das Quadrat der Block.",
        ring + zeiger + _pfad(o, rundeck_pfad(18, 18, 12, 12, 2.4)))

    # Explorer: die Lupe ueber einer Kachel.
    lupe = ('    <path android:strokeColor="%s" android:strokeWidth="4"\n'
            '        android:fillColor="#00000000"\n'
            '        android:pathData="M21,17 A11,11 0 1 1 20.99,17 Z"/>\n' % o)
    griff = ('    <path android:strokeColor="%s" android:strokeWidth="4.6"\n'
             '        android:strokeLineCap="round" android:fillColor="#00000000"\n'
             '        android:pathData="M29.5,25.5 L38,34"/>\n' % o)
    aus["shortcut_explorer"] = vektor_verknuepfung(
        "Explorer: die Lupe ueber einer Kachel.",
        lupe + _pfad(hell, rundeck_pfad(15, 11, 12, 12, 2.4), 0.9) + griff)
    return aus


def schreiben(pfad, inhalt, tun):
    p = WURZEL / pfad
    if tun:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(inhalt, encoding="utf-8")
    print("  %s %s" % ("schreibe" if tun else "wuerde schreiben", pfad))

def rendern(svg_pfad, ziel, groesse, tun):
    if tun:
        (WURZEL / ziel).parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["rsvg-convert", "-w", str(groesse), "-h", str(groesse),
                        str(WURZEL / svg_pfad), "-o", str(WURZEL / ziel)], check=True)
    print("  %s %s (%d px)" % ("rendere" if tun else "wuerde rendern", ziel, groesse))

def icns_schreiben(ziel, bilder):
    """Schreibt eine .icns-Datei aus PNG-Daten.

    **Ohne Mac und ohne ImageMagick-Delegat.** Beides stand hier nicht zur
    Verfuegung: `iconutil` gibt es nur auf macOS, und dieses ImageMagick ist
    ohne ICNS gebaut. Das Format ist aber denkbar einfach und braucht keins
    von beidem:

        "icns" | Gesamtlaenge | dann je Bild: Typ | Laenge | Daten

    Alle Laengen sind vier Bytes, gross-endig, und schliessen die acht Bytes
    des Kopfes mit ein. Die hier benutzten Typen tragen unveraendertes PNG.
    """
    import struct
    teile = []
    for typ, daten in bilder:
        teile.append(typ.encode("ascii") + struct.pack(">I", len(daten) + 8) + daten)
    rumpf = b"".join(teile)
    ziel.parent.mkdir(parents=True, exist_ok=True)
    ziel.write_bytes(b"icns" + struct.pack(">I", len(rumpf) + 8) + rumpf)


# Typ -> Kantenlaenge. icp4/icp5 sind die einfachen 16 und 32, ic07 bis ic10
# die grossen, ic11 bis ic14 die verdoppelten fuer Netzhautschirme.
ICNS_TYPEN = [("icp4", 16), ("icp5", 32), ("ic11", 32), ("ic12", 64),
              ("ic07", 128), ("ic13", 256), ("ic08", 256), ("ic14", 512),
              ("ic09", 512), ("ic10", 1024)]

DICHTEN = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
MACOS = [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
         (128, "128x128"), (256, "128x128@2x"), (256, "256x256"),
         (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")]

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pruefen", action="store_true",
                    help="nur zeigen, was entstuende")
    args = ap.parse_args()
    tun = not args.pruefen

    print("Linux und Flatpak:")
    meister = "app/icons/dev.orangedeck.OrangeDeck.svg"
    schreiben(meister, svg_voll(), tun)
    # **Dasselbe Zeichen noch einmal als PNG, und zwar in der Anwendung.**
    # Unter Wayland findet der Fensterverwalter das Symbol ueber die app_id
    # und die .desktop-Datei; unter X11 und XWayland nicht -- dort traegt das
    # Fenster sein Symbol selbst, in `_NET_WM_ICON`. Ohne diese Datei setzt
    # `main.cpp` nichts, und die Fensterleiste zeigt einen leeren Platzhalter
    # (Fedora, 18.09.2026). 256 px reicht: mehr zeigt keine Leiste, und die
    # Datei liegt in den Ressourcen der Anwendung.
    rendern(meister, "app/icons/dev.orangedeck.OrangeDeck-256.png", 256, tun)

    print("Android:")
    schreiben("android/res/drawable/ic_launcher_vordergrund.xml",
              vektor_android("Vordergrund der adaptiven Ikone."), tun)
    schreiben("android/res/drawable/ic_launcher_monochrom.xml",
              vektor_android("Monochrome Ebene fuer eingefaerbte Symbole ab "
                             "Android 13. Ohne sie zeichnet das System sich "
                             "selbst eine, meist schlecht.", einfarbig=True), tun)
    schreiben("android/res/values/ic_launcher_hintergrund.xml",
              '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
              '    <color name="ic_launcher_hintergrund">%s</color>\n</resources>\n'
              % GRUND, tun)
    adaptiv = ('<?xml version="1.0" encoding="utf-8"?>\n'
               '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
               '    <background android:drawable="@color/ic_launcher_hintergrund"/>\n'
               '    <foreground android:drawable="@drawable/ic_launcher_vordergrund"/>\n'
               '    <monochrome android:drawable="@drawable/ic_launcher_monochrom"/>\n'
               '</adaptive-icon>\n')
    schreiben("android/res/mipmap-anydpi-v26/ic_launcher.xml", adaptiv, tun)
    schreiben("android/res/mipmap-anydpi-v26/ic_launcher_round.xml", adaptiv, tun)
    for dichte, px in DICHTEN.items():
        rendern(meister, "android/res/mipmap-%s/ic_launcher.png" % dichte, px, tun)
    for name, inhalt in verknuepfungen().items():
        schreiben("android/res/drawable/%s.xml" % name, inhalt, tun)

    print("Windows:")
    if tun:
        ziel = WURZEL / "packaging/windows/orangedeck.ico"
        ziel.parent.mkdir(parents=True, exist_ok=True)
        teilbilder = []
        for px in (16, 32, 48, 64, 128, 256):
            t = ziel.parent / ("_%d.png" % px)
            subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px),
                            str(WURZEL / meister), "-o", str(t)], check=True)
            teilbilder.append(str(t))
        subprocess.run(["magick"] + teilbilder + [str(ziel)], check=True)
        for t in teilbilder:
            pathlib.Path(t).unlink()
    print("  %s packaging/windows/orangedeck.ico (16..256)"
          % ("schreibe" if tun else "wuerde schreiben"))

    print("macOS:")
    # Das `.iconset` bleibt: wer einen Mac hat, macht daraus mit
    # `iconutil -c icns` dasselbe. Die fertige Datei entsteht aber auch ohne
    # einen -- siehe icns_schreiben().
    for px, name in MACOS:
        rendern(meister, "packaging/macos/orangedeck.iconset/icon_%s.png" % name, px, tun)
    if tun:
        import tempfile
        bilder = []
        with tempfile.TemporaryDirectory() as tmp:
            for typ, px in ICNS_TYPEN:
                t = pathlib.Path(tmp) / ("%s.png" % typ)
                subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px),
                                str(WURZEL / meister), "-o", str(t)], check=True)
                bilder.append((typ, t.read_bytes()))
        icns_schreiben(WURZEL / "packaging/macos/orangedeck.icns", bilder)
    print("  %s packaging/macos/orangedeck.icns (16..1024, ohne Mac erzeugt)"
          % ("schreibe" if tun else "wuerde schreiben"))

if __name__ == "__main__":
    main()
