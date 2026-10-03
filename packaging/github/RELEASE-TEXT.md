<!-- Der Text unten ist der Entwurf fuer 0.2.16 (03.10.2026). Die Texte von
     0.2.8 bis 0.2.15 stehen in der Geschichte dieser Datei.

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

This release is about mining with more than one device, and about seeing your miner when you are not on its network.

## What's new since 0.2.15

### Several miners

- The settings have one field per miner address. The + below adds another, × removes one. Before, several addresses had to be typed into one field, separated by `|`.
- With several devices the mining tab shows the combined hashrate and its history, the total power and J/TH, and one row per device. Tap a row to open that device with its chart, hash domains and best shares; "All devices" goes back.
- When the devices mine on more than one pool, the list is grouped by pool. A device that is off keeps its name and its group.
- Devices with several chips (Bitaxe Hex, GT) show one bar per chip. Until now only the first chip was read.
- On phones the device page uses larger text, as the network page already did.

### Pool page

- A new page between Device and Network for pools with the public-pool interface, such as pool.solomining.de or public-pool.io. Enter the pool in the mining settings and the page appears: pool hashrate and history, miners, blocks found, and which devices mine there, as bars or a ring, by hashrate or by number of miners.
- Optionally, enter your payout address. The page then shows your devices as the pool sees them: hashrate, best share, when the pool last heard from them. A worker name copied along with the address (`bc1q….bitaxe`) is ignored.
- The address stays on your device and is sent only to the pool you entered, which knows it from your miner anyway.

### When the miner is out of reach

- If a miner cannot be reached on the network, for example from a guest Wi-Fi with client isolation or on mobile data, its row shows the pool's numbers instead, marked "per pool". As soon as the miner answers again, the row switches back to its own numbers. A device never appears twice.
- The device details then show which best share this is: the one of the current pool connection with its duration, and, if only this device mines to the address, the best ever at this pool.
- The Android miner widgets fall back to the pool the same way.

### Fixes

- The Android miner widgets read only the first address correctly when more than one was set. They split at commas while the app stores `|`.
- The service on Linux reconnects when no new transaction has arrived for 90 seconds, and retries a failed block summary after 20 seconds.

## Windows: `orangedeck-0.2.16-windows-x86_64.zip`

Unzip anywhere and run `orangedeck-app.exe`. Requires Windows 10 or 11, 64-bit.

The build is not signed. A certificate costs money every year, and this project is meant to cost nothing. SmartScreen will warn you on the first start (More info > Run anyway). Please compare the checksum below before you do.

To start a widget, for example the block clock in the top right corner:

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id clock

Click a widget and press Q to close it. Details are in `packaging/widgets/README.md`.

## Android: `orangedeck-0.2.16-arm64-v8a.apk`

For phones and tablets with a 64-bit ARM processor (arm64-v8a) and Android 9 or newer. Installs over 0.2.15.

Please check the signature before installing:

    apksigner verify --print-certs orangedeck-0.2.16-arm64-v8a.apk

The SHA-256 fingerprint of the signing certificate must be:

    B3:CC:83:79:CE:27:93:4D:30:B5:48:B3:F5:A1:D5:51:6E:E1:11:14:FF:D5:4E:F1:7E:57:D2:38:12:02:92:E0

The same APK is also in the OrangeDeck F-Droid repository, which keeps it up to date in F-Droid, Droid-ify or Neo Store:

    https://fdroid.orangedeck.dev/repo?fingerprint=06E62F144A293077C333DE18FA6076364FE7FB0718F1F3D6E8897E7291DC4C59

## Linux: `orangedeck-0.2.16.flatpak`

    flatpak install --user orangedeck-0.2.16.flatpak

This pulls the KDE runtime 6.9 from Flathub.

## Tested on

- Samsung Galaxy A55 with Android 16 in German, this signed APK installed over 0.2.15 with its settings kept: several test miners entered through the + fields (also when + is tapped while the keyboard still holds the typed word), the list grouped by pool, a device opened and closed. A real Bitaxe that cannot be reached from a guest Wi-Fi appears with the numbers of pool.solomining.de, marked "per pool", with the best share of the current pool connection and of all time at this pool.
- Windows 11 in a VM with a German system, this ZIP: several test miners, one of them never reached on the network and shown through a test pool, its details, and the pool page against pool.solomining.de with bars and ring.
- This Flatpak bundle in the live sessions of Ubuntu 24.04 and Fedora 44 KDE, in English: the + fields, the pool page against pool.solomining.de over HTTPS with bars and ring, and a test miner that was never reached on the network shown through a test pool, without a second row for it.
- Not tested in this release: macOS, real tablets, display scaling above 100% on Windows, and a real cluster of several physical miners; the multi-device views were tested with simulated AxeOS and cgminer devices. If something looks wrong, please open an issue.

## Checksums (SHA-256)

    ab6aff6c15ad4f6f6780efbf5fd668541a5ded9b412c81b737fbccc07c9da184  orangedeck-0.2.16-windows-x86_64.zip
    29fcbf7b9b1f60a5d1326294816f34fd047a377f306e7e793ae3c272e988640b  orangedeck-0.2.16-arm64-v8a.apk
    1bb355f8789f487f0b89558d59c67a33db7e09ec498b6f32bd9f0923cabbcea0  orangedeck-0.2.16.flatpak

---

## Deutsch

In 0.2.16 geht es um mehrere Miner und darum, den eigenen Miner auch dann zu sehen, wenn man nicht in seinem Netz ist.

Jede Miner-Adresse hat in den Einstellungen ihr eigenes Feld, weitere kommen über +. Mit mehreren Geräten zeigt der Mining-Reiter die gemeinsame Hashrate mit Verlauf, Leistung und J/TH und eine Zeile je Gerät; ein Tipp öffnet das Gerät. Laufen die Geräte auf mehreren Pools, ist die Liste danach gruppiert. Geräte mit mehreren Chips zeigen einen Balken je Chip.

Die neue Seite Pool liest die offene Statistik von Pools mit public-pool-Schnittstelle, etwa pool.solomining.de. Mit der eigenen Auszahlungsadresse, freiwillig, zeigt sie auch die eigenen Geräte so, wie der Pool sie sieht. Die Adresse bleibt auf dem Gerät und geht nur an den eingetragenen Pool.

Ist ein Miner im Netz nicht erreichbar, etwa aus einem Gäste-WLAN oder über mobile Daten, zeigt seine Zeile die Werte des Pools mit dem Hinweis "laut Pool". Antwortet er wieder, gelten wieder seine eigenen Werte. Die Android-Widgets machen es genauso und lesen jetzt auch mehrere Adressen richtig.

Das APK installiert sich über 0.2.15 und steht auch im F-Droid-Repo von OrangeDeck, Adresse oben im Abschnitt Android. Bitte vor dem Installieren Prüfsumme und Signatur prüfen.
