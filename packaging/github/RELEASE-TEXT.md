<!-- Der Text unten ist der Entwurf fuer 0.2.12 (19.09.2026). "Tested on" und
     die Pruefsummen sind Platzhalter, bis Punkt 2 bis 8 erledigt sind. Die
     Texte von 0.2.8 bis 0.2.11 stehen in der Geschichte dieser Datei.

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

This release keeps the Android widgets useful when the network is gone and makes the Android package much smaller.

## What's new since 0.2.11

- Android widgets keep their numbers when a fetch fails. Until now they showed "not reachable right now" and nothing else, even when the price from a minute ago was known. Now they show the last values they had, and the title turns into the time those values were fetched, for example "as of 08:16". When the network is back they update and show their name again.
- On Android, tapping a tile in the mempool mosaic keeps its details on screen. Until now they were only visible while the finger rested on the tile, and a tap did nothing. Now a tap shows the details and leaves them there, a tap on empty space hides them, and a second tap on the same tile opens the transaction in the explorer. Double tap resets the zoom again, which on phones had not worked either.
- On the desktop, clicking a tile in the mempool mosaic opens the transaction in the explorer. The details showed on hover, but the click did nothing. A double click resets the zoom, so a single click waits a moment before it opens the explorer.
- The Android package is 23 MB instead of 57 MB. The native libraries are now compressed inside the APK. Android unpacks them during installation, so the app takes a little more space on the phone afterwards.
- Error messages on screen are short reasons in every language, such as "not found" or "too many requests", instead of technical text from the network library. The technical version goes to the log.
- On Linux, the service notices when the live feed from mempool.space goes silent without closing the connection. It reconnects after a minute and fills the gap from the regular interface in the meantime. Before, the desktop widgets could stand still for hours while everything looked connected.
- The settings of the Dank Material Shell plugin speak the same thirteen languages as the app.
- The project moved to [github.com/orangedeck-dev/orangedeck](https://github.com/orangedeck-dev/orangedeck). Old links redirect.

## Windows: `orangedeck-0.2.12-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.12-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Installs over 0.2.11.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.12-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

The same APK is also in the OrangeDeck F-Droid repository, which keeps it up to date in F-Droid, Droid-ify or Neo Store:

    https://fdroid.orangedeck.dev/repo?fingerprint=06E62F144A293077C333DE18FA6076364FE7FB0718F1F3D6E8897E7291DC4C59

## Linux: `orangedeck-0.2.12.flatpak`

    flatpak install --user orangedeck-0.2.12.flatpak

This pulls the KDE runtime 6.9 from Flathub. All six views are included on Linux. To serve the wallet to other Linux computers on your network:

    systemctl --user edit orangedeck.service
    # [Service]
    # Environment=ORANGEDECK_ADDR=0.0.0.0

## Tested on

- Samsung Galaxy A55 with Android 16, this signed APK installed over earlier builds of 0.2.12, the first of which went over 0.2.11: all tabs with live data, and in the feed a tap shows the details of a tile and keeps them, a tap on empty space hides them, a second tap opens the explorer and a double tap resets the zoom. Widgets keeping their numbers without network, with "Stand 08:16" in the title and back to normal once the network returned, were seen on a test build from the same day with the same widget code, not on this file.
- Windows 11 25H2 in a VM, this ZIP: feed, clock, mining, explorer and market (heatmap) with data, hovering a tile shows its details and a click opens that transaction in the explorer, the digits switch tabs, the comma key opens the settings. A widget stays on the desktop with Win+D and shows data, Q closes widget and window. No new detection from Defender.
- This Flatpak bundle, freshly installed in live sessions of Ubuntu 24.04 with GNOME and Fedora 44 with KDE: feed, clock and market with live data, hovering a tile shows its details, a click opens that transaction in the explorer, and a double click after zooming in resets the view without opening it. The settings open with the comma key. Mining, liquidations and the heatmap were seen on an earlier build of this release the same day.
- Not tested yet: macOS, real tablets, and display scaling above 100% on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    4177c15e5f27340f0295c984aa57fac0cd3ccbfe97fc3b250a8d004b9d454d12  orangedeck-0.2.12-windows-x86_64.zip
    640d5ac554ed9b6881f15a6a1ecd83f44e573b3be6f2d085ca9ccefd92932372  orangedeck-0.2.12-arm64-v8a.apk
    527d11e4f17a8430845850f76ecfbbd4da12e4cc4c29f9a86f662b296bb9635b  orangedeck-0.2.12.flatpak

---

## Deutsch

0.2.12 hält die Android-Widgets brauchbar, wenn das Netz weg ist, und macht das Android-Paket deutlich kleiner.

Android-Widgets behalten ihre Zahlen, wenn ein Abruf scheitert. Bisher stand dann nur "gerade nicht erreichbar" da, auch wenn der Kurs von vor einer Minute bekannt war. Jetzt zeigen sie den letzten Stand, und die Überschrift wird zur Uhrzeit, zu der er geholt wurde, etwa "Stand 08:16". Ist das Netz wieder da, holen sie nach und tragen wieder ihren Namen.

Unter Android bleiben die Angaben zu einer Kachel im Mempool-Feld stehen, wenn man sie antippt. Bisher waren sie nur zu sehen, solange der Finger darauf lag, und ein Tipp bewirkte nichts. Jetzt zeigt ein Tipp die Angaben und lässt sie stehen, ein Tipp auf leere Fläche räumt sie weg, und ein zweiter Tipp auf dieselbe Kachel öffnet die Transaktion im Explorer. Doppeltippen setzt die Vergrößerung wieder zurück, auch das ging am Telefon bisher nicht.

Am Rechner öffnet ein Klick auf eine Kachel die Transaktion im Explorer. Die Angaben erschienen beim Überfahren, der Klick bewirkte nichts. Ein Doppelklick setzt die Vergrößerung zurück, deshalb wartet ein einfacher Klick einen Augenblick, bevor er den Explorer öffnet.

Das Android-Paket ist 23 statt 57 MB groß. Die Bibliotheken liegen jetzt gepackt im APK. Android entpackt sie bei der Installation, die App belegt danach etwas mehr Platz auf dem Telefon.

Fehlermeldungen auf dem Bildschirm sind kurze Gründe in jeder Sprache, etwa "nicht gefunden" oder "zu viele Abfragen", statt technischer Texte aus der Netzwerkbibliothek. Die technische Fassung steht im Protokoll.

Unter Linux merkt der Dienst, wenn der Live-Datenstrom von mempool.space verstummt, ohne die Verbindung zu schließen. Er verbindet sich nach einer Minute neu und holt die Lücke solange über die normale Schnittstelle nach. Vorher konnten die Desktop-Widgets stundenlang stillstehen, während alles verbunden aussah. Die Einstellungen des Plugins für die Dank Material Shell sprechen dieselben dreizehn Sprachen wie die App.

Das Projekt ist nach [github.com/orangedeck-dev/orangedeck](https://github.com/orangedeck-dev/orangedeck) umgezogen, alte Links leiten weiter. Das APK gibt es auch im F-Droid-Repo von OrangeDeck, Adresse oben im Abschnitt Android.

Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
