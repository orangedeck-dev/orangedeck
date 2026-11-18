<!-- Der Text unten ist der Entwurf fuer 0.2.18 (18.11.2026). Die Texte von
     0.2.8 bis 0.2.17 stehen in der Geschichte dieser Datei.

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

This release makes full screen usable on phones again, fixes a bug that reset settings after an update, and tidies up the mining tab.

## What's new since 0.2.17

### Full screen

- The tabs can be reached in full screen again. Until now they were hidden there, and on a phone there was no way to switch to another tab. Pull the content down and the tab row slides in, with the view moving down below it. Scroll on and it slides out again; after half a minute without a touch it goes by itself.

### Mining

- The field for your own payout address is always shown in the mining settings. Until now it only appeared once a pool was entered, and the grey example in the empty pool field looked like an entry, so the field was easy to miss. Without a pool it is now greyed out and says that a pool has to be entered first, and the example reads "e.g. pool.solomining.de".
- The button that opens the miner's web page sits on the left, opposite the "i". The switch between Device, Pool and Network stays centered and no longer runs under the button on a phone.
- In the hashrate charts the labels for the highest and lowest value sit above and below the curve instead of on it. The lower value now uses the unit of the upper one; it showed "235" next to "1.76 TH/s" when it meant 235 GH/s.
- With several miners, the combined hashrate chart appears after ten seconds instead of a minute.
- The pool page shows one error message instead of two.

### Fixes

- Settings keep their values after an update. When a new version added a setting, language, tab order and full screen were back at their defaults on the second start.
- The General settings page shows the version.

### Linux

- A changed miner address takes effect right away, also when the background service is running. Until now the service kept polling the old address, for example after the miner got a new one from the router.
- A block that arrived shortly after the explorer's last update no longer stays missing there until the next block.
- The Flatpak no longer starts the background service when the app gets its data directly from the mempool instance.

## Windows: `orangedeck-0.2.18-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.18-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Installs over 0.2.17.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.18-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

The same APK is also in the OrangeDeck F-Droid repository, which keeps it up to date in F-Droid, Droid-ify or Neo Store:

    https://fdroid.orangedeck.dev/repo?fingerprint=06E62F144A293077C333DE18FA6076364FE7FB0718F1F3D6E8897E7291DC4C59

## Linux: `orangedeck-0.2.18.flatpak`

    flatpak install --user orangedeck-0.2.18.flatpak

This pulls the KDE runtime 6.9 from Flathub.

## Tested on

- Samsung Galaxy A55 in German, this signed APK installed over test builds of this release, which had replaced 0.2.17 with its settings kept: the payout address field, the pool page and device page with a real Bitaxe and pool, the version in the settings, and full screen with the tab row pulled in and out.
- Windows 11 in a VM with a German system, the ZIP from this release: feed, market, the pool page of pool.solomining.de with the new chart labels, the mining settings, the version in the settings, full screen with the tab row pulled in and out with the mouse, the clock widget staying on the desktop after Win+D, and no Microsoft Defender detection.
- The Flatpak bundle of this release in the live sessions of Ubuntu 24.04 and Fedora 44 KDE, in English. Ubuntu with the background service: feed, the mining settings with an empty pool field, and a miner address entered in the settings that was used right away, tested with a simulated AxeOS device. Fedora: market, and full screen with the tab row pulled in and out.
- Not tested in this release: macOS, real tablets, the explorer picking up a new block, the Flatpak without the service, display scaling above 100% on Windows, and a real cluster of several physical miners. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    5f5dd333c3d2652b32b17364bb960976e7a54815dffc18707f0ad64132ac7400  orangedeck-0.2.18-windows-x86_64.zip
    5d91b56da1b0cc7f99c51ff61bddf03cc016237c503f626c3b1faf7ad8b94c51  orangedeck-0.2.18-arm64-v8a.apk
    5759c039f743326c75ec62dabb7c34074a9a4a6007195d1a6ed995e04bd55fa1  orangedeck-0.2.18.flatpak

---

## Deutsch

Mit 0.2.18 ist das Vollbild am Telefon wieder voll bedienbar, die Einstellungen überstehen Updates, und der Mining-Reiter ist aufgeräumt.

Im Vollbild sind die Reiter wieder erreichbar. Zieht man den Inhalt herunter, gleitet die Reiterleiste herein, und die Ansicht rückt darunter. Beim Weiterblättern oder nach einer halben Minute ohne Berührung gleitet sie wieder hinaus.

Das Feld für die eigene Auszahlungsadresse steht in den Mining-Einstellungen jetzt immer da. Ohne Pool ist es ausgegraut und sagt, dass erst ein Pool einzutragen ist. Im leeren Pool-Feld steht das Beispiel als „z. B. pool.solomining.de“ und sieht nicht mehr wie ein Eintrag aus. Der Knopf zur Weboberfläche des Miners sitzt links, damit der Umschalter zwischen Gerät, Pool und Netzwerk mittig bleibt. In den Hashrate-Kurven liegen die Beschriftungen nicht mehr auf der Kurve, und der Tiefstwert steht in der Einheit des Höchstwerts.

Behoben: Brachte eine neue Fassung eine neue Einstellung mit, standen Sprache, Reiterfolge und Vollbild beim zweiten Start wieder auf der Vorgabe. Unter Linux gilt eine geänderte Miner-Adresse jetzt sofort, auch wenn der Dienst läuft.

Das APK installiert sich über 0.2.17 und steht auch im F-Droid-Repo von OrangeDeck, Adresse oben im Abschnitt Android. Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
