<!-- Der Text unten ist der Entwurf fuer 0.2.13 (25.09.2026). Die Texte von
     0.2.8 bis 0.2.12 stehen in der Geschichte dieser Datei.

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

A Bitcoin dashboard with the mempool as a live tile mosaic, a block height clock, mining figures for the whole network and your own Bitaxe, a block explorer and the BTC market. MIT licensed, no account needed.

This release fixes four things that looked wrong outside of the German interface or outside of the system it was built on.

## What's new since 0.2.12

- Numbers and dates follow the language of the interface. The English interface showed German forms next to English text, such as "0,01" in the legend, "78.324 transactions" and "19.09.2026". Now it writes 0.01 and 78,324, and dates in English are written as 2026-09-25, so day and month cannot be mixed up.
- The fee rate in the details of a mempool tile matches the size and fee shown above it. It came from mempool.space, which includes parent transactions and sigops, so it could differ from fee divided by size in the same box. The tooltip now shows its own calculation. If the effective rate differs, it has a line of its own, and the tile keeps its color by the effective rate, because that is the one miners choose by.
- The price axis in the market view is no longer cut off at the right edge. On Ubuntu and Fedora the last digit was missing, because the labels were measured in a different font than the one they were drawn in.
- On Linux the window shows its icon in the title bar and the taskbar. It had none on Fedora with KDE. The window now carries the icon itself, and the desktop file names the window class for X11.

## Windows: `orangedeck-0.2.13-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.13-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Installs over 0.2.12.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.13-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

The same APK is also in the OrangeDeck F-Droid repository, which keeps it up to date in F-Droid, Droid-ify or Neo Store:

    https://fdroid.orangedeck.dev/repo?fingerprint=06E62F144A293077C333DE18FA6076364FE7FB0718F1F3D6E8897E7291DC4C59

## Linux: `orangedeck-0.2.13.flatpak`

    flatpak install --user orangedeck-0.2.13.flatpak

This pulls the KDE runtime 6.9 from Flathub. All six views are included on Linux. To serve the wallet to other Linux computers on your network:

    systemctl --user edit orangedeck.service
    # [Service]
    # Environment=ORANGEDECK_ADDR=0.0.0.0

## Tested on

- Samsung Galaxy A55 with Android 16 in German, this signed APK installed over 0.2.12 with its settings kept: the tabs with live data, German numbers and dates, and the full price axis in the market view.
- Windows 11 in a VM with a German system, this ZIP: feed and market with live data, the fee rate in the details of a tile matches fee divided by size, and the price axis shows every digit.
- This Flatpak bundle, freshly installed in live sessions of Ubuntu 24.04 with GNOME and Fedora 44 with KDE, both in English: feed and market with live data, English numbers and dates, the fee rate in the tile details matches its own numbers, and the price axis shows every digit. On Fedora the icon shows in the title bar and the taskbar. On Ubuntu the dock showed a generic icon, because flatpak was installed into the running live session and the session did not know its path yet; on an installed system that is set at login.
- Not tested yet: macOS, real tablets, and display scaling above 100% on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    8999e5f5536606e462ecc7838ca52b8836fee08b12d993806357638c72c81c2c  orangedeck-0.2.13-windows-x86_64.zip
    ef54af3ef4e7dcaec78bbb81be18ddf87c9708160c80187c8e8219928ef85e07  orangedeck-0.2.13-arm64-v8a.apk
    85872cb477a8f495f37e79e379e27a4fe09644c7819110a493cd719caa625542  orangedeck-0.2.13.flatpak

---

## Deutsch

0.2.13 behebt vier Dinge, die außerhalb der deutschen Oberfläche oder außerhalb des Systems, auf dem gebaut wurde, falsch aussahen.

Zahlen und Datum folgen der Sprache der Oberfläche. In der englischen Oberfläche standen deutsche Schreibweisen neben englischem Text, etwa "0,01" in der Legende, "78.324 transactions" und "19.09.2026". Jetzt steht dort 0.01 und 78,324, und das Datum steht auf Englisch als 2026-09-25, damit Tag und Monat nicht zu verwechseln sind.

Die Gebührenrate in den Angaben einer Mempool-Kachel passt zu Größe und Gebühr darüber. Sie kam von mempool.space und rechnet Vorgänger-Transaktionen und Sigops mit, deshalb konnte sie von Gebühr geteilt durch Größe im selben Kasten abweichen. Der Tooltip zeigt jetzt die eigene Rechnung. Weicht die wirksame Rate ab, steht sie in einer eigenen Zeile, und die Kachel behält ihre Farbe nach der wirksamen Rate, weil Miner nach ihr auswählen.

Die Preisachse im Markt wird am rechten Rand nicht mehr abgeschnitten. Unter Ubuntu und Fedora fehlte die letzte Ziffer, weil die Beschriftung in einer anderen Schrift gemessen wurde, als in der sie gezeichnet wird.

Unter Linux zeigt das Fenster sein Symbol in der Titelleiste und in der Leiste. Unter Fedora mit KDE hatte es keines. Das Fenster trägt das Symbol jetzt selbst, und die Desktop-Datei nennt die Fensterklasse für X11.

Das APK installiert sich über 0.2.12 und steht auch im F-Droid-Repo von OrangeDeck, Adresse oben im Abschnitt Android. Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
