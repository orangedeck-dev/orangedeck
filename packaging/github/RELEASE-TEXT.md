<!-- Der Text unten ist der Entwurf fuer 0.2.14 (26.09.2026). Die Texte von
     0.2.8 bis 0.2.13 stehen in der Geschichte dieser Datei.

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

This release lets you choose where the data comes from.

## What's new since 0.2.13

- A new field in the settings, Mempool instance, under General. Leave it empty for mempool.space, or enter another public instance such as mempool.emzy.de or mempool.ninja, or your own node, for example http://umbrel.local:3006. Without a scheme the address is taken as https, and an /api at the end does not matter.
- The instance applies everywhere: the live feed and every view in direct mode, the details of a mempool tile, the explorer, the Android widgets, and the OrangeDeck service on Linux. When the field changes, the service on the same computer switches over, saves the address in sources.json and reconnects.
- The service accepts that change only from the same computer, only as JSON and never with an Origin header. No other device on the network and no website in a browser can point it somewhere else. This matters because the service also asks the instance about the addresses you watch.
- The data source choice now reads "Directly to the mempool instance" instead of naming mempool.space.

## Windows: `orangedeck-0.2.14-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.14-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Installs over 0.2.13.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.14-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

The same APK is also in the OrangeDeck F-Droid repository, which keeps it up to date in F-Droid, Droid-ify or Neo Store:

    https://fdroid.orangedeck.dev/repo?fingerprint=06E62F144A293077C333DE18FA6076364FE7FB0718F1F3D6E8897E7291DC4C59

## Linux: `orangedeck-0.2.14.flatpak`

    flatpak install --user orangedeck-0.2.14.flatpak

This pulls the KDE runtime 6.9 from Flathub. All six views are included on Linux. To serve the wallet to other Linux computers on your network:

    systemctl --user edit orangedeck.service
    # [Service]
    # Environment=ORANGEDECK_ADDR=0.0.0.0

## Tested on

- Samsung Galaxy A55 with Android 16 in German, this signed APK installed over 0.2.13 with its settings kept: the field under General, the clock with live data from mempool.emzy.de, and "no connection" with an address that does not exist.
- Windows 11 in a VM with a German system, this ZIP: the clock with live data with the field empty, "no connection" with an address that does not exist, and live data again with mempool.ninja. The field shows under General.
- This Flatpak bundle on a Linux desktop, in English: the same three cases with the same results, and the field under General.
- The service on Linux: switched to mempool.ninja and back through the field's request, with the address saved and the connection renewed; requests from the network, with an Origin header or not as JSON were refused.
- Not tested in this release: the live sessions of Ubuntu and Fedora, macOS, real tablets, and display scaling above 100% on Windows. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    fb792156e52c5d705f3c5dd7328d009e487741a5dd954a65e89f85c48b7bcd74  orangedeck-0.2.14-windows-x86_64.zip
    5765cb87c3e81409bb9faab209690f9a74cbd517d4974f11c98723dc6981b0eb  orangedeck-0.2.14-arm64-v8a.apk
    e45c8b74ab0a336b823eb440988f64e200349f689dec0bb975806ca817bcaf9f  orangedeck-0.2.14.flatpak

---

## Deutsch

0.2.14 lässt wählen, woher die Daten kommen.

In den Einstellungen gibt es unter Allgemein ein neues Feld, Mempool-Instanz. Leer bleibt es bei mempool.space. Eingetragen werden kann eine andere öffentliche Instanz wie mempool.emzy.de oder mempool.ninja oder der eigene Node, etwa http://umbrel.local:3006. Ohne Schema gilt https, und ein /api am Ende stört nicht.

Die Instanz gilt überall: im Live-Feed und in allen Ansichten im Direktbezug, in den Details einer Mempool-Kachel, im Explorer, in den Android-Widgets und im OrangeDeck-Dienst unter Linux. Ändert sich das Feld, stellt der Dienst auf demselben Rechner mit um, speichert die Adresse in sources.json und verbindet sich neu.

Der Dienst nimmt diese Änderung nur vom selben Rechner an, nur als JSON und nie mit einem Origin-Kopf. Kein anderes Gerät im Netz und keine Webseite im Browser kann ihn damit woandershin lenken. Das zählt, weil der Dienst die Instanz auch nach den beobachteten Adressen fragt.

Das APK installiert sich über 0.2.13 und steht auch im F-Droid-Repo von OrangeDeck, Adresse oben im Abschnitt Android. Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
