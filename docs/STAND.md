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
## NACHTRAG 25.09.2026 -- 0.2.13 als Entwurf

- Fassung 0.2.13 (`a762ace`, Tag `v0.2.13`), Pin `1773ee1`, Freigabetext in
  `packaging/github/RELEASE-TEXT.md`, Release als **Entwurf** mit ZIP, APK und
  Flatpak. Pruefsummen in `PRUEFSUMMEN.txt` der Auslieferung.
- Gemessen: Galaxy A55 (Anwender, signiertes APK ueber 0.2.12), Windows 11
  VM (ZIP aus dem Pin-Lauf: Feed, Tooltip-Rechnung, Preisachse), Ubuntu 24.04
  und Fedora 44 KDE (CI-Buendel: Feed, Tooltip, Markt, Symbol). **Nicht**
  wiederholt: Mining, Explorer-Klick, Widgets mit Win+D, Defender, das
  Zahnrad ueber `,`. Der Text nennt nur, was gesehen wurde.
- Ubuntu-Dock zeigte ein Zahnrad statt des Symbols: flatpak wurde in die
  laufende Live-Sitzung nachinstalliert, `XDG_DATA_DIRS` kennt den
  Exportpfad erst nach einer Anmeldung. Kein Fehler der App.
- Im Emulator `orangedeck` liegt jetzt eine Debug-signierte 0.2.13; das
  release-signierte 0.2.12 der F-Droid-Bilder ist deinstalliert.
- **Veroeffentlicht 25.09.2026, 18:15 UTC** (vom Anwender freigegeben, "Latest").
  Seite neu gebaut und gepusht (`7e1aef3`), alle drei Download-Links 200.
  **Offen:** F-Droid-Repo pushen, lokal fertig (`2b01c30`); den Force-Push
  laesst die Rechtepruefung nur den Anwender selbst ausfuehren:
  `git -C ~/.local/share/orangedeck/fdroid-pages push --force origin main`

## NACHTRAG 24.09.2026 -- Bilder und Veroeffentlichung erledigt

Die Punkte 1 bis 3 unten und die F-Droid-Bilder aus Punkt 4 sind erledigt:

- **DMS-Plugin veroeffentlicht.** Repo `orangedeck-dev/dms-plugin`, ein
  Commit, Tag `v1.0.0`. Eintrag im DMS-Verzeichnis als PR #937 in
  AvengeMedia/dms-plugin-registry, `validate` und `preview` gruen, Merge offen.
- **Bilder.** Titelbild auf das Popout zugeschnitten, im README eine Galerie
  aus sechs Bildern (Clock, Mining, Explorer, Market, Kachel, Desktop-Widget),
  alle aus dem Probestand. Rohbilder unter
  `~/.local/share/orangedeck/pruefbilder/dms-2026-09-24/`.
- **F-Droid.** Fuenf Handybilder in
  `packaging/fdroid/metadata/dev.orangedeck.OrangeDeck/en-US/phoneScreenshots/`,
  aufgenommen im Emulator `orangedeck` mit dem Release-APK 0.2.12,
  Statusleiste im Vorfuehrmodus. Das Repo auf fdroid.orangedeck.dev ist damit
  neu gebaut und online.
- Haupt-Repo gepusht.

Zwei Kniffe fuer die Aufnahmen, beide ohne den Bildschirm des Anwenders:

- Das Fenster des Probestands darf auf einem leeren Workspace liegen, es
  zeichnet dort weiter, nur mit etwa einem Bild je Sekunde. Nach jedem
  Schritt also 15 bis 20 s warten. `zeiger` rechnet in der Probe mit den
  Massen des Wirtsbildschirms: Koordinaten verdoppeln.
- Vor `tools/dms-plugin.sh --repo` darf in `shell/dms/assets/` nichts
  anderes liegen, der Ordner wird ganz kopiert.

Weiter offen bleibt Punkt 4 (Fedora-Lauf) und alles unter "Was sonst noch
offen ist" ab Punkt 3.

## TAGESABSCHLUSS 20.09.2026 -- wo das Projekt steht

> Einstieg fuer den naechsten Tag. Alles Aeltere liegt im Journal unter
> `docs/journal/`, ein Tag je Datei.

### Der Stand in einem Satz

**0.2.12 steht unveraendert draussen** -- heute wurde nichts veroeffentlicht.
Der Tag ging an zwei Dinge: **das DMS-Plugin laeuft jetzt allein** (kopiertes
Verzeichnis, kein Repo, kein Dienst noetig, Erzeuger samt Pruefungen, Eintrag
fuer das Verzeichnis vorbereitet), und **die vier Kleinbefunde der offenen
Liste sind erledigt** -- Gebuehrenrate, Preisachse, Zahlenformate,
Fenstersymbol. Sechs Commits, Arbeitsbaum sauber.

Nicht gepusht, nicht getaggt, keine neue Fassung. Der Probestand
(`tools/dms-probe.sh`) ist aus, die Pruef-VMs waren nicht an.

### Was morgen als Erstes drankommt

1. **Die Bilder aufnehmen** -- der Anwender, morgen oder uebermorgen. Was
   wohin gehoert, steht in `docs/BILDER.md`; die drei Befehle fuer den
   Probestand stehen dort ebenfalls. **Ohne das Bild geht der Eintrag ins
   DMS-Verzeichnis nicht**: `validate_links.py` prueft die Bild-URL.
2. **Repo `orangedeck-dev/dms-plugin` anlegen** (Anwender) und den fertigen
   Arbeitsbaum pushen: `tools/dms-plugin.sh --repo` hat ihn in
   `build/dms-plugin-repo` gelegt, mitsamt Commit und den Befehlen zum Push.
3. **Den PR ins Verzeichnis** schreibt der Anwender, mit der Offenlegung der
   KI-Anteile. Die Regel dort: *"Say in the PR when a meaningful part of it
   was AI generated."* Der Eintrag liegt fertig in
   `packaging/dms-registry/orangedeck-dev-orangedeck.json`.
4. Danach: **Fedora-Lauf fuer Punkt 9** (das Fenstersymbol, unten Punkt 4)
   und die Bilder fuer F-Droid.

### Was heute dazugekommen ist

| Was | Commit | Anstoss |
|---|---|---|
| Das DMS-Plugin laeuft allein (Erzeuger, `mode: "auto"`, Aufgeben der Daemon-Komponente) | `90ab44a` | Anwender (Plan vom 19.09.) |
| Eintrag fuer das Verzeichnis, `assets/` im Erzeuger, `set -e`-Falle darin | `97549a3` | Ablauf |
| Zahlen und Datum in der Sprache der Oberflaeche, Preisachse misst sich richtig | `333202d` | offene Liste, Punkte 7 und 8 |
| Der Tooltip rechnet die Gebuehrenrate aus seinen eigenen Zahlen | `3533731` | offene Liste, Punkt 6 |
| Das Fenster traegt sein Symbol selbst, `StartupWMClass` | `3a5c10b` | offene Liste, Punkt 9 |
| `--repo` fuer den Erzeuger, `docs/BILDER.md` | `354f38b` | Ablauf |
| `tools/dms-probe.sh`: der Probestand als Werkzeug | (dieser) | Ablauf |

**Was das Plugin jetzt kann.** `tools/dms-plugin.sh` erzeugt ein Verzeichnis
mit 51 Dateien und 1,2 MB, ohne einen Symlink, und prueft das Ergebnis selbst:
kein Symlink, jedes `import "...js"` vorhanden, jeder in `plugin.json`
genannte Bestandteil vorhanden. `FeedState` kennt `mode: "auto"` -- erst den
Dienst, nach vier Sekunden ohne Antwort den Direktbezug, einmal je Sitzung
entschieden. Die Daemon-Komponente gibt auf, wenn Unit **und** Programm
fehlen; der Knopf "eigenes Fenster" verschwindet ohne `orangedeck-window`.

**Gemessen** (im Probestand, geschachtelte Sitzung mit frischem HOME):

- **Mit Dienst**: Plugin laedt aus der Kopie, Pille mit 78k, Popout mit Block
  und Halde; `ss` zeigt die Verbindung nach 21021 -- "auto" hat den Dienst
  gefunden.
- **Ohne Dienst** (`health=000` waehrend der ganzen Messung): dieselben
  Ansichten direkt von mempool.space, kein Wallet-Reiter, kein Knopf fuer das
  eigene Fenster.
- **Das Aufgeben gezaehlt**: ein Zaehlstueck anstelle von `orangedeck` schrieb
  in 50 Sekunden **einen** Startversuch mit. Ohne die Aenderung waeren es
  fuenf gewesen.
- **Die Preisachse**: gezeichnet 34,0 px, gemessen mit "sans-serif" 35,3 px,
  gemessen ohne Familie 38,4 px ("DejaVu LGC Sans").
- **Das Fenstersymbol**: vorher `_NET_WM_ICON: fehlt`, nachher `da, 256 x 256`.
- **Die Gebuehrenrate**: 222 sats / 111,00 vB = 2,00 und 359 sats / 298,25 vB
  = 1,20, beide Male die angezeigte Zahl.

### Die Erkenntnisse des Tages

**Zwei Schriften, ein Text -- und eine Messung, die nichts misst.** Die
Preisachse wird auf der Leinwand mit `Fonts.sansCss()` geschrieben, ihre
Breite wurde mit einem `Text` **ohne Familie** gemessen, also mit der
Standardschrift von Qt. Auf diesem Rechner war die Messung breiter als der
Text und es passte; unter Ubuntu und Fedora fehlte die letzte Ziffer. Wer
Platz fuer etwas reserviert, muss **dasselbe** messen, das dort stehen wird.

**Eine Zahl, die man nicht nachrechnen kann, ist eine Behauptung.** Im
Tooltip standen Groesse, Rate und Gebuehr untereinander, und die Rate passte
zu den anderen beiden nicht: sie kam von mempool.space und rechnet Vorgaenger
und Sigops mit. Beides ist richtig, nebeneinander ist es falsch. Jetzt steht
die eigene Rechnung da, und die wirksame Rate kommt als eigene Zeile dazu,
wenn sie abweicht.

**Unter Wayland reicht die app_id, unter X11 nicht.** Das Fenster trug seinen
Titel, aber kein `_NET_WM_ICON` -- unter Wayland schlaegt der Verwalter die
app_id in der .desktop-Datei nach, unter X11 und XWayland liest er die
Eigenschaft am Fenster. Eine VM laeuft leicht in einer X11-Sitzung, und dann
faellt genau das auf, was hier nie auffallen konnte.

**Den fremden Fall kann man nicht im eigenen Haus pruefen.** Ein Plugin, das
"auch ohne alles laeuft", beweist sich nur dort, wo nichts ist: frisches HOME,
eigenes Laufzeitverzeichnis, eigener Sitzungsbus. Drei Kleinigkeiten
entscheiden darueber, ob das geht -- `WAYLAND_DISPLAY` als absoluter Pfad, ein
**kurzes** `XDG_RUNTIME_DIR` (Sockel duerfen keine hundert Zeichen
ueberschreiten) und `dbus-run-session`. Was sich so nicht herstellen laesst,
ist die Abwesenheit des Dienstes: Loopback ist geteilt.

**Ein Waechter laeuft auch dann, wenn man ihn nicht meint.** `systemctl --user
stop orangedeck` hielt zehn Sekunden: das installierte Plugin des Wirts
startet die Unit nach. Stilllegen liess es sich ohne eine einzige Datei zu
verschieben -- `dms ipc call plugins disable orangedeck`, und hinterher
`enable`.

**`console.warn` aus QML kommt auf dem Schreibtisch nicht an.** Auf Android
landet es im logcat, hier in keinem Strom -- der Hinweis im Abschluss vom
18.09. gilt nur fuer das Telefon. Gemessen wurde stattdessen **ins Bild**:
`ctx.fillText` mit den Zahlen, ein Bildschirmfoto, danach wieder raus.

**Das Verzeichnis von DMS will kein 960x540.** In der Planung stand diese
Groesse als Vorgabe; `CONTRIBUTING.md` sagt das Gegenteil -- jedes
Seitenverhaeltnis ist recht, die Karte wird daraus gebaut. Auch hier galt:
**vor dem Antrag die Regeln des Gegenuebers lesen**, nicht die eigene Notiz
darueber.

### Und was ich selbst falsch gemacht habe

- **`pkill -f` mit einem Muster, das in der Huelle stand, aus der es lief** --
  und damit genau den Fehler wiederholt, der im Abschluss vom 18.09. steht.
  Der Probestand beendet sich jetzt ueber seine Prozessgruppe; der Rueckfall
  fragt `/proc/<pid>/environ`, nicht die Befehlszeile.
- **`niri msg` in der Probe befragte den Compositor des Wirts**, weil
  `NIRI_SOCKET` in der Umgebung stand. Die Fensterliste war seine, nicht die
  der Probe -- und ich habe sie erst fuer die Probe gehalten.
- **`rm -rf` ueber ein Laufzeitverzeichnis mit Einhaengungen** (gvfs,
  Dokumenten-Portal): eine Wand aus "Ressource belegt", geraeumt hat es
  nichts.
- **`[ -f ... ] && cp` als eigene Zeile unter `set -e`**: fehlt die Datei,
  endet das Skript dort -- im Erzeuger waeren damit alle Pruefungen am Ende
  stillschweigend ausgefallen.
- **Den Dienst des Anwenders gestoppt, ohne den Waechter zu bedenken**; die
  erste Messung ohne Dienst war deshalb keine.

### Was sonst noch offen ist

1. **Die Bilder** (siehe oben und `docs/BILDER.md`): eines fuer das
   DMS-Verzeichnis, zwei bis drei fuer das README des Plugin-Repos, drei bis
   fuenf Handybilder fuer den F-Droid-Eintrag.
2. **Das Plugin-Repo und der PR** ins DMS-Verzeichnis (Anwender).
3. **Der Tooltip-Untergrund** kostet Rechenzeit in der Weichzeichnung selbst,
   nicht im Nachziehen (18.09. gemessen, Riegel verworfen). Wer sparen will,
   muss an das abgenommene Aussehen.
4. ~~**Punkt 9 unter Fedora bestaetigen.**~~ **Bestaetigt am 25.09.2026**
   (Fedora 44 KDE Live, Flatpak). Die Sitzung lief unter **Wayland**, nicht
   X11; Fedora 44 KDE bringt keine X11-Sitzung mehr mit. Mit 0.2.12 stand
   das Fenster auch dort ohne Symbol, in Titelleiste und Leiste. Mit dem
   Stand `c34f3a7` (Bauplan `...dev.yml`) zeigen beide das Zeichen. Bilder
   unter `~/.local/share/orangedeck/pruefbilder/fedora-2026-09-25/`.
   **Falle dabei:** `tools/pruefvm.sh bauen` nahm den Bauplan zum
   Ausliefern und damit den festgenagelten Commit von 0.2.12; der erste
   Lauf pruefte deshalb die alte Fassung. Jetzt `ORANGEDECK_VM_BAUPLAN=dev`.
5. **Laeden.** Flathub vorerst nicht (KI-Regeln), IzzyOnDroid gar nicht. Das
   eigene F-Droid-Repo laeuft; jedes Release geht mit `tools/fdroid-repo.sh
   <v>` und einem Push hinein. Offen: **Google Play** entscheidet der Anwender
   (25 $, Ausweis, 12 Tester ueber 14 Tage). **Google verlangt ab 30.09.2026**
   in Brasilien, Indonesien, Singapur und Thailand, ab 2027 weltweit, einen
   registrierten Entwickler fuer jede App auf zertifizierten Telefonen, auch
   ausserhalb von Play.
6. **Windows**: ungeprueft sind 600 MB im Markt, die README-Startzeile in
   Win+R, Skalierung ueber 100 %, SmartScreen. **macOS**: baut in der CI, nie
   geprueft, kein Paket; die Seite sagt es jetzt so.
7. **`bitfeed`**: eine Messung in der Sitzung des Anwenders, `kitten panel
   --edge=background` unter niri (braucht sein OK), dann Stufe 3 und 4.
8. **Am Telefon ein zweiter Tipp innerhalb der Doppeltipp-Zeit** auf dieselbe
   Kachel setzt die Sicht zurueck, statt den Explorer zu oeffnen. So gewollt,
   aber wer schnell tippt, merkt es. Beobachten.
9. **Das alte Cloudflare-Projekt `orangedeck`** loescht sich nur ueber die API
   (alle Deployments zuerst). Schadet nicht, kostet nichts.
10. **Shopatch** hat ein eigenes GitHub-Konto (Einzelunternehmen, also streng
    genommen ein zweites). Umwandeln in eine Organisation in Ruhe pruefen,
    wegen der Shopify-Anbindungen am Login -- Sache des Anwenders.
11. **`setOrganizationDomain("21rebel.dev")`** steht noch in `main.cpp`. Unter
    Linux steht die Domain nicht im Pfad der Einstellungen
    (`~/.config/orangedeck/orangedeck.conf`, nachgesehen), unter macOS schon --
    Aendern wuerde sie dort verschieben. Entscheidung des Anwenders.
12. **Die naechste Fassung** braucht einen Freigabetext, der die vier
    Korrekturen nennt (Gebuehrenrate, Preisachse, Zahlenformate,
    Fenstersymbol). Die ISO-Datumsschreibweise in der englischen Oberflaeche
    gehoert ebenfalls hinein: sie faellt auf.
13. **Idee fuer spaeter**: Wallet direkt auf dem Telefon.

### Fuer den naechsten Lauf

    Repo: github.com/orangedeck-dev/orangedeck -- gh immer mit -R orangedeck-dev/orangedeck
      (zwei Remotes im Ordner; der alte Name 21Rebel leitet nur weiter)
    Git im Repo: Satoshoe <info@orangedeck.dev> (lokal gesetzt, NICHT global)
    curl -4 / -6 -m 10 https://mempool.space/api/blocks/tip/height
    Dienst nachsehen (Port 21021, nicht 8787):
      curl -s http://127.0.0.1:21021/state | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['seq'], d['source'], d['mempool']['count'])"
      zweimal im Abstand messen -- steht `seq`, traegt der Draht nichts
      die Wache meldet sich:  journalctl --user -u orangedeck | grep schweigt
      **Der Waechter im DMS-Plugin startet die Unit binnen 10 s nach.** Wer den
      Dienst wirklich weg haben will:  dms ipc call plugins disable orangedeck
      (und hinterher enable), dann erst systemctl --user stop orangedeck
    laeuft ein Prozess:  ps -C <name>  -- NIE pgrep -f / pkill -f mit einem Muster,
      das in der eigenen Befehlszeile steht: das beendet die eigene Shell
    Diese Werkzeug-Shell trennt Variablen nicht: keine Befehle in $VAR legen,
      ANDROID_SERIAL=... exportieren statt "adb -s ..." in einer Variable
    console.warn aus QML: nur auf Android (logcat "W qml"). Auf dem Schreibtisch
      kommt es nirgends an -- dort ins Bild messen (ctx.fillText) und wieder raus
    DMS-Plugin:
      tools/dms-plugin.sh              erzeugt build/dms-plugin (kopiert, ohne Symlinks)
      tools/dms-plugin.sh --repo       dasselbe als Git-Arbeitsbaum zum Pushen
      tools/dms-probe.sh neu|start|popout|bild <datei>|befehl ...|ende
        geschachteltes niri + dms mit frischem HOME; dort ist das Standard-Thema,
        Englisch und kein Dienst -- der Ort fuer die Bilder und fuer "laeuft allein"
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
      beenden: adb -s emulator-5554 emu kill
    Maus im Xvfb (Klick, Rad, Doppelklick, Zeiger fuer den Tooltip):
      Xvfb :97 -screen 0 1400x900x24 & ; DISPLAY=:97 HOME=<eigenes> ./build/orangedeck-app --source direct --id probe
      DISPLAY=:97 python3 -c 'import sys;sys.path.insert(0,"tools");import xtest; xtest.maus_nach(x,y); xtest.klick(x,y); xtest.rad(True,6)'
      Bild: DISPLAY=:97 magick import -window root <datei>.png
      Fenstereigenschaften: w=xtest.fenster_suchen(); w.get_wm_class(); _NET_WM_ICON ueber get_full_property
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
| [19.09.2026](journal/2026-09-19.md) | 0.2.12 veroeffentlicht, Umzug nach `orangedeck-dev`, eigenes F-Droid-Repo unter fdroid.orangedeck.dev, die Seite verteilt selbst. |
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
