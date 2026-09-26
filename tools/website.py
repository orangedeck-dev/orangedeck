#!/usr/bin/env python3
"""Erzeugt orangedeck.dev aus je einer Textdatei pro Sprache.

    tools/website.py            bauen nach website/fertig/
    tools/website.py --pruefen  nur zeigen, was entstuende

**Warum ein Erzeuger fuer eine einfache Seite.** Die Anwendung spricht
dreizehn Sprachen, und die Seite soll ihr dorthin folgen. Von Hand hiesse das
dreizehn HTML-Dateien, in denen jede Aenderung dreizehnmal gemacht werden
muss -- die erste vergessene macht die Seite unglaubwuerdig. So ist eine
weitere Sprache **eine Datei** in `website/texte/`, sonst nichts.

Ausgegeben wird nach `website/fertig/`:

    fertig/index.html      leitet nach der Browsersprache weiter
    fertig/en/index.html   je Sprache eine Seite
    fertig/de/index.html
    fertig/stil.css, fertig/bilder/...

Das Verzeichnis ist der Ausgabeordner fuer Cloudflare Pages.
"""
import argparse, html, json, pathlib, re, shutil

WURZEL = pathlib.Path(__file__).resolve().parent.parent
QUELLE = WURZEL / "website"
ZIEL = QUELLE / "fertig"
# Die Reihenfolge aus ui/qml/strings.js -- so steht die Sprachwahl hier in
# derselben Ordnung wie in der Anwendung.
ORDNUNG = ["de", "en", "es", "fr", "it", "pt-pt", "nl", "ru", "ja", "zh",
           "pt-br", "pl", "cs"]


# **Die Download-Links tragen die Fassung im Dateinamen** (orangedeck-0.2.12-...),
# und `releases/latest/download/` nimmt nur den genauen Namen. Die Nummer
# kommt deshalb aus project() in CMakeLists.txt, derselben Stelle, die der
# Bau benutzt: nach einem Release reicht ein Neubau der Seite. In den Texten
# steht sie als {v}.
# Bildschirmfotos der Anwendung, 1280 x 800, aufgenommen mit
# `tools/ansichten.py` auf Englisch. Name ohne Endung, die Dateien liegen als
# .webp in website/bilder/. Die Unterschriften stehen je Sprache in "bilder".
BILD_B, BILD_H = 1280, 800

FASSUNG = re.search(r"project\(orangedeck-app VERSION ([0-9.]+)",
                    (WURZEL / "CMakeLists.txt").read_text()).group(1)


def sprachen():
    gefunden = {}
    for f in sorted(QUELLE.glob("texte/*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        gefunden[d["code"]] = d
    return [gefunden[c] for c in ORDNUNG if c in gefunden]


def e(s):
    return html.escape(s, quote=True)


def seite(d, alle):
    """Aufbau nach shopatch.com: Kopf mit Navigation und Sprachwahl, Hero mit
    zwei Handlungsaufforderungen und Kennzahlen, dann nummerierte Karten,
    Merkmale, Gruende, Fragen, Fuss."""
    nav = "".join('<a href="%s">%s</a>' % (e(z), e(t)) for t, z in d["nav"])
    # Zwei Formen derselben Wahl: oben das Kuerzel, unten der Name.
    # **Ausgeschrieben passt es nicht.** Zwei Sprachen gehen noch; bei den
    # dreizehn, die die Anwendung spricht, waere die Kopfleiste gesprengt.
    # Im Fuss ist Platz, dort steht der Name.
    def wahlliste(lang):
        return "".join(
            '<a href="../%s/" hreflang="%s"%s>%s</a>'
            % (a["code"], a["code"],
               ' aria-current="true"' if a["code"] == d["code"] else "",
               e(a["code"].upper() if lang else a["name"]))
            for a in alle)
    wahl_kurz, wahl_lang = wahlliste(True), wahlliste(False)
    badges = "".join('<span class="badge">%s</span>' % e(b) for b in d["badges"])
    absaetze = "".join("<p>%s</p>" % e(t) for t in d["was"])
    ansichten = "".join(
        '<li><span class="nr">%02d</span><b>%s</b><span class="txt">%s</span></li>'
        % (i + 1, e(n), e(t)) for i, (n, t) in enumerate(d["ansichten"]))
    wo = "".join('<li><b>%s</b><span class="txt">%s</span></li>' % (e(n), e(t))
                 for n, t in d["wo"])
    warum = "".join(
        '<li><span class="nr">%02d</span><b>%s</b><span class="txt">%s</span></li>'
        % (i + 1, e(n), e(t)) for i, (n, t) in enumerate(d["warum"]))
    holen = "".join(
        ('<a class="knopf" href="%s"><b>%s</b><span>%s</span></a>'
         % (e(u.replace("{v}", FASSUNG)), e(n), e(t.replace("{v}", FASSUNG))))
        if u else ('<div class="knopf wartet"><b>%s</b><span>%s</span></div>' % (e(n), e(t)))
        for n, t, u in d["holen"])
    bilder = "".join(
        '<figure><a href="../bilder/%s.webp"><img src="../bilder/%s.webp" alt="%s" '
        'width="%d" height="%d" loading="lazy"></a><figcaption>%s</figcaption></figure>'
        % (n, n, e(u), BILD_B, BILD_H, e(u)) for n, u in d["bilder"])
    faq = "".join("<details><summary>%s</summary><p>%s</p></details>"
                  % (e(f), e(a)) for f, a in d["faq"])
    return """<!doctype html>
<html lang="%(code)s" dir="%(richtung)s">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(titel)s</title>
<meta name="description" content="%(beschreibung)s">
<meta property="og:title" content="%(titel)s">
<meta property="og:description" content="%(beschreibung)s">
<meta property="og:type" content="website">
<meta property="og:url" content="https://orangedeck.dev/%(code)s/">
<meta property="og:locale" content="%(code)s">
<meta property="og:site_name" content="OrangeDeck">
<meta property="og:image" content="https://orangedeck.dev/bilder/vorschau-%(code)s.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="%(titel)s">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="%(titel)s">
<meta name="twitter:description" content="%(beschreibung)s">
<meta name="twitter:image" content="https://orangedeck.dev/bilder/vorschau-%(code)s.png">
<link rel="canonical" href="https://orangedeck.dev/%(code)s/">
<link rel="icon" href="../bilder/symbol.svg" type="image/svg+xml">
<link rel="stylesheet" href="../stil.css">
%(alternativen)s
<body>
<div class="kopfleiste"><div class="mitte kopf">
  <a class="marke" href="#"><img src="../bilder/symbol.svg" alt="" width="34" height="34"><span>OrangeDeck</span></a>
  <nav class="nav">%(nav)s</nav>
  <nav class="sprachen">%(wahl_kurz)s</nav>
</div></div>

<div class="mitte">
  <header class="hero">
    <h1>%(hero_titel)s</h1>
    <p class="fuehrend">%(hero_text)s</p>
    <div class="knopfreihe">
      <a class="tat" href="%(cta1z)s">%(cta1)s</a>
      <a class="tat zweit" href="%(cta2z)s">%(cta2)s</a>
    </div>
    <div class="badges">%(badges)s</div>
  </header>

  <section class="schau">
    <!-- **Das Standbild steht darunter, nicht daneben.** `live.js` blendet es
         erst aus, wenn die ersten Transaktionen angekommen sind; ohne
         JavaScript, ohne Verbindung zu mempool.space und bei
         `prefers-reduced-motion` bleibt es liegen. Eine Seite, deren
         Herzstueck ein leeres Loch ist, waere schlechter als eine mit einem
         Bild -- und ein Pruefer wie ein Crawler sieht genau das zuerst. -->
    <div id="live" class="live">
      <img class="live-standbild" src="../bilder/feed.webp" alt="%(feed_alt)s" width="1280" height="800">
    </div>
  </section>

  <section id="was">
    <h2>%(was_titel)s</h2>
    %(absaetze)s
  </section>

  <section id="ansichten">
    <h2>%(ansichten_titel)s</h2>
    <ul class="karten">%(ansichten)s</ul>
  </section>

  <section id="bilder">
    <h2>%(bilder_titel)s</h2>
    <div class="galerie">%(bilder)s</div>
  </section>

  <section id="wo">
    <h2>%(wo_titel)s</h2>
    <ul class="karten schlicht">%(wo)s</ul>
  </section>

  <section id="warum">
    <h2>%(warum_titel)s</h2>
    <ul class="karten">%(warum)s</ul>
  </section>

  <section id="holen">
    <h2>%(holen_titel)s</h2>
    <div class="knopfreihe">%(holen)s</div>
  </section>

  <section id="faq">
    <h2>%(faq_titel)s</h2>
    <div class="fragen">%(faq)s</div>
  </section>

  <!-- Hier kommt spaeter der Spendenteil hin: eine wechselnde Adresse, damit
       sich Zahlungen nicht einer einzigen zuordnen lassen. Braucht einen xpub
       und eine Ableitung, also mehr als eine statische Seite -- deshalb
       bewusst noch nicht drin. -->

  <footer>
    <p class="fuss-tat"><a class="tat" href="#holen">%(fuss_cta)s</a></p>
    <p>%(fuss_lizenz)s %(fuss_herkunft)s</p>
    <p><a href="%(repo)s">github.com/orangedeck-dev/orangedeck</a></p>
    <p class="klein">%(sprache_waehlen)s</p>
    <nav class="sprachen">%(wahl_lang)s</nav>
  </footer>
</div>
<script type="application/ld+json">%(ldjson)s</script>
<script>window.ORANGEDECK_LIVE = %(live_json)s;</script>
<script src="../mondrian.js"></script>
<script src="../colors.js"></script>
<script src="../live.js" defer></script>
</body>
</html>
""" % {"code": d["code"], "richtung": d["richtung"], "titel": e(d["titel"]),
       "beschreibung": e(d["beschreibung"]), "nav": nav, "wahl_kurz": wahl_kurz, "wahl_lang": wahl_lang,
       "hero_titel": e(d["hero_titel"]), "hero_text": e(d["hero_text"]),
       "cta1": e(d["hero_cta1"]), "cta1z": e(d["hero_cta1_ziel"]),
       "cta2": e(d["hero_cta2"]), "cta2z": e(d["hero_cta2_ziel"]),
       "badges": badges, "was_titel": e(d["was_titel"]), "absaetze": absaetze,
       "ansichten_titel": e(d["ansichten_titel"]), "ansichten": ansichten,
       "wo_titel": e(d["wo_titel"]), "wo": wo,
       "warum_titel": e(d["warum_titel"]), "warum": warum,
       "holen_titel": e(d["holen_titel"]), "holen": holen,
       "faq_titel": e(d["faq_titel"]), "faq": faq,
       "bilder_titel": e(d["bilder_titel"]), "bilder": bilder,
       "fuss_cta": e(d["fuss_cta"]), "fuss_lizenz": e(d["fuss_lizenz"]),
       "fuss_herkunft": e(d["fuss_herkunft"]), "repo": e(d["repo"]),
       "sprache_waehlen": e(d["sprache_waehlen"]),
       # Die Beschriftungen des bewegten Kopfes gehen als JSON hinein --
       # `live.js` traegt selbst keinen Text, sonst waere es die vierzehnte
       # Sprachdatei.
       "live_json": json.dumps(d.get("live", {}), ensure_ascii=False,
                               separators=(",", ":")),
       "feed_alt": e(d["ansichten"][0][1]),
       "ldjson": ldjson(d),
       "alternativen": "\n".join(
           '<link rel="alternate" hreflang="%s" href="https://orangedeck.dev/%s/">'
           % (a["code"], a["code"]) for a in alle)
       + '\n<link rel="alternate" hreflang="x-default" href="https://orangedeck.dev/en/">'}


def robots():
    """**Ausdruecklich statt stillschweigend.**

    Ohne Datei gilt zwar "alles erlaubt", aber Cloudflare Pages liefert jede
    unbekannte Adresse mit **HTTP 200** und dem Inhalt der Sprachweiche aus --
    ein Crawler, der `robots.txt` holt, bekommt also HTML mit Status 200 und
    muss raten, was das soll. Dieselbe Falle trifft `sitemap.xml`: bei Google
    eingereicht, antwortet sie mit einer HTML-Seite.

    Die KI-Crawler stehen namentlich da, obwohl `*` sie schon einschliesst.
    Nicht aus Technik, sondern als Aussage: dieses Projekt will gelesen
    werden.
    """
    return """# OrangeDeck -- https://orangedeck.dev
# Alles offen. Auch fuer die, die daraus Antworten bauen.

User-agent: *
Allow: /

# Ausdruecklich willkommen
User-agent: GPTBot
Allow: /
User-agent: OAI-SearchBot
Allow: /
User-agent: ChatGPT-User
Allow: /
User-agent: ClaudeBot
Allow: /
User-agent: Claude-SearchBot
Allow: /
User-agent: PerplexityBot
Allow: /
User-agent: Google-Extended
Allow: /
User-agent: Applebot-Extended
Allow: /
User-agent: Bingbot
Allow: /

Sitemap: https://orangedeck.dev/sitemap.xml
"""


def sitemap(alle):
    """Jede Sprachseite einmal, mit den Geschwistern daneben.

    `xhtml:link` wiederholt, was im Kopf der Seite schon steht -- Google
    verlangt beides, sonst gilt die Sprachverknuepfung als unvollstaendig.
    """
    zeilen = ['<?xml version="1.0" encoding="UTF-8"?>',
              '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"',
              '        xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for d in alle:
        zeilen.append("  <url>")
        zeilen.append("    <loc>https://orangedeck.dev/%s/</loc>" % d["code"])
        for a in alle:
            zeilen.append('    <xhtml:link rel="alternate" hreflang="%s" href="https://orangedeck.dev/%s/"/>'
                          % (a["code"], a["code"]))
        zeilen.append('    <xhtml:link rel="alternate" hreflang="x-default" href="https://orangedeck.dev/en/"/>')
        zeilen.append("    <changefreq>weekly</changefreq>")
        zeilen.append("  </url>")
    zeilen.append("</urlset>")
    return "\n".join(zeilen) + "\n"


def llmstxt(alle):
    """Die Kurzfassung in Klartext, an einem festen Ort.

    Gedacht fuer Systeme, die eine Seite nicht rendern, sondern lesen. Was
    hier steht, ist dasselbe wie auf der Seite -- nur ohne Navigation,
    Bildunterschriften und Fusszeile dazwischen. **Keine zweite Wahrheit**:
    steht hier etwas anderes als auf der Seite, ist eines von beidem falsch.
    """
    d = next((x for x in alle if x["code"] == "en"), alle[0])
    z = ["# OrangeDeck", "", "> " + d["beschreibung"], "",
         d.get("seo_kurz", ""), "", "## " + d["ansichten_titel"], ""]
    for n, t in d["ansichten"]:
        z.append("- **%s**: %s" % (n, t))
    z += ["", "## " + d["wo_titel"], ""]
    for n, t in d["wo"]:
        z.append("- **%s**: %s" % (n, t))
    z += ["", "## Data sources", "",
          "- Blocks, mempool, fees, hashrate: wss://mempool.space/api/v1/ws, or your own instance",
          "- Price and trades: Binance, Bybit, OKX public streams",
          "- Liquidations: Bybit, OKX",
          "- Open interest (heatmap model): Binance futures data",
          "- Your own miner: http://<bitaxe>/api/system/info, never leaves the home network",
          "", "## " + d["faq_titel"], ""]
    for f, a in d["faq"]:
        z += ["### " + f, "", a, ""]
    z += ["## Origin", "",
          "The tile packing and colour model are ports from bitfeed (MIT, mononaut).",
          "OrangeDeck itself is MIT licensed, copyright 2026 Satoshoe.",
          "Source: " + d["repo"], ""]
    return "\n".join(z)


def seite404(alle):
    """**Cloudflare Pages liefert sonst jede falsche Adresse mit 200 aus.**

    Gemessen am 06.09.2026: `/robots.txt` und `/llms.txt` gaben die
    Sprachweiche zurueck, Status 200. Fuer eine Suchmaschine ist damit jede
    vertippte Adresse eine eigene, indexierbare Seite mit demselben Inhalt --
    und `robots.txt` ist HTML. Eine `404.html` im Ausgabeverzeichnis stellt
    das ab; Pages nimmt sie und antwortet dann mit dem richtigen Status.
    """
    liste = " ".join('<a href="/%s/">%s</a>' % (a["code"], e(a["name"])) for a in alle)
    return """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>404 — OrangeDeck</title>
<meta name="robots" content="noindex">
<link rel="icon" href="/bilder/symbol.svg" type="image/svg+xml">
<link rel="stylesheet" href="/stil.css">
<body>
<div class="mitte"><header>
  <div class="marke"><img src="/bilder/symbol.svg" alt="" width="72" height="72"><h1>404</h1></div>
  <p class="unterzeile">Diese Seite gibt es nicht. / This page does not exist.</p>
  <p class="sprachen">%s</p>
</header></div>
</body>
</html>
""" % liste


def ldjson(d):
    """Strukturierte Daten: was das Ding ist, und die Fragen mit Antworten.

    **Nicht fuer Google allein.** ChatGPT, Perplexity und die Uebersichten in
    der Suche zitieren, was sich zitieren laesst -- eine Frage mit einer
    vollstaendigen Antwort daneben, ohne Kontext ringsherum. Die Fragen stehen
    ohnehin schon auf der Seite; hier bekommen sie eine Form, die eine
    Maschine ohne Raten liest.

    `applicationCategory` ist absichtlich `UtilityApplication` und nicht
    `FinanceApplication`: das Programm bewegt kein Geld, es sieht zu. Eine
    Kennzeichnung, die mehr verspricht, als das Programm tut, faellt spaeter
    auf einen zurueck.
    """
    frei = {"@type": "Offer", "price": "0", "priceCurrency": "EUR"}
    anwendung = {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "OrangeDeck",
        "url": "https://orangedeck.dev/%s/" % d["code"],
        "inLanguage": d["code"],
        "description": d.get("seo_kurz") or d["beschreibung"],
        "applicationCategory": "UtilityApplication",
        "operatingSystem": "Linux, Windows, Android",
        "license": "https://opensource.org/licenses/MIT",
        "isAccessibleForFree": True,
        "offers": frei,
        "image": "https://orangedeck.dev/bilder/vorschau-%s.png" % d["code"],
        # Der Feed steht oben als Standbild, die Galerie zeigt die anderen.
        "screenshot": ["https://orangedeck.dev/bilder/%s.webp" % n
                       for n in ["feed"] + [n for n, _ in d["bilder"]]],
        "codeRepository": d["repo"],
        "author": {"@type": "Person", "name": "Satoshoe",
                   "url": "https://github.com/satoshoe-dev"},
        "featureList": [n for n, _ in d["ansichten"]],
    }
    fragen = {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "inLanguage": d["code"],
        "mainEntity": [{"@type": "Question", "name": f,
                        "acceptedAnswer": {"@type": "Answer", "text": a}}
                       for f, a in d["faq"]],
    }
    return json.dumps([anwendung, fragen], ensure_ascii=False,
                      separators=(",", ":"))


def geteilt(quelle, ziel):
    """`ui/qml/*.js` unveraendert uebernehmen, ohne die QML-Zeile.

    **Nicht nachgebaut, sondern dieselbe Datei.** `mondrian.js` setzt die
    Kacheln und `colors.js` faerbt sie -- in der Anwendung wie auf der Seite.
    Ein Nachbau waere im ersten Monat gleich und im dritten anders, und dann
    zeigt die Seite eine Packung, die es nirgends gibt.

    Herausfallen muss allein `.pragma library`: das ist eine Anweisung an die
    QML-Maschine und in einem Browser ein Syntaxfehler -- die Datei bricht
    dann stillschweigend ab, und `MondrianLayout` gibt es nicht. Der Rest ist
    gewoehnliches JavaScript; in einem klassischen <script> werden die
    Funktionen zu globalen Namen, genau wie `live.js` sie erwartet.
    """
    text = quelle.read_text(encoding="utf-8")
    ohne = "\n".join(z for z in text.splitlines()
                     if z.strip() != ".pragma library")
    kopf = ("// Uebernommen aus ui/qml/%s durch tools/website.py.\n"
            "// Nicht hier bearbeiten -- die Quelle liegt in der Anwendung.\n"
            % quelle.name)
    ziel.write_text(kopf + ohne + "\n", encoding="utf-8")


def weiche(alle):
    """Die Wurzel waehlt die Sprache nach dem Browser, mit Englisch als Rueckfall.

    Ohne JavaScript landet man ueber das <noscript> trotzdem irgendwo -- eine
    Seite, die ohne Skript leer bleibt, waere fuer einen Pruefer wertlos.
    """
    codes = ",".join('"%s"' % a["code"] for a in alle)
    liste = " ".join('<a href="%s/">%s</a>' % (a["code"], e(a["name"])) for a in alle)
    return """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OrangeDeck</title>
<link rel="icon" href="bilder/symbol.svg" type="image/svg+xml">
<link rel="stylesheet" href="stil.css">
<link rel="canonical" href="https://orangedeck.dev/en/">
<script>
  var da = [%s];
  var w = (navigator.languages || [navigator.language || "en"]);
  var ziel = "en";
  for (var i = 0; i < w.length && ziel === "en"; i++) {
    var l = String(w[i]).toLowerCase();
    if (da.indexOf(l) >= 0) { ziel = l; break; }
    var k = l.split("-")[0];
    if (da.indexOf(k) >= 0) { ziel = k; break; }
  }
  location.replace(ziel + "/");
</script>
<body>
<div class="mitte"><header>
  <div class="marke"><img src="bilder/symbol.svg" alt="" width="72" height="72"><h1>OrangeDeck</h1></div>
  <noscript><p class="unterzeile">%s</p></noscript>
</header></div>
</body>
</html>
""" % (codes, liste)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pruefen", action="store_true")
    args = ap.parse_args()
    tun = not args.pruefen
    alle = sprachen()
    if not alle:
        raise SystemExit("Keine Sprachdateien unter website/texte/")

    if tun and ZIEL.exists():
        shutil.rmtree(ZIEL)
    for d in alle:
        p = ZIEL / d["code"] / "index.html"
        if tun:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(seite(d, alle), encoding="utf-8")
        print("  %s %s" % ("schreibe" if tun else "wuerde", p.relative_to(WURZEL)))
    if tun:
        (ZIEL / "index.html").write_text(weiche(alle), encoding="utf-8")
        shutil.copy2(QUELLE / "stil.css", ZIEL / "stil.css")
        shutil.copy2(QUELLE / "live.js", ZIEL / "live.js")
        (ZIEL / "robots.txt").write_text(robots(), encoding="utf-8")
        (ZIEL / "sitemap.xml").write_text(sitemap(alle), encoding="utf-8")
        (ZIEL / "llms.txt").write_text(llmstxt(alle), encoding="utf-8")
        (ZIEL / "404.html").write_text(seite404(alle), encoding="utf-8")
        shutil.copytree(QUELLE / "bilder", ZIEL / "bilder")
        for name in ("mondrian.js", "colors.js"):
            geteilt(WURZEL / "ui" / "qml" / name, ZIEL / name)
    print("  %s website/fertig/index.html (Sprachweiche)" % ("schreibe" if tun else "wuerde"))
    print("  %s stil.css, live.js, bilder/ und die zwei geteilten Bausteine"
          % ("kopiere" if tun else "wuerde kopieren"))
    print("  %s robots.txt, sitemap.xml, llms.txt und 404.html"
          % ("schreibe" if tun else "wuerde schreiben"))
    print("\n%d Sprachen: %s" % (len(alle), ", ".join(a["code"] for a in alle)))


if __name__ == "__main__":
    main()
