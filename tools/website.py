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

    fertig/index.html               leitet nach der Browsersprache weiter
    fertig/<code>/index.html        je Sprache die Startseite
    fertig/<code>/<slug>/index.html die Unterseiten aus "unterseiten"
    fertig/<code>/changelog/        was ist neu, aus website/aenderungen.json
    fertig/stil.css, fertig/bilder/..., _headers, sitemap.xml, llms.txt

Das Verzeichnis ist der Ausgabeordner fuer Cloudflare Pages.
"""
import argparse, datetime, html, json, pathlib, re, shutil, subprocess

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


# og:locale will Sprache und Land ("de_DE"), hreflang nimmt die Codes aus
# ORDNUNG, wie sie sind.
LOCALE = {"de": "de_DE", "en": "en_US", "es": "es_ES", "fr": "fr_FR", "it": "it_IT",
          "pt-pt": "pt_PT", "nl": "nl_NL", "ru": "ru_RU", "ja": "ja_JP", "zh": "zh_CN",
          "pt-br": "pt_BR", "pl": "pl_PL", "cs": "cs_CZ"}

SEITE = "https://orangedeck.dev"
APP_ID = SEITE + "/#app"
# Wo OrangeDeck sonst noch steht. Fuer Suchmaschinen und KI-Systeme ist das
# die Verknuepfung, an der sie festmachen, dass all das dasselbe Projekt ist.
ANDERSWO = ["https://github.com/orangedeck-dev/orangedeck",
            "https://github.com/orangedeck-dev/dms-plugin",
            "https://fdroid.orangedeck.dev/repo/",
            "https://github.com/AvengeMedia/dms-plugin-registry/blob/master/plugins/orangedeck-dev-orangedeck.json"]


# Die Schluessel aus ui/qml/strings.js, die der bewegte Kopf braucht. Er
# zeigt die Ansichten der Anwendung und soll dieselben Woerter tragen.
LIVE_SCHLUESSEL = [
    "tab.feed", "tab.clock", "tab.miner", "tab.explorer", "tab.market",
    "block", "blockHeight", "lastBlock", "nextBlock", "fee", "hashrate", "difficulty",
    "mempool", "price", "clock.moscow", "clock.remaining", "clock.halving",
    "clock.diffLine", "duration.dayHour", "duration.min", "ago.min", "ago.now",
    "in.min", "feed.movedValue", "feed.avgFee", "feed.mempoolLine", "feed.sizeValue",
    "feed.ageScale", "feed.bytes", "feed.inMempool", "feed.nextBlockLine",
    "txlist.count", "color.label", "color.age", "color.fee", "color.type",
    "miner.paneDevice", "miner.paneNet", "net.nextAdj", "net.blockTime",
    "net.lastBlock", "net.justNow", "chain.label", "proj.unchanged",
    "explorer.browseAll", "explorer.inMempool", "search.placeholder",
    "market.sub.price", "market.sub.liq", "market.sub.heat", "market.trades",
    "market.candles", "market.line", "market.volume", "market.cvd", "market.24h",
    "market.waiting"]


def app_texte():
    """Die Beschriftungen aus strings.js, je Sprache ein Woerterbuch.

    strings.js ist JavaScript und traegt Kommentare und Zeilenumbrueche in
    seinen Listen; statt es nachzubauen, laesst Node die Datei selbst laufen.
    Leere Eintraege fallen auf Englisch zurueck, wie `t()` in der Anwendung.
    """
    quelle = (WURZEL / "ui" / "qml" / "strings.js").read_text(encoding="utf-8")
    quelle = "\n".join(z for z in quelle.splitlines() if z.strip() != ".pragma library")
    skript = quelle + """
var aus = {};
LANGS.forEach(function (l, i) {
  var d = {};
  %s.forEach(function (k) {
    var z = S[k];
    if (!z) throw new Error("strings.js kennt " + k + " nicht");
    d[k] = z[i] || z[1];
  });
  aus[l] = d;
});
process.stdout.write(JSON.stringify(aus));
""" % json.dumps(LIVE_SCHLUESSEL)
    lauf = subprocess.run(["node", "-"], input=skript, capture_output=True, text=True, check=True)
    return json.loads(lauf.stdout)


def aenderungen():
    return json.loads((QUELLE / "aenderungen.json").read_text(encoding="utf-8"))


def datum(iso, code):
    """Deutsch schreibt 25.09.2026, alle anderen ISO wie die Anwendung auf
    Englisch: da verwechselt niemand Tag und Monat."""
    if code == "de":
        j, m, t = iso.split("-")
        return "%s.%s.%s" % (t, m, j)
    return iso


def rahmen(d, alle, pfad, titel, beschreibung, inhalt, ld, tiefe):
    """Kopf, Leiste und Fuss, gleich fuer jede Seite.

    `pfad` ist der Teil nach dem Sprachcode ("" fuer die Startseite,
    "bitaxe/" fuer eine Unterseite), `tiefe` die Zahl der Ordner unter der
    Wurzel. Die Verweise bleiben relativ, damit die fertige Seite auch als
    Datei im Browser aufgeht."""
    auf = "../" * tiefe
    start = "" if not pfad else "../"
    nav = "".join('<a href="%s%s">%s</a>' % (start, e(z), e(t)) for t, z in d["nav"])
    # **Bei dreizehn Sprachen passt die Wahl nicht mehr in die Kopfleiste.**
    # Oben steht dann nur das eigene Kuerzel und springt zur Liste im Fuss.
    if len(alle) > 3:
        wahl_kurz = '<a href="#sprache" aria-current="true">%s</a>' % e(d["code"].upper())
    else:
        wahl_kurz = "".join(
            '<a href="%s%s/%s" hreflang="%s"%s>%s</a>'
            % (auf, a["code"], pfad, a["code"],
               ' aria-current="true"' if a["code"] == d["code"] else "", e(a["code"].upper()))
            for a in alle)
    wahl_lang = "".join(
        '<a href="%s%s/%s" hreflang="%s" lang="%s"%s>%s</a>'
        % (auf, a["code"], pfad, a["code"], a["code"],
           ' aria-current="true"' if a["code"] == d["code"] else "", e(a["name"]))
        for a in alle)
    mehr = "".join('<a href="%s%s/">%s</a>' % (start, u["slug"], e(u["name"]))
                   for u in d["unterseiten"])
    mehr += '<a href="%schangelog/">%s</a>' % (start, e(d["neu_link"]))
    url = "%s/%s/%s" % (SEITE, d["code"], pfad)
    alternativen = "\n".join(
        '<link rel="alternate" hreflang="%s" href="%s/%s/%s">' % (a["code"], SEITE, a["code"], pfad)
        for a in alle) + '\n<link rel="alternate" hreflang="x-default" href="%s/en/%s">' % (SEITE, pfad)
    vorschau = "%s/bilder/vorschau-%s.png" % (SEITE, d["code"] if (QUELLE / "bilder" / ("vorschau-%s.png" % d["code"])).exists() else "en")
    andere = "\n".join('<meta property="og:locale:alternate" content="%s">' % LOCALE[a["code"]]
                       for a in alle if a["code"] != d["code"])
    return """<!doctype html>
<html lang="%(code)s" dir="%(richtung)s">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(titel)s</title>
<meta name="description" content="%(beschreibung)s">
<meta property="og:title" content="%(titel)s">
<meta property="og:description" content="%(beschreibung)s">
<meta property="og:type" content="website">
<meta property="og:url" content="%(url)s">
<meta property="og:locale" content="%(locale)s">
%(andere)s
<meta property="og:site_name" content="OrangeDeck">
<meta property="og:image" content="%(vorschau)s">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="%(titel)s">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="%(titel)s">
<meta name="twitter:description" content="%(beschreibung)s">
<meta name="twitter:image" content="%(vorschau)s">
<link rel="canonical" href="%(url)s">
<link rel="icon" href="%(auf)sbilder/symbol.svg" type="image/svg+xml">
<link rel="stylesheet" href="%(auf)sstil.css">
%(alternativen)s
<body>
<div class="kopfleiste"><div class="mitte kopf">
  <a class="marke" href="%(start)s#"><img src="%(auf)sbilder/symbol.svg" alt="" width="34" height="34"><span>OrangeDeck</span></a>
  <nav class="nav">%(nav)s</nav>
  <nav class="sprachen">%(wahl_kurz)s</nav>
</div></div>

<div class="mitte">
%(inhalt)s

  <footer>
    <p class="fuss-tat"><a class="tat" href="%(start)s#holen">%(fuss_cta)s</a></p>
    <p class="klein">%(mehr_titel)s</p>
    <nav class="sprachen">%(mehr)s</nav>
    <p>%(fuss_lizenz)s %(fuss_herkunft)s</p>
    <p><a href="%(repo)s">github.com/orangedeck-dev/orangedeck</a></p>
    <p class="klein" id="sprache">%(sprache_waehlen)s</p>
    <nav class="sprachen">%(wahl_lang)s</nav>
  </footer>
</div>
<script type="application/ld+json">%(ld)s</script>
%(skripte)s
</body>
</html>
""" % {"code": d["code"], "richtung": d["richtung"], "titel": e(titel),
       "beschreibung": e(beschreibung), "url": url, "locale": LOCALE[d["code"]],
       "andere": andere, "vorschau": vorschau, "auf": auf, "start": start or "",
       "alternativen": alternativen, "nav": nav, "wahl_kurz": wahl_kurz,
       "wahl_lang": wahl_lang, "mehr": mehr, "mehr_titel": e(d["mehr_titel"]),
       "inhalt": inhalt, "fuss_cta": e(d["fuss_cta"]), "fuss_lizenz": e(d["fuss_lizenz"]),
       "fuss_herkunft": e(d["fuss_herkunft"]), "repo": e(d["repo"]),
       "sprache_waehlen": e(d["sprache_waehlen"]),
       "ld": json.dumps(ld, ensure_ascii=False, separators=(",", ":")),
       "skripte": "" if pfad else (
           '<script>window.ORANGEDECK_LIVE = %s;</script>\n'
           '<script src="../mondrian.js"></script>\n'
           '<script src="../colors.js"></script>\n'
           '<script src="../live.js" defer></script>'
           % json.dumps({"s": APP_TEXTE[d["code"]]}, ensure_ascii=False, separators=(",", ":")))}


def seite(d, alle):
    """Die Startseite. Aufbau nach shopatch.com: Kopf mit Navigation und
    Sprachwahl, Hero mit zwei Handlungsaufforderungen und Kennzahlen, dann
    nummerierte Karten, Merkmale, Gruende, Fragen, Fuss."""
    neueste = aenderungen()[0]
    badges = "".join('<span class="badge">%s</span>' % e(b) for b in d["badges"])
    absaetze = "".join("<p>%s</p>" % e(t) for t in d["was"])
    ansichten = "".join(
        '<li><span class="nr">%02d</span><b>%s</b><span class="txt">%s</span></li>'
        % (i + 1, e(n), e(t)) for i, (n, t) in enumerate(d["ansichten"]))
    wo = "".join('<li><b>%s</b><span class="txt">%s</span></li>' % (e(n), e(t))
                 for n, t in d["wo"])
    einsatz = "".join(
        '<li><a href="%s/"><b>%s</b><span class="txt">%s</span></a></li>'
        % (u["slug"], e(u["name"]), e(u["karte"])) for u in d["unterseiten"])
    quellen = "".join('<li><b>%s</b><span class="txt">%s</span></li>' % (e(n), e(t))
                      for n, t in d["quellen"])
    warum = "".join(
        '<li><span class="nr">%02d</span><b>%s</b><span class="txt">%s</span></li>'
        % (i + 1, e(n), e(t)) for i, (n, t) in enumerate(d["warum"]))
    holen = "".join(
        '<a class="knopf" href="%s"><b>%s</b><span>%s</span></a>'
        % (e(u.replace("{v}", FASSUNG)), e(n), e(t.replace("{v}", FASSUNG)))
        for n, t, u in d["holen"])
    bilder = "".join(
        '<figure><a href="../bilder/%s.webp"><img src="../bilder/%s.webp" alt="%s" '
        'width="%d" height="%d" loading="lazy"></a><figcaption>%s</figcaption></figure>'
        % (n, n, e(u), BILD_B, BILD_H, e(u)) for n, u in d["bilder"])
    faq = "".join("<details><summary>%s</summary><p>%s</p></details>"
                  % (e(f), e(a)) for f, a in d["faq"])
    fassung = e(d["hero_fassung"].replace("{v}", FASSUNG)
                .replace("{datum}", datum(neueste["datum"], d["code"])))
    inhalt = """  <header class="hero">
    <h1>%(hero_titel)s</h1>
    <p class="fuehrend">%(hero_text)s</p>
    <div class="knopfreihe">
      <a class="tat" href="%(cta1z)s">%(cta1)s</a>
      <a class="tat zweit" href="%(cta2z)s">%(cta2)s</a>
    </div>
    <div class="badges">%(badges)s</div>
    <p class="fassung">%(fassung)s · <a href="changelog/">%(neu_link)s</a></p>
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

  <section id="einsatz">
    <h2>%(einsatz_titel)s</h2>
    <ul class="karten verweise">%(einsatz)s</ul>
  </section>

  <section id="wo">
    <h2>%(wo_titel)s</h2>
    <ul class="karten schlicht">%(wo)s</ul>
  </section>

  <section id="quellen">
    <h2>%(quellen_titel)s</h2>
    <ul class="karten schlicht">%(quellen)s</ul>
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
       bewusst noch nicht drin. -->""" % {
        "hero_titel": e(d["hero_titel"]), "hero_text": e(d["hero_text"]),
        "cta1": e(d["hero_cta1"]), "cta1z": e(d["hero_cta1_ziel"]),
        "cta2": e(d["hero_cta2"]), "cta2z": e(d["hero_cta2_ziel"]),
        "badges": badges, "fassung": fassung, "neu_link": e(d["neu_link"]),
        "feed_alt": e(d["ansichten"][0][1]),
        "was_titel": e(d["was_titel"]), "absaetze": absaetze,
        "ansichten_titel": e(d["ansichten_titel"]), "ansichten": ansichten,
        "bilder_titel": e(d["bilder_titel"]), "bilder": bilder,
        "einsatz_titel": e(d["einsatz_titel"]), "einsatz": einsatz,
        "wo_titel": e(d["wo_titel"]), "wo": wo,
        "quellen_titel": e(d["quellen_titel"]), "quellen": quellen,
        "warum_titel": e(d["warum_titel"]), "warum": warum,
        "holen_titel": e(d["holen_titel"]), "holen": holen,
        "faq_titel": e(d["faq_titel"]), "faq": faq}
    return rahmen(d, alle, "", d["titel"], d["beschreibung"], inhalt, ldjson(d), 1)


def pfadleiste(d, name, pfad):
    """BreadcrumbList: Uebersicht > diese Seite."""
    return {"@context": "https://schema.org", "@type": "BreadcrumbList",
            "itemListElement": [
                {"@type": "ListItem", "position": 1, "name": d["zurueck"],
                 "item": "%s/%s/" % (SEITE, d["code"])},
                {"@type": "ListItem", "position": 2, "name": name,
                 "item": "%s/%s/%s" % (SEITE, d["code"], pfad)}]}


def webseite(d, u, pfad):
    return {"@context": "https://schema.org", "@type": "WebPage",
            "name": u["h1"], "description": u["beschreibung"],
            "url": "%s/%s/%s" % (SEITE, d["code"], pfad), "inLanguage": d["code"],
            "isPartOf": {"@type": "WebSite", "name": "OrangeDeck", "url": SEITE + "/"},
            "about": {"@id": APP_ID}}


def unterseite(d, alle, u):
    """Eine Seite je Anliegen, nach dem jemand sucht: Bitaxe-Monitor, Anzeige
    fuer die Wand, DankMaterialShell. Eine einzelne Startseite rankt nur fuer
    wenige Begriffe, und eine Frage mit eigener Seite laesst sich zitieren."""
    pfad = u["slug"] + "/"
    text = "".join("<p>%s</p>" % e(t) for t in u["text"])
    faq = "".join("<details><summary>%s</summary><p>%s</p></details>"
                  % (e(f), e(a)) for f, a in u["faq"])
    inhalt = """  <header class="hero unter">
    <p class="pfad"><a href="../">%(zurueck)s</a> › %(name)s</p>
    <h1>%(h1)s</h1>
  </header>

  <section class="text">
    %(text)s
    <figure class="einzelbild"><img src="../../bilder/%(bild)s.webp" alt="%(alt)s" width="1280" height="800" loading="lazy"></figure>
    <p><a class="tat" href="../#holen">%(cta)s</a></p>
  </section>

  <section>
    <h2>%(faq_titel)s</h2>
    <div class="fragen">%(faq)s</div>
  </section>""" % {"zurueck": e(d["zurueck"]), "name": e(u["name"]), "h1": e(u["h1"]),
                   "text": text, "bild": u["bild"], "alt": e(u["bild_alt"]),
                   "cta": e(d["hero_cta1"]), "faq_titel": e(d["faq_titel"]), "faq": faq}
    ld = [webseite(d, u, pfad), pfadleiste(d, u["name"], pfad),
          {"@context": "https://schema.org", "@type": "FAQPage", "inLanguage": d["code"],
           "mainEntity": [{"@type": "Question", "name": f,
                           "acceptedAnswer": {"@type": "Answer", "text": a}}
                          for f, a in u["faq"]]}]
    return rahmen(d, alle, pfad, u["titel"], u["beschreibung"], inhalt, ld, 2)


def neuseite(d, alle):
    """Was ist neu: jede Fassung mit Datum. Zeigt Suchmaschinen und Lesern,
    dass das Projekt lebt. Die Eintraege stehen in `website/aenderungen.json`,
    auf Deutsch und Englisch; die anderen Sprachen zeigen die englischen und
    sagen das dazu."""
    n = d["neu"]
    pfad = "changelog/"
    teile = []
    for a in aenderungen():
        eigene = a.get(d["code"])
        punkte = eigene or a["en"]
        sprache = "" if eigene else ' lang="en"'
        teile.append('<article><h2>%s <span class="datum">%s</span></h2><ul class="klar"%s>%s</ul></article>'
                     % (e(a["v"]), e(datum(a["datum"], d["code"])), sprache,
                        "".join("<li>%s</li>" % e(p) for p in punkte)))
    hinweis = ("<p>%s</p>" % e(d["nur_englisch"])) if d.get("nur_englisch") else ""
    inhalt = """  <header class="hero unter">
    <p class="pfad"><a href="../">%(zurueck)s</a> › %(h1)s</p>
    <h1>%(h1)s</h1>
    <p class="fuehrend">%(text)s</p>
    %(hinweis)s
  </header>

  <section class="aenderungen">
    %(teile)s
    <p><a href="https://github.com/orangedeck-dev/orangedeck/releases">%(alte)s</a></p>
  </section>""" % {"zurueck": e(d["zurueck"]), "h1": e(n["h1"]), "text": e(n["text"]),
                   "hinweis": hinweis, "teile": "\n    ".join(teile),
                   "alte": e(d["alte_fassungen"])}
    ld = [webseite(d, {"h1": n["h1"], "beschreibung": n["beschreibung"]}, pfad),
          pfadleiste(d, n["h1"], pfad)]
    return rahmen(d, alle, pfad, n["titel"], n["beschreibung"], inhalt, ld, 2)


def alle_pfade(d):
    return [""] + [u["slug"] + "/" for u in d["unterseiten"]] + ["changelog/"]


# Schluessel fuer IndexNow (Bing, Yandex, Seznam, Naver). Die Datei
# <schluessel>.txt im Wurzelverzeichnis beweist, dass die Meldung von hier
# kommt. Gemeldet wird mit tools/indexnow.py nach dem Veroeffentlichen.
INDEXNOW = "2c40db6590d93768908899fec925fa1f"


def kopfzeilen():
    """`_headers` fuer Cloudflare Pages.

    Ohne sie kam alles mit `max-age=0`, auch die Bilder, und jeder Besuch
    lud sie neu. Bilder aendern ihren Namen nicht, wenn sie sich aendern,
    deshalb eine Woche und nicht ein Jahr; CSS und Skripte eine Stunde.
    """
    return """/bilder/*
  Cache-Control: public, max-age=604800
/*.css
  Cache-Control: public, max-age=3600
/*.js
  Cache-Control: public, max-age=3600
"""


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
    """Jede Seite in jeder Sprache einmal, mit den Geschwistern daneben.

    `xhtml:link` wiederholt, was im Kopf der Seite schon steht -- Google
    verlangt beides, sonst gilt die Sprachverknuepfung als unvollstaendig.
    `lastmod` ist der Tag des Baus: gebaut wird nur, wenn sich etwas aendert.
    """
    heute = datetime.date.today().isoformat()
    zeilen = ['<?xml version="1.0" encoding="UTF-8"?>',
              '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"',
              '        xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for pfad in alle_pfade(alle[0]):
        for d in alle:
            zeilen.append("  <url>")
            zeilen.append("    <loc>%s/%s/%s</loc>" % (SEITE, d["code"], pfad))
            for a in alle:
                zeilen.append('    <xhtml:link rel="alternate" hreflang="%s" href="%s/%s/%s"/>'
                              % (a["code"], SEITE, a["code"], pfad))
            zeilen.append('    <xhtml:link rel="alternate" hreflang="x-default" href="%s/en/%s"/>'
                          % (SEITE, pfad))
            zeilen.append("    <lastmod>%s</lastmod>" % heute)
            zeilen.append("  </url>")
    zeilen.append("</urlset>")
    return "\n".join(zeilen) + "\n"


def llmstxt(alle):
    """Die Kurzfassung in Klartext, an einem festen Ort.

    Gedacht fuer Systeme, die eine Seite nicht rendern, sondern lesen. Was
    hier steht, ist dasselbe wie auf der Seite -- nur ohne Navigation,
    Bildunterschriften und Fusszeile dazwischen. **Keine zweite Wahrheit**:
    alles kommt aus derselben Textdatei wie die Seite, auch die Datenquellen.
    """
    d = next((x for x in alle if x["code"] == "en"), alle[0])
    neueste = aenderungen()[0]
    z = ["# OrangeDeck", "", "> " + d["beschreibung"], "",
         d.get("seo_kurz", ""), "",
         "Current version: %s, released %s. Website: %s/en/" % (FASSUNG, neueste["datum"], SEITE),
         "", "## " + d["ansichten_titel"], ""]
    for n, t in d["ansichten"]:
        z.append("- **%s**: %s" % (n, t))
    z += ["", "## " + d["wo_titel"], ""]
    for n, t in d["wo"]:
        z.append("- **%s**: %s" % (n, t))
    z += ["", "## " + d["quellen_titel"], ""]
    for n, t in d["quellen"]:
        z.append("- **%s**: %s" % (n, t))
    z += ["", "## " + d["holen_titel"], ""]
    for n, t, u in d["holen"]:
        z.append("- **%s**: %s %s" % (n, t.replace("{v}", FASSUNG), u.replace("{v}", FASSUNG)))
    z += ["", "## " + d["mehr_titel"], ""]
    for u in d["unterseiten"]:
        z.append("- [%s](%s/en/%s/): %s" % (u["h1"], SEITE, u["slug"], u["beschreibung"]))
    z.append("- [%s](%s/en/changelog/): %s" % (d["neu"]["h1"], SEITE, d["neu"]["beschreibung"]))
    z += ["", "## " + d["faq_titel"], ""]
    for f, a in d["faq"]:
        z += ["### " + f, "", a, ""]
    for u in d["unterseiten"]:
        for f, a in u["faq"]:
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
    """Strukturierte Daten: die Seite, das Programm, die Fragen mit Antworten.

    **Nicht fuer Google allein.** ChatGPT, Perplexity und die Uebersichten in
    der Suche zitieren, was sich zitieren laesst -- eine Frage mit einer
    vollstaendigen Antwort daneben, ohne Kontext ringsherum. Die Fragen stehen
    ohnehin schon auf der Seite; hier bekommen sie eine Form, die eine
    Maschine ohne Raten liest.

    `applicationCategory` ist absichtlich `UtilityApplication` und nicht
    `FinanceApplication`: das Programm bewegt kein Geld, es sieht zu. Eine
    Kennzeichnung, die mehr verspricht, als das Programm tut, faellt spaeter
    auf einen zurueck. Bewertungen stehen bewusst nicht drin: es gibt keine,
    und erfundene waeren genau das.
    """
    neueste = aenderungen()[0]
    frei = {"@type": "Offer", "price": "0", "priceCurrency": "EUR"}
    netz = {"@context": "https://schema.org", "@type": "WebSite", "name": "OrangeDeck",
            "url": SEITE + "/", "inLanguage": d["code"]}
    anwendung = {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "@id": APP_ID,
        "name": "OrangeDeck",
        "url": "%s/%s/" % (SEITE, d["code"]),
        "inLanguage": d["code"],
        "description": d.get("seo_kurz") or d["beschreibung"],
        "applicationCategory": "UtilityApplication",
        "operatingSystem": "Linux, Windows, Android",
        "softwareVersion": FASSUNG,
        "datePublished": aenderungen()[-1]["datum"],
        "dateModified": neueste["datum"],
        "downloadUrl": [u.replace("{v}", FASSUNG) for _, _, u in d["holen"]
                        if "/releases/latest/download/" in u],
        "releaseNotes": "%s/%s/changelog/" % (SEITE, d["code"]),
        "license": "https://opensource.org/licenses/MIT",
        "isAccessibleForFree": True,
        "offers": frei,
        "image": "%s/bilder/vorschau-%s.png" % (SEITE, d["code"]),
        # Der Feed steht oben als Standbild, die Galerie zeigt die anderen.
        "screenshot": ["%s/bilder/%s.webp" % (SEITE, n)
                       for n in ["feed"] + [n for n, _ in d["bilder"]]],
        "codeRepository": d["repo"],
        "sameAs": ANDERSWO,
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
    return [netz, anwendung, fragen]


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
    // Portugiesisch gibt es zweimal; ohne Land ist es das europaeische.
    if (k === "pt") k = "pt-pt";
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


def fassungen():
    """Haengt an CSS und Skripte eine Kennung aus ihrem Inhalt: stil.css?v=1a2b3c4d.

    **Cloudflare hielt live.js vier Stunden im Cache**, waehrend das HTML schon
    neu war (26.09.2026). Neues HTML mit altem Skript passt nicht zusammen: das
    alte Skript kannte das Datenformat nicht mehr. Mit der Kennung ist jede
    geaenderte Datei eine neue Adresse, und kein Cache liefert die alte.
    """
    import hashlib
    kennung = {}
    for name in ("stil.css", "live.js", "mondrian.js", "colors.js"):
        kennung[name] = hashlib.sha256((ZIEL / name).read_bytes()).hexdigest()[:10]
    for f in ZIEL.rglob("*.html"):
        h = f.read_text(encoding="utf-8")
        for name, k in kennung.items():
            h = re.sub(r'((?:href|src)="[^"]*?%s)"' % re.escape(name), r'\1?v=%s"' % k, h)
        f.write_text(h, encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pruefen", action="store_true")
    args = ap.parse_args()
    tun = not args.pruefen
    global APP_TEXTE
    APP_TEXTE = app_texte()
    alle = sprachen()
    if not alle:
        raise SystemExit("Keine Sprachdateien unter website/texte/")

    if tun and ZIEL.exists():
        shutil.rmtree(ZIEL)
    for d in alle:
        seiten = [("", seite(d, alle))]
        seiten += [(u["slug"] + "/", unterseite(d, alle, u)) for u in d["unterseiten"]]
        seiten.append(("changelog/", neuseite(d, alle)))
        for pfad, inhalt in seiten:
            p = ZIEL / d["code"] / pfad / "index.html"
            if tun:
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(inhalt, encoding="utf-8")
            print("  %s %s" % ("schreibe" if tun else "wuerde", p.relative_to(WURZEL)))
    if tun:
        (ZIEL / "index.html").write_text(weiche(alle), encoding="utf-8")
        shutil.copy2(QUELLE / "stil.css", ZIEL / "stil.css")
        shutil.copy2(QUELLE / "live.js", ZIEL / "live.js")
        (ZIEL / "robots.txt").write_text(robots(), encoding="utf-8")
        (ZIEL / "sitemap.xml").write_text(sitemap(alle), encoding="utf-8")
        (ZIEL / "llms.txt").write_text(llmstxt(alle), encoding="utf-8")
        (ZIEL / "404.html").write_text(seite404(alle), encoding="utf-8")
        (ZIEL / "_headers").write_text(kopfzeilen(), encoding="utf-8")
        (ZIEL / (INDEXNOW + ".txt")).write_text(INDEXNOW, encoding="utf-8")
        shutil.copytree(QUELLE / "bilder", ZIEL / "bilder")
        for name in ("mondrian.js", "colors.js"):
            geteilt(WURZEL / "ui" / "qml" / name, ZIEL / name)
    if tun:
        fassungen()
    print("  %s website/fertig/index.html (Sprachweiche)" % ("schreibe" if tun else "wuerde"))
    print("  %s stil.css, live.js, bilder/ und die zwei geteilten Bausteine"
          % ("kopiere" if tun else "wuerde kopieren"))
    print("  %s robots.txt, sitemap.xml, llms.txt und 404.html"
          % ("schreibe" if tun else "wuerde schreiben"))
    print("\n%d Sprachen: %s" % (len(alle), ", ".join(a["code"] for a in alle)))


if __name__ == "__main__":
    main()
