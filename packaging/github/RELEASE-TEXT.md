<!-- Der Text unten ist der Entwurf fuer 0.2.15 (26.09.2026). Die Texte von
     0.2.8 bis 0.2.14 stehen in der Geschichte dieser Datei.

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

This release removes the watch-only wallet.

## What's new since 0.2.14

- The watch-only wallet is gone, on every platform. Since 15 September it had only existed on Linux with the OrangeDeck service, and it was the one part of OrangeDeck that asked for anything about you: the mempool instance saw which addresses were queried. Now every platform shows the same five views: feed, clock, mining, explorer and market.
- The service no longer derives addresses from an xpub. A watch list left in `~/.config/orangedeck/sources.json` is ignored and can be deleted; `--watch-add`, `--watch-list` and `--watch-remove` say that the wallet no longer exists.
- If the wallet was your start view, the last view or part of your tab order, OrangeDeck opens the first view of your order instead. `--view 4` does the same.
- The service writes `sources.json` with permissions 600 on every path, including the Mempool instance field from 0.2.14.

## Windows: `orangedeck-0.2.15-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.15-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Installs over 0.2.14.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.15-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

The same APK is also in the OrangeDeck F-Droid repository, which keeps it up to date in F-Droid, Droid-ify or Neo Store:

    https://fdroid.orangedeck.dev/repo?fingerprint=06E62F144A293077C333DE18FA6076364FE7FB0718F1F3D6E8897E7291DC4C59

## Linux: `orangedeck-0.2.15.flatpak`

    flatpak install --user orangedeck-0.2.15.flatpak

This pulls the KDE runtime 6.9 from Flathub.

## Tested on

- Samsung Galaxy A55 with Android 16 in German, this signed APK installed over 0.2.14 with its settings kept: it opens with the five tabs Feed, Clock, Mining, Explorer and Market, and the miner view shows the Bitaxe as before.
- Windows 11 in a VM with a German system, this ZIP: started with `--view 4`, it opens the feed with the five tabs Feed, Clock, Mining, Explorer and Market.
- This Flatpak bundle on a Linux desktop, in English, with old settings that had the wallet as start view, last view and in the tab order: it opens the feed, and the tab bar ends with Market.
- The service on Linux with a `sources.json` that still contains a watch list: it starts, `/wallets` answers 404, and the state carries no wallet fields.
- Not tested in this release: the live sessions of Ubuntu and Fedora, macOS, real tablets, and display scaling above 100% on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    5e390321ce3d45b926782cc561ab84911ebc29cbe610f43283c7706f193a25f3  orangedeck-0.2.15-windows-x86_64.zip
    c18b03de28f735b2efb1531dae3694feee9df93b10f4061f4a3d79dde7134319  orangedeck-0.2.15-arm64-v8a.apk
    522c30eadbe71ab3a815f00b1410ce80c0d5ed62ed758ef971df6fb794ee8265  orangedeck-0.2.15.flatpak

---

## Deutsch

0.2.15 entfernt die Wallet zum Beobachten.

Die Wallet ist weg, auf allen Plattformen. Seit dem 15. September gab es sie nur noch unter Linux mit dem OrangeDeck-Dienst, und sie war der einzige Teil von OrangeDeck, der etwas über Sie wissen wollte: Die Mempool-Instanz sah, welche Adressen abgefragt wurden. Jetzt zeigen alle Plattformen dieselben fünf Ansichten: Feed, Uhr, Mining, Explorer und Markt.

Der Dienst leitet keine Adressen mehr aus einem xpub ab. Eine Beobachtungsliste in `~/.config/orangedeck/sources.json` wird übergangen und kann gelöscht werden. War die Wallet die Start- oder zuletzt benutzte Ansicht oder Teil der Reiterreihenfolge, öffnet OrangeDeck stattdessen die erste Ansicht dieser Reihenfolge.

Das APK installiert sich über 0.2.14 und steht auch im F-Droid-Repo von OrangeDeck, Adresse oben im Abschnitt Android. Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
