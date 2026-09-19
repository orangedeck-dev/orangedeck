# Stand und offene Punkte

> Der Abschnitt gleich hier darunter ist der **gueltige Stand** und der
> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei, und erklaert nur noch, wie es dazu kam.

<!-- **Warum die Datei geteilt ist.** Am 06., 07. und 08.09.2026 stand
     dreimal derselbe offene Punkt darin: sie war 117 kB gross, dann 130,
     dann 148 -- "als Einstieg noch brauchbar, als Datei laengst
     unhandlich". Ein Journal, das man nicht mehr oeffnen mag, wird nicht
     mehr gelesen, und dann ist die Sorgfalt beim Schreiben umsonst.

     Geteilt am 09.09.2026, Zeile fuer Zeile unveraendert uebernommen: die
     Zerlegung wurde gegen das Original zurueckgerechnet, bevor sie
     geschrieben wurde. Hier bleibt nur der neueste Tagesabschluss stehen.
     Wandert er morgen ins Journal, kommt der von morgen an seine Stelle;
     die Datei bleibt damit so lang, wie ein Einstieg sein darf. -->
## TAGESABSCHLUSS 19.09.2026 -- wo das Projekt steht

> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei.

### Der Stand in einem Satz

**0.2.12 ist veroeffentlicht** ("Latest", Tag `v0.2.12` auf `fd48092`, Pin
`0878161`, seit 20:43 UTC), gemessen auf Galaxy, Windows 11, Ubuntu 24.04 und
Fedora 44. **Das Projekt hat ein neues Zuhause**: GitHub-Organisation
`orangedeck-dev`, ein **eigenes F-Droid-Repo** unter `fdroid.orangedeck.dev`,
und orangedeck.dev verteilt selbst (Download je System, F-Droid, Obtainium).

Arbeitsbaum sauber, alles gepusht. Keine VM an, kein Emulator, kein Xvfb.
Die Windows-VM steht wieder auf 10 GB. Am Galaxy: Drehung frei, Netz an, Euro,
Systemsprache, und das OrangeDeck-Repo ist in F-Droid eingetragen.

### Was morgen als Erstes drankommt

1. **Das OrangeDeck-Plugin fuer DMS ins Verzeichnis von DMS bringen** (vom
   Anwender am 19.09. fuer morgen gesetzt). Bewertung unten, Punkt 5 der
   offenen Liste. Die Schritte:
   1. Plugin eigenstaendig machen: ein Erzeuger (`tools/`), der alle
      QML-Dateien und `strings.js` in ein Verzeichnis ohne Symlinks legt.
   2. Den Dienst ohne Repo-Auszug erreichbar machen (aus dem Flatpak) und
      `orangedeck-window` ebenso -- oder das Plugin ohne beide lauffaehig.
   3. Eigenes Repo `orangedeck-dev/dms-plugin` (legt der Anwender an), mit
      Tag, englischer Beschreibung in `plugin.json` und README.
   4. Installation so pruefen, wie DMS sie macht: frisches Verzeichnis unter
      `~/.config/DankMaterialShell/plugins/`, ohne `install-links.sh`.
   5. Bild 960x540 im Standard-Thema von DMS, mit echten Daten.
   6. Eintrag `plugins/<name>.json` fuer `AvengeMedia/dms-plugin-registry`
      vorbereiten; den PR samt Offenlegung der KI-Anteile schreibt der
      Anwender.
2. **Handy-Bilder fuer den F-Droid-Eintrag** (`phoneScreenshots` in den
   Metadaten), Oberflaeche dafuer auf Englisch, ohne die Statusleiste des
   Anwenders.
3. Danach die kleinen Befunde von heute (Punkte 6 bis 9).

### Was heute dazugekommen ist

Neunzehn Commits, dazu der Umzug auf GitHub und Cloudflare.

| Was | Commit | Anstoss |
|---|---|---|
| Widget ohne Netz zeigt den letzten Stand mit Uhrzeit | `e5d4ca2` | offene Liste, Punkt 9 |
| APK 24 statt 57 MB: Bibliotheken gepackt | `4d6992f` | F-Droid-Weg |
| Eigenes F-Droid-Repo (`tools/fdroid-repo.sh`, `packaging/fdroid/`) | `df4976f` | Anwender |
| Umzug nach `orangedeck-dev`, Urheber Satoshoe | `856ed66` | Anwender |
| Fassung 0.2.12 | `2f85a90` | Ablauf |
| Tipp am Telefon, erster Versuch (wirkte nicht) | `e9e752f` | **Anwender am Galaxy** |
| Tipp am Telefon, im Emulator gemessen und behoben | `36d5f2e` | Geraetelauf |
| `fdroid-repo.sh` mit der Git-Identitaet des Hauptrepos | `3f9177e` | eigener Fund |
| Klick mit der Maus oeffnet den Explorer | `fd48092` | zweiter Linux-Lauf |
| Bauplan auf `2f85a90`, `e9e752f`, `36d5f2e`, `fd48092` | `5eafe24` `bdce03d` `57009ab` `0878161` | Ablauf |
| Freigabetext, dann gegen Code und Messung gehalten | `1f557b7` `d7489a0` | Anwender |
| `fdroid-repo.sh` prueft das APK gegen PRUEFSUMMEN.txt | `266259b` | eigener Fehler |
| Seite: Download, F-Droid, Obtainium; macOS und Flathub richtiggestellt | `ffa82eb` | Anwender |
| "Download" statt "Beziehen" | `e35d6f4` | Anwender |

**Die Dateien von 0.2.12** (veroeffentlicht):

    640d5ac554ed9b6881f15a6a1ecd83f44e573b3be6f2d085ca9ccefd92932372  orangedeck-0.2.12-arm64-v8a.apk (signiert)
    85c0b8a2e8a8979b9a68a9e06a6f3813f46ac54cd001a4adca41d7f3bc35598a  orangedeck-0.2.12-arm64-v8a-unsigniert.apk
    4177c15e5f27340f0295c984aa57fac0cd3ccbfe97fc3b250a8d004b9d454d12  orangedeck-0.2.12-windows-x86_64.zip
    527d11e4f17a8430845850f76ecfbbd4da12e4cc4c29f9a86f662b296bb9635b  orangedeck-0.2.12.flatpak

Drei Runden sind verworfen; ihre Dateien liegen als `...-verworfen-<commit>`
im Auslieferungsordner, ihre Zeilen auskommentiert in `PRUEFSUMMEN.txt`.

**Was ausserhalb des Repos neu ist** (Einzelheiten in der Erinnerung
`github-cloudflare-einrichtung`):

- GitHub: persoenliches Konto **`satoshoe-dev`** (vorher 21Rebel),
  Organisationen **`orangedeck-dev`** (Repos `orangedeck` und `fdroid`) und
  **`21Rebel`** (leer, haelt den Shop-Namen). Git im Repo lokal:
  `Satoshoe <info@orangedeck.dev>`, die Adresse ist im Konto bestaetigt.
- Cloudflare Pages: neues Projekt **`orangedeck-site`** traegt orangedeck.dev.
  Das alte Projekt `orangedeck` haengt an der Installation von 21Rebel, baut
  nicht mehr und laesst sich im Dashboard nicht loeschen (zu viele Deployments).
- DNS: `fdroid` als CNAME auf `orangedeck-dev.github.io` (graue Wolke), dazu
  die Mail-Eintraege fuer Proton: **`info@orangedeck.dev`** empfaengt.
- F-Droid: Arbeitsverzeichnis `~/.local/share/orangedeck/fdroid/` mit eigenem
  Schluessel (Fingerabdruck `06E62F14...91DC4C59`); der Anwender hat ihn im
  Passwortmanager. `fdroidserver` 2.4.5 ueber pipx, mit `setuptools<81`.
- Das Signierpasswort ist getauscht (neuer Behaelter, derselbe Schluessel,
  Zertifikat weiter `b3cc8379...`).

**Gemessen heute:**

- **Galaxy**: Widgets ohne Netz mit "Stand 08:16", nach dem Nachholen wieder
  grau und mit Namen; zwei Runden, weil die Farbe erst beim zweiten Mal jedes
  Mal gesetzt wurde. Tipp, zweiter Tipp, Tipp daneben und Doppeltipp im Feed
  vom Anwender bestaetigt, mit dem ausgelieferten APK.
- **Windows 11, VM, das ausgelieferte ZIP**: alle Reiter mit Daten, Klick auf
  eine Kachel oeffnet sie im Explorer, Ziffern, Komma, Widget mit Win+D, Q.
  Kein neuer Defender-Fund (juengster weiter vom 13.09.).
- **Ubuntu und Fedora, das ausgelieferte Buendel**: Pruefsummen, Fassung,
  Quelle `0878161`; Tooltip, Klick in den Explorer, Doppelklick nach dem
  Vergroessern setzt zurueck; Uhr, Markt, Komma. Mining, Liquidationen und
  Heatmap am selben Tag an `2f85a90`.
- **Das F-Droid-Repo** mit dem F-Droid-Client am Galaxy: erkennt Name,
  Fingerabdruck, "von Satoshoe", den Hinweis auf NonFreeNet, und die
  installierte 0.2.12 als dieselbe Fassung.
- **Downloads**: `releases/latest/download/...` liefert alle drei Dateien mit
  den Pruefsummen oben; alte Links auf `21Rebel/orangedeck` leiten weiter.

### Die Erkenntnisse des Tages

**Ein Handler, der im Code steht, ist kein Handler, der feuert.** Der
TapHandler im Kachelfeld bekam weder Finger noch Maus ab -- seit dem 08.09.,
durch drei Releases, ohne dass es jemand merkte. Der Tooltip beim Ueberfahren
ging ja, und der Klick sah so selbstverstaendlich aus, dass keine Pruefliste
nach ihm fragte. Gefunden hat es der Anwender am Telefon ("bleibt nicht
stehen") und dann der zweite Linux-Lauf fuer die Maus.

**Zwanzig Minuten messen statt zwei Runden raten.** Die erste Korrektur fuer
den Tipp habe ich aus dem Lesen des Codes gebaut, der Anwender hat signiert,
es wirkte nicht. Danach im Emulator mit vier Protokollzeilen: in einer
Viertelstunde lagen beide Ursachen offen (der TapHandler bekommt nichts,
`onExited` raeumt hinterher weg). Der Emulator kostet den Anwender keine
Signatur -- **fuer alles, was sich im Emulator zeigen laesst, zuerst dort.**

**Eine Notiz ist die Messung eines Tages, kein Gesetz.** Am 08.09. stand im
Code: `onExited` kommt am Finger nicht. Heute kam es, nur spaeter als alles
andere. Der Code verlaesst sich jetzt in keiner Richtung darauf.

**Ein Test, der den Weg nicht geht, beweist ihn nicht.** Der Lauf vom Mittag
hat den Explorer ueber den Reiter geoeffnet, nicht ueber eine Kachel -- und
galt als "Explorer mit Daten". Seitdem nennt der Pruefauftrag die Handlung,
nicht die Ansicht: Maus auf die Kachel, klicken, TxID vergleichen.

**Gleicher Name, gleiche Fassung, gleicher Schluessel -- andere Datei.** Das
F-Droid-Repo trug zwanzig Minuten lang einen verworfenen Bau. Die Pruefung des
Zertifikats konnte das nicht sehen; die der Pruefsumme kann es. Massstab ist
jetzt die gueltige Zeile in `PRUEFSUMMEN.txt`.

**Vor dem Antrag die Regeln des Gegenuebers.** Flathub verbietet, dass ein
Agent den Antrag stellt oder seinen Text schreibt, verlangt die Offenlegung
der KI-Anteile und Belege fuer echten Gebrauch; #10105 traegt "AI Slop".
IzzyOnDroid lehnt KI-geschriebene Apps ab. Das DMS-Verzeichnis erlaubt sie
mit Offenlegung. Der Weg, der ohne fremde Zustimmung geht -- eigenes
F-Droid-Repo, eigene Seite, Obtainium -- war an einem Nachmittag gebaut.

**Was Nutzer eintragen, gehoert auf die eigene Domain.** GitHub leitet Repos
nach einer Umbenennung weiter, GitHub Pages nicht. Deshalb `fdroid.orangedeck.dev`
statt einer github.io-Adresse, und deshalb eine Organisation statt des
persoenlichen Kontos. Und: Cloudflare Pages haengt an der Installation der
GitHub-App; nach dem Umzug des Repos half nur ein neues Projekt, "Disconnect"
waere eine Einbahnstrasse gewesen.

**Ein frischer Klon nimmt die globale Git-Identitaet.** Darin stand ein
Klarname. Bemerkt vor dem ersten Push, weil ich den Autor im Index gelesen
habe; das Skript setzt die Identitaet jetzt ausdruecklich.

**Ein Freigabetext wird gegen Code und Messung gelesen, nicht nur gegen den
Stil.** Die maschinelle Pruefung fand keine Gedankenstriche -- und liess "for
hours" (nicht belegt), "23 MB" (MiB neben dezimalen 57 MB) und zwei gleich
gebaute Absaetze durch. Auf der Seite stand seit Wochen "Windows und macOS,
derselbe Bau", fuer macOS gibt es kein Paket.

**Vergroessert ist fast alles Kachel.** Der erste Mausklick oeffnete sofort
den Explorer, und damit kam man aus einer Vergroesserung per Doppelklick nicht
mehr heraus. Der einfache Klick wartet jetzt die Doppelklick-Zeit ab.

### Und was ich selbst falsch gemacht habe

- **`rm *.flatpak` im Datenordner der Pruef-VM** loeschte auch die beiden
  Laufzeiten, nicht nur das alte Buendel. Kopien lagen eine Ebene hoeher.
- **Das F-Droid-Repo vor der letzten Runde gebaut und danach nicht neu** --
  zwanzig Minuten lag der verworfene Bau aus `36d5f2e` oeffentlich.
- **Die erste Tipp-Korrektur ohne Messung gebaut**; der Anwender hat dafuer
  einmal umsonst signiert.
- **`pgrep -f`/`pkill -f` mit einem Muster aus der eigenen Befehlszeile** --
  zweimal die eigene Shell beendet. Der Hinweis `ps -C <name> (nicht pgrep
  -f)` stand im Abschluss vom 18.09.; ich habe ihn nicht gelesen.
- **Der Signierbefehl mit relativem Pfad und `VAR=~/...` unter fish**: beides
  scheitert im Home-Verzeichnis des Anwenders; er musste zweimal ansetzen.
- **`du -sh "$D"` mit leerem `$D` auf dem Telefon** -- lief ueber das ganze
  Geraet; dabei landete die Paketliste des Telefons in dieser Sitzung.
- **In `PRUEFSUMMEN.txt` eine gueltige Zeile mit auskommentiert**, sofort
  bemerkt und zurueckgenommen.
- **Zu frueh fotografiert**: ohne Netz, aber mit VPN, scheitert jedes Widget
  erst nach rund 6 s, und Android arbeitet die zehn nacheinander ab.
- **In dieser Werkzeug-Shell Befehle in Variablen gelegt** (`$E`, `set -- $t`):
  sie trennt nicht an Leerzeichen. Zweimal leere Ergebnisse, bevor ich es sah.

### Was sonst noch offen ist

1. **Der Tooltip-Untergrund** kostet Rechenzeit in der Weichzeichnung selbst,
   nicht im Nachziehen (18.09. gemessen, Riegel verworfen). Wer sparen will,
   muss an das abgenommene Aussehen.
2. **Laeden.** Flathub vorerst nicht (siehe Erkenntnisse), IzzyOnDroid gar
   nicht. **Das eigene F-Droid-Repo laeuft**; jedes Release geht mit
   `tools/fdroid-repo.sh <v>` und einem Push hinein (Ablauf unten). Offen:
   **Google Play** entscheidet der Anwender (25 $, Ausweis, 12 Tester ueber 14
   Tage; Aurora Store kommt dann von selbst). **Google verlangt ab 30.09.2026**
   in Brasilien, Indonesien, Singapur und Thailand, ab 2027 weltweit, einen
   registrierten Entwickler fuer jede App auf zertifizierten Telefonen, auch
   ausserhalb von Play. F-Droids Hauptrepo nur, wenn Qt dort aus dem Quelltext
   gebaut werden soll.
3. **Windows**: ungeprueft sind 600 MB im Markt, die README-Startzeile in
   Win+R, Skalierung ueber 100 %, SmartScreen. **macOS**: baut in der CI,
   nie geprueft, kein Paket; die Seite sagt es jetzt so.
4. **`bitfeed`**: eine Messung in der Sitzung des Anwenders, `kitten panel
   --edge=background` unter niri (braucht sein OK), dann Stufe 3 und 4.
5. **Das DMS-Plugin ins Verzeichnis von DMS** (`AvengeMedia/dms-plugin-registry`).
   Bewertung vom 19.09.2026: **lohnt sich** -- die Zielgruppe (niri, DMS,
   Wayland) ist genau die, fuer die OrangeDeck als Widget gedacht ist, und das
   Verzeichnis erlaubt KI-Anteile, wenn sie offengelegt sind und der
   Einreicher jede Zeile vertreten kann. **Aber so, wie es liegt, liefe es
   nicht**: DMS installiert ein Plugin, indem es sein Verzeichnis kopiert.
   `shell/dms/` bezieht `strings.js` und die geteilten QML-Dateien heute ueber
   Symlinks aus `tools/install-links.sh`, und `OrangeDeckWidget.qml` ruft
   `~/.local/bin/orangedeck-window` auf, der Dienst kommt aus einem
   Repo-Auszug. Noetig vorher:
   - ein eigenstaendiges Plugin-Verzeichnis mit allen QML-Dateien und
     `strings.js` (aus dem Repo erzeugt, nicht von Hand kopiert), am besten
     als eigenes Repo `orangedeck-dev/dms-plugin` mit Tags;
   - der Dienst als erklaerte Abhaengigkeit (`dependencies`) und ein Weg, ihn
     ohne Repo-Auszug zu bekommen -- naheliegend aus dem Flatpak;
   - `id` in camelCase passt (`orangedeck`), aber die Beschreibung in
     `plugin.json` ist deutsch -- englisch fuer das Verzeichnis;
   - ein Bild 960x540 im Standard-Thema von DMS, mit echten Daten;
   - der Eintrag `plugins/<name>.json` mit `category`, `compositors`,
     `distro`, `repo`, `path`, `screenshot`. Den PR und seine Offenlegung
     schreibt der Anwender.
6. **Tooltip und Explorer rechnen die Gebuehrenrate verschieden**: 4,54 gegen
   4,56 sat/vB fuer dieselbe Transaktion (1000 sat / 219,25 vB = 4,56). Der
   Tooltip weicht von seinen eigenen Zahlen ab.
7. **Die Preisachse im Markt** ist am rechten Rand abgeschnitten ("81,95"
   statt "81,951"), unter Ubuntu und Fedora, schon am 18.09.
8. **Zahlenformate in der englischen Oberflaeche**: Legende "0,01", Datum
   "19.09.2026", daneben englische Formate.
9. **Fedora-Fensterleiste**: das Fenster traegt dort weder Symbol noch Titel.
10. **F-Droid-Eintrag**: Handy-Bilder fehlen (siehe oben).
11. **Am Telefon ein zweiter Tipp innerhalb der Doppeltipp-Zeit** auf dieselbe
    Kachel setzt die Sicht zurueck, statt den Explorer zu oeffnen. So gewollt,
    aber wer schnell tippt, merkt es. Beobachten.
12. **Das alte Cloudflare-Projekt `orangedeck`** loescht sich nur ueber die API
    (alle Deployments zuerst). Schadet nicht, kostet nichts.
13. **Shopatch** hat ein eigenes GitHub-Konto (Einzelunternehmen, also
    streng genommen ein zweites). Umwandeln in eine Organisation in Ruhe
    pruefen, wegen der Shopify-Anbindungen am Login -- Sache des Anwenders.
14. **Idee fuer spaeter**: Wallet direkt auf dem Telefon.

### Fuer den naechsten Lauf

    Repo: github.com/orangedeck-dev/orangedeck -- gh immer mit -R orangedeck-dev/orangedeck
      (zwei Remotes im Ordner; der alte Name 21Rebel leitet nur weiter)
    Git im Repo: Satoshoe <info@orangedeck.dev> (lokal gesetzt, NICHT global)
    curl -4 / -6 -m 10 https://mempool.space/api/blocks/tip/height
    Dienst nachsehen (Port 21021, nicht 8787):
      curl -s http://127.0.0.1:21021/state | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['seq'], d['source'], d['mempool']['count'])"
      zweimal im Abstand messen -- steht `seq`, traegt der Draht nichts
      die Wache meldet sich:  journalctl --user -u orangedeck | grep schweigt
    laeuft ein Prozess:  ps -C <name>  -- NIE pgrep -f / pkill -f mit einem Muster,
      das in der eigenen Befehlszeile steht: das beendet die eigene Shell
    Diese Werkzeug-Shell trennt Variablen nicht: keine Befehle in $VAR legen,
      ANDROID_SERIAL=... exportieren statt "adb -s ..." in einer Variable
    Release, in dieser Reihenfolge:
      Fassung an drei Stellen (project(), Manifest samt versionCode, Metainfo)
      tools/apk.sh  ->  ~/Schreibtisch/orangedeck/tools/apk-signieren.sh <v>   (Anwender, absoluter Pfad)
      Geraetelauf durch den Anwender; Pin setzen: tools/bauplan-pruefen.py
      gh run download <lauf> -R orangedeck-dev/orangedeck -n orangedeck-windows-x86_64-UNSIGNIERT -D build/win-<v>
      gh run download <lauf> -R orangedeck-dev/orangedeck -n orangedeck-flatpak -D build/flatpak-<v>
      ZIP ohne zip:  (cd build/win-<v> && python3 -m zipfile -c <ziel>.zip .)   (88 Eintraege, 72 Dateien)
      Windows-VM, beide Linux-VMs -- im Pruefauftrag die HANDLUNG nennen (Kachel anklicken, TxID vergleichen)
      Tag auf den Inhalts-Commit (nicht den Pin), Entwurf mit gh release create --draft
      Text gegen Code und Messung lesen, nicht nur gegen den Stil
      tools/fdroid-repo.sh <v>  (NACH der letzten Runde; prueft Zertifikat und PRUEFSUMMEN.txt)
      git -C ~/.local/share/orangedeck/fdroid-pages push --force origin main
      dann veroeffentlicht der Anwender:  gh release edit v<v> -R orangedeck-dev/orangedeck --draft=false --latest
      Seite neu bauen (python3 tools/website.py): die Download-Links nehmen die Fassung aus project()
    Verworfene Runde: Dateien in ...-verworfen-<commit> umbenennen, Zeilen in PRUEFSUMMEN.txt auskommentieren
    F-Droid-Repo am Telefon pruefen:
      adb shell am start -a android.intent.action.VIEW -d "fdroidrepos://fdroid.orangedeck.dev/repo?fingerprint=06E62F14...4C59" org.fdroid.fdroid
      (fdroidrepo:// fuer http, z. B. ueber adb reverse tcp:8888 tcp:8888)
    Test-APKs neben dem Release:
      env ORANGEDECK_APK_DIR=$HOME/.local/share/orangedeck/auslieferung/geraetetest-<v> tools/apk.sh
    Emulator statt Signierrunde (Android 11, eigener Debug-Schluessel):
      export ANDROID_NDK_ROOT=$(command ls -d $HOME/Android/sdk/ndk/* | sort -V | tail -1) ANDROID_SDK_ROOT=$HOME/Android/sdk
      cmake --build build-android-x86_64 --target apk -j8
      apksigner sign --ks ~/.android/debug.keystore --ks-pass pass:android --key-pass pass:android --out <apk> <unsigniert>
      emulator -avd orangedeck-api30 -no-window -no-audio -no-snapshot -gpu swangle_indirect
      warten: until [ "$(adb -s emulator-5554 shell getprop sys.boot_completed)" = 1 ]
      console.warn("ODBG ...") in QML landet im logcat unter "W qml"; vor dem Commit wieder raus
      beenden: adb -s emulator-5554 emu kill
    Maus im Xvfb (Klick, Rad, Doppelklick):
      Xvfb :97 -screen 0 1400x900x24 & ; DISPLAY=:97 HOME=<eigenes> ./build/orangedeck-app --source direct --id probe
      DISPLAY=:97 python3 -c 'import sys;sys.path.insert(0,"tools");import xtest; xtest.klick(x,y); xtest.rad(True,6)'
    Galaxy: tabRotate ist an, die Ansicht wandert alle 30 s; KEYCODE_COMMA (55) oeffnet das Zahnrad
    Netz am Telefon aus/an: adb shell svc wifi disable ; adb shell svc data disable (hinterher enable)
    Widget-Protokoll: adb logcat -d -v time | grep -E ' (I|W)/OrangeDeck'
    Windows-VM:
      virsh -c qemu:///system setmaxmem win11 4G --config (und setmem; danach 10240000)
      Anmeldung: KEY_SPACE, BACKSPACE x6, PIN Ziffer fuer Ziffer mit --holdtime 100 und 0,45 s Abstand
      python3 tools/win-tippen.py 'Z:\orangedeck\build\od-start.cmd' ; KEY_ENTER   (in Win+R nur Pfade)
      Paket nach build/win-test, dann od-vorbereiten.cmd; Ausgaben liegen erst verzoegert auf Z:
      Klick per QMP: input-send-event, abs-Achsen 0..32767 ueber 2560x1440
    tools/pruefvm.sh starten | anhalten | gast   (nicht `bauen`, wenn das CI-Buendel geprueft wird)
      Daten-ISO: Laufzeiten aus ~/.cache/orangedeck-vm/ mit hinein, dann
        (cd daten && sha256sum ./*.flatpak > PRUEFSUMMEN.txt && xorriso -as mkisofs -V ORANGEDECK -J -r -o ../daten.iso .)
      Fedora: Startmenue (35, 768), Kachel "Konsole" (401, 410), warten
    Seite ansehen ohne Browserfenster:
      google-chrome-stable --headless=new --user-data-dir=<tmp> --window-size=1300,4400 --screenshot=<png> file://.../website/fertig/de/index.html
      (Chrome hat eine Mindestbreite um 500 px; darunter wirkt die Seite abgeschnitten)
    qmllint: /usr/lib/qt6/bin/qmllint -I ui/qml [-I app/qml] <datei>
    tools/install-links.sh --check        (neue Datei unter ui/qml: ZUERST verlinken)
    tools/install-links.sh && python3 -B daemon/orangedeck-dashtab && systemctl --user restart dms

---

## Das Journal

Ein Tag je Datei, das Neueste oben. Herausgeloest aus dieser Datei, unveraendert.

| Tag | Worum es ging |
|---|---|
| [18.09.2026](journal/2026-09-18.md) | 0.2.11 veroeffentlicht, fuenf Punkte der offenen Liste erledigt, die Wache gegen den stummen WebSocket, Android 11 im Emulator. |
| [17.09.2026](journal/2026-09-17.md) | 0.2.11 gebaut und signiert, die Widgets haben die Nacht bestanden, dieselbe Transaktion stand doppelt im Mempool-Protokoll, Windows lief mit Daten. |
| [16.09.2026](journal/2026-09-16.md) | 0.2.10 veroeffentlicht, acht Aenderungen fuer 0.2.11 auf main, Widgets im Doze nachgestellt, OKX reicht nur 24 Stunden zurueck. |
| [15.09.2026](journal/2026-09-15.md) | Alles fuer 0.2.10 auf main: Widgets ohne leere Kacheln, der Dienst-Weg repariert und unter Android und Windows entfernt, Zahnrad per Taste. |
| [14.09.2026](journal/2026-09-14.md) | 0.2.9 veroeffentlicht, Linux in zwei VMs nachgeholt, Freigabetext ohne KI-typische Muster, Dashtab-Nachbearbeitungen uebernommen. |
| [13.09.2026](journal/2026-09-13.md) | 0.2.9 fertig getestet, der Markt ohne Dienst in der App, am Telefon bedienbar; Defender hielt die Testfernbedienung fuer ClickFix. |
| [12.09.2026](journal/2026-09-12.md) | Das erste Release 0.2.8, Windows startet zum ersten Mal, Markt und Wallet ueber einen Dienst im Netz, `bitfeed` als Entwurf. |
| [11.09.2026](journal/2026-09-11.md) | Derselbe Satz Ansichten auf jedem System: vier Befunde, die Nummer wanderte auf 0.2.8, und mempool.space drosselte diese Maschine. |
| [10.09.2026](journal/2026-09-10.md) | Dreimal getaggt, und jedes Mal kam am Telefon noch etwas. Widgets, Vollbild, Sprache des Systems. |
| [09.09.2026](journal/2026-09-09.md) | Acht Widgets, und eine Verwechslung, die Stunden gekostet hat: gezaehlt am Block statt an der Halde. |
| [08.09.2026](journal/2026-09-08.md) | Das Geraet fand dreizehn Befunde. Der Miner laeuft ohne Daemon, und `v0.2.2` zeigt auf einen Stand ohne jede Korrektur. |
| [07.09.2026](journal/2026-09-07.md) | Die Sicherung traegt, der Signaturschluessel existiert. Offen blieb nur der Push. |
| [06.09.2026](journal/2026-09-06.md) | orangedeck.dev ist live und zeigt den Mempool wirklich live; der Flathub-Antrag ging raus und war in einer Minute zu. |
| [05.09.2026](journal/2026-09-05.md) | Eigene Identitaet: eigene Domain, eigenes Zeichen, eine Kennung fuer alle Systeme. Die Auslieferung geradegezogen. |
| [04.09.2026](journal/2026-09-04.md) | Zum ersten Mal auf einem Rechner gelaufen, der nichts von diesem Projekt weiss. Die Pruef-VM entsteht. |
| [03.09.2026](journal/2026-09-03.md) | Das Projekt heisst OrangeDeck und ist oeffentlich. 394 Vorkommen umbenannt, zwei neue Ansichten. |
| [02.09.2026](journal/2026-09-02.md) | Blockuhr, Widgets, Flatpak, Layer-Shell, Android-APK, dreizehn Sprachen, Goggles, watch-only. |
| [01.09.2026](journal/2026-09-01.md) | Die erste Uebergabe: was steht, was offen ist, wie man morgen anfaengt. |
| [31.08.2026](journal/2026-08-31.md) | Die aeltesten Notizen. Woher `mondrian.js` und `colors.js` kommen, und ob Bitfeed sich selbst betreiben laesst. |
