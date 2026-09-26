#!/usr/bin/env python3
"""Das Vorschaubild fuer geteilte Links (og:image), je Sprache eines.

    tools/vorschau.py            schreibt website/bilder/vorschau-<code>.png

1200 x 630, gezeichnet von Chrome aus einer kleinen HTML-Seite. Die Texte
kommen aus `website/texte/<code>.json` (hero_titel, die Namen der Ansichten,
vorschau_fuss), rechts daneben steht ein Ausschnitt aus `bilder/feed.webp`.
Bis zum 26.09.2026 gab es nur ein deutsches Bild, das auch die englische
Seite zeigte.

Nach neuen Bildern oder geaenderten Texten neu laufen lassen, danach
`tools/website.py`.
"""
import json, pathlib, shutil, subprocess, tempfile

WURZEL = pathlib.Path(__file__).resolve().parent.parent
QUELLE = WURZEL / "website"
BILDER = QUELLE / "bilder"

# Ausschnitt aus feed.webp (1280 x 800): links, oben, Breite, Hoehe.
# Der Block in der Mitte und darunter die Halde des Mempools.
AUSSCHNITT = (330, 150, 600, 640)

VORLAGE = """<!doctype html>
<meta charset="utf-8">
<style>
  html, body { margin: 0; width: 1200px; height: 630px; overflow: hidden; }
  body { background: #12101a; color: #e6e0e9; font-family: "Noto Sans", system-ui, sans-serif;
         display: grid; grid-template-columns: 610px 590px; }
  .text { padding: 70px 30px 0 60px; }
  .marke { display: flex; align-items: center; gap: 26px; }
  .marke img { width: 84px; height: 84px; }
  .marke b { font-size: 62px; letter-spacing: -1px; }
  h1 { color: #f7931a; font-weight: 500; font-size: 38px; margin: 54px 0 18px; }
  .ansichten { color: #b3adbf; font-size: 22px; line-height: 1.5; margin: 0; }
  .fuss { color: #8a8496; font-size: 21px; margin-top: 34px; }
  .bild { background: #0b0a10 url("%(bild)s") no-repeat;
          background-size: %(bg_b)dpx %(bg_h)dpx; background-position: %(bg_x)dpx %(bg_y)dpx; }
</style>
<div class="text">
  <div class="marke"><img src="%(symbol)s" alt=""><b>OrangeDeck</b></div>
  <h1>%(titel)s</h1>
  <p class="ansichten">%(ansichten)s</p>
  <p class="fuss">%(fuss)s</p>
</div>
<div class="bild"></div>
"""


def chrome():
    for n in ("google-chrome-stable", "chromium", "google-chrome"):
        if shutil.which(n):
            return n
    raise SystemExit("Kein Chrome gefunden")


def main():
    x, y, b, h = AUSSCHNITT
    # Der Ausschnitt fuellt die rechte Flaeche (590 x 630) in der Hoehe.
    mass = 630 / h
    werte = {"bild": (BILDER / "feed.webp").as_uri(),
             "symbol": (BILDER / "symbol.svg").as_uri(),
             "bg_b": round(1280 * mass), "bg_h": round(800 * mass),
             "bg_x": round(-x * mass - (b * mass - 590) / 2), "bg_y": round(-y * mass)}
    for f in sorted(QUELLE.glob("texte/*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        esc = lambda s: s.replace("&", "&amp;").replace("<", "&lt;")
        seite = VORLAGE % dict(werte, titel=esc(d["hero_titel"]),
                               ansichten=" · ".join(esc(n) for n, _ in d["ansichten"]),
                               fuss="<br>".join(esc(z) for z in d["vorschau_fuss"]))
        with tempfile.TemporaryDirectory() as tmp:
            html = pathlib.Path(tmp) / "vorschau.html"
            html.write_text(seite, encoding="utf-8")
            ziel = BILDER / ("vorschau-%s.png" % d["code"])
            subprocess.run([chrome(), "--headless=new", "--user-data-dir=" + tmp + "/profil",
                            "--hide-scrollbars", "--allow-file-access-from-files",
                            "--force-device-scale-factor=1", "--window-size=1200,630",
                            "--screenshot=" + str(ziel), html.as_uri()],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("  schreibe", ziel.relative_to(WURZEL))


if __name__ == "__main__":
    main()
