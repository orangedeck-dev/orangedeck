# orangedeck.dev

Die Seite entsteht aus `tools/website.py`. **Eine weitere Sprache ist eine
Datei** in `website/texte/`, sonst nichts -- die Anwendung spricht dreizehn,
und die Seite soll ihr dorthin folgen koennen, ohne dass jede Aenderung
dreizehnmal gemacht werden muss.

    tools/website.py            bauen nach website/fertig/
    tools/website.py --pruefen  nur zeigen, was entstuende

## Aufbau

Angelehnt an shopatch.com: klebende Kopfleiste mit Navigation und Sprachwahl
rechts, Hero mit zwei Handlungsaufforderungen und Kennzahlen, Bildstreifen,
dann nummerierte Karten (Ansichten), Wirte, Gruende, Bezugswege, Fragen als
aufklappbare Zeilen, Fuss.

## Sprachen

`ORDNUNG` in `tools/website.py` ist die Reihenfolge aus `ui/qml/strings.js`,
damit Seite und Anwendung dieselbe Ordnung zeigen. Seit dem 26.09.2026 sind
alle dreizehn da. `de` und `en` sind die Quelle; die uebrigen elf sind aus
`en.json` uebersetzt, mit den Begriffen aus `ui/qml/strings.js`. Wer `en.json`
aendert, muss die elf nachziehen, sonst gilt: eine halbe Uebersetzung ist
schlimmer als keine.

## Seiten

Je Sprache die Startseite, drei Unterseiten aus `"unterseiten"` (Bitaxe-Monitor,
Anzeige fuer die Wand, DankMaterialShell) und `changelog/`. Die Eintraege dort
stehen in `website/aenderungen.json`, auf Deutsch und Englisch; die anderen
Sprachen zeigen die englischen und sagen das (`"nur_englisch"`). Nach einem
Release dort die neue Fassung oben eintragen.

Vorschaubilder fuer geteilte Links je Sprache: `tools/vorschau.py`, danach
`tools/website.py`. Nach dem Veroeffentlichen `tools/indexnow.py`.

`fertig/index.html` waehlt die Sprache nach dem Browser und faellt auf
Englisch zurueck. Ohne JavaScript steht dort eine Liste zum Anklicken; eine
Seite, die ohne Skript leer bleibt, waere fuer einen Pruefer wertlos.

## Veroeffentlichen

`website/fertig/` ist mitgeliefert, damit Cloudflare Pages **ohne Bauschritt**
darauf zeigen kann:

    Build command:      (leer)
    Build output:       website/fertig

Wer lieber bauen laesst: `python3 tools/website.py` als Bauschritt, gleiches
Ausgabeverzeichnis.

## Spenden

Der Abschnitt `#spenden` erscheint erst, wenn `website/spenden.json` etwas
enthaelt: `name` (BIP353, ergibt `₿name@orangedeck.dev`), `lno` (BOLT12-Angebot
aus Phoenix), `sp` (Silent-Payment-Adresse aus Sparrow) und `onchain` (true,
sobald die Function eingerichtet ist). Leere Felder fallen einzeln weg.

Die wechselnde On-chain-Adresse kommt aus `functions/api/spenden-adresse.js`
(Pages Function, liegt im Repo neben `website/`). Im Pages-Projekt
`orangedeck-site` unter Settings > Variables and Secrets:

    SPENDEN_ZPUB     zpub der Spendenwallet, als Secret
    SPENDEN_BEREICH  optional, Standard 200; Gap-Limit in Sparrow mindestens so gross

Vor dem Einschalten `node tools/spenden/test.mjs <zpub> 20` und die Adressen
mit dem Reiter Addresses in Sparrow vergleichen. Die zwei gebuendelten
Bibliotheken (`functions/_lib/ableitung.js`, `website/qr.js`) baut
`tools/spenden/bau.sh` neu.

BIP353 selbst ist ein DNS-Eintrag (DNSSEC muss an sein):

    <name>.user._bitcoin-payment.orangedeck.dev  TXT  "bitcoin:?lno=<lno>&sp=<sp1>"

## Was noch fehlt

- **Rechtstexte.** Zurueckgestellt: der Betreiber sitzt nicht in der EU,
  eine Impressumspflicht nach deutschem Recht greift also nicht. Wenn spaeter
  doch welche gebraucht werden, gehoeren sie in denselben Erzeuger -- als
  eigene Textdatei je Sprache, nicht als handgeschriebene Extraseite.
- **Die elf uebrigen Sprachen.**

