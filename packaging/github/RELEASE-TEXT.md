<!-- Der Text unten ist der Entwurf fuer 0.2.17 (08.10.2026). Die Texte von
     0.2.8 bis 0.2.16 stehen in der Geschichte dieser Datei.

     **Die Pruefliste gilt fuer jede Nummer, nicht nur fuer die, bei der sie
     entstand.** Am 14.09.2026 nannte sie fuer 0.2.9 nur Windows und das
     Galaxy, weil am Vortag nur dort gemessen worden war; Linux fiel erst an
     einem leeren Platzhalter auf. Deshalb steht hier alles, jedes Mal, und
     was nicht gemessen ist, wird nicht als getestet genannt.

     **Vor dem Tag:**

     1. Metainfo (`packaging/flatpak/*.metainfo.xml`): Fassung, Datum, und die
        Beschreibung gegen das, was die Nummer wirklich bringt. Am 14.09.2026
        beschrieb sie noch den Markt ueber einen Dienst, einen Tag nachdem er
        ohne Dienst kam. **Auch was wegfaellt**, gegen den Text der letzten
        Nummer gehalten: 0.2.9 kuendigte die Wallet unter Android und Windows
        an, 0.2.10 nimmt sie dort heraus.
     2. Geraetelauf am Galaxy mit dem gebauten APK, vom Anwender selbst
        durchgegangen. Danach `adb shell wm user-rotation free`.
     3. Windows-VM: Feed, Mining und Markt mit Daten, Zahnrad (auch `,`),
        Widgets mit Win+D, Q schliesst Fenster und Widget, keine neue
        Defender-Erkennung.
     4. Linux in **beiden** Pruef-VMs (Ubuntu GNOME, Fedora KDE), das Buendel
        aus dem Pin frisch installiert: alle Reiter, Einstellungen ueber `,`.
     5. `python3 tools/bauplan-pruefen.py`, Pin im Flatpak-Bauplan auf dem
        Commit, der getaggt wird.

     **Vor dem Veroeffentlichen:**

     6. Windows-ZIP aus dem **Lauf auf dem Pin-Commit** (die CI laeuft nur
        auf main, nicht auf Tags; der Pin-Commit unterscheidet sich vom Tag
        nur im Bauplan). Dateien und Bytes gegen das Artefakt halten.
     7. APK signiert der Anwender; Zertifikat gegen den Fingerabdruck unten.
        Test-APKs und ihre Zeilen in `PRUEFSUMMEN.txt` vorher wegraeumen.
     8. Drei Pruefsummen eintragen, "Tested on" nur mit dem, was in Punkt 2
        bis 4 wirklich gesehen wurde.
     9. **Stil des Textes**, maschinell pruefen: keine Gedankenstriche als
        Einschub, keine Mittelpunkte oder Pfeile, keine fett gesetzten
        Satzanfaenge, saubere Interpunktion, Umlaute im deutschen Teil.
     10. Release als Entwurf; veroeffentlicht wird nur mit ausdruecklichem OK
         des Anwenders. -->

A Bitcoin dashboard with the mempool as a live tile mosaic, a block height clock, mining figures for the whole network and your own miners, a block explorer and the BTC market. MIT licensed, no account needed.

A small release with fixes for the mining tab and for the desktop app.

## What's new since 0.2.16

### Mining

- With several miners, the combined hashrate chart no longer disappears when one device misses a few polls. Most of the time that is the Wi-Fi, and the miner keeps hashing. The device stays in the sum with its last value for up to two minutes; after that the chart shows the devices that are still running.
- The pool page remembers whether device types are shown as bars or as a ring, and whether they are sorted by hashrate or by number of miners. Until now both were reset on every start.

### Fixes

- Negative numbers no longer get a thousands separator right after the minus sign. The explorer showed a UTXO change of "-,940".
- In full screen, the button that leaves full screen sat on top of the "i" of the mining tab, so a click opened the legend instead. The buttons of the view now move aside in full screen.
- Keyboard shortcuts work again after typing into a settings field and switching to another tab. Until now F11, "i" and "," did nothing after that.
- Started with `--source`, the settings show the data source that is actually in use. Before, they showed the saved one, and the field for a service on another device was visible although nothing used it.

## Windows: `orangedeck-0.2.17-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.17-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Installs over 0.2.16.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.17-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

The same APK is also in the OrangeDeck F-Droid repository, which keeps it up to date in F-Droid, Droid-ify or Neo Store:

    https://fdroid.orangedeck.dev/repo?fingerprint=06E62F144A293077C333DE18FA6076364FE7FB0718F1F3D6E8897E7291DC4C59

## Linux: `orangedeck-0.2.17.flatpak`

    flatpak install --user orangedeck-0.2.17.flatpak

This pulls the KDE runtime 6.9 from Flathub.

## Tested on

- Samsung Galaxy A55 with Android 16 in German, this signed APK installed over 0.2.16 with its settings kept: the mining tab, the pool page with ring and miners still selected after the app was closed and opened again, leaving full screen with a tap, and all tabs.
- Windows 11 in a VM with a German system: two test miners, one of them dropping out for 25 seconds every minute, with the combined chart staying in place, the pool page keeping ring and miners after a restart, and leaving full screen with a click.
- The Flatpak bundle of the build before the three fixes above in the live sessions of Ubuntu 24.04 and Fedora 44 KDE, in English: all tabs, the settings with `--source direct`, the combined chart with a test miner dropping out, and the pool page keeping its choice after a restart. The three fixes were tested on Linux in the app built from this release, not in the bundle.
- Not tested in this release: macOS, real tablets, the Windows widgets, display scaling above 100% on Windows, and a real cluster of several physical miners; the multi-device views were tested with simulated AxeOS devices. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    6322d2ece54bec79d4c7f122d8a910c8859e50642fc85ee9a26138183918c09a  orangedeck-0.2.17-windows-x86_64.zip
    4abf66f00052165d7cf0145d295c0640d09039bda3d68a6f46933652c5b7bf08  orangedeck-0.2.17-arm64-v8a.apk
    25ee6e9b69eecfba323db61bf58b6c5a7c4eae407e5613a2b697299653aef69e  orangedeck-0.2.17.flatpak

---

## Deutsch

0.2.17 ist eine kleine Fassung mit Korrekturen für den Mining-Reiter und die Desktop-App.

Bei mehreren Minern verschwindet die gemeinsame Hashrate-Kurve nicht mehr, wenn ein Gerät ein paar Abfragen verpasst. Es bleibt bis zu zwei Minuten mit seinem letzten Wert in der Summe, danach zeigt die Kurve die Geräte, die noch laufen. Die Pool-Seite merkt sich, ob die Gerätetypen als Balken oder als Ring erscheinen und wonach sie sortiert sind.

Behoben: Negative Zahlen bekommen kein Trennzeichen mehr direkt hinter dem Minus. Der Knopf zum Verlassen des Vollbilds liegt nicht mehr auf dem i des Mining-Reiters. Die Tastenkürzel wirken wieder, nachdem man in ein Feld der Einstellungen getippt und den Reiter gewechselt hat. Mit `--source` gestartet, zeigen die Einstellungen die Datenquelle, die tatsächlich gilt.

Das APK installiert sich über 0.2.16 und steht auch im F-Droid-Repo von OrangeDeck, Adresse oben im Abschnitt Android. Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
