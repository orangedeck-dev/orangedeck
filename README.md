# OrangeDeck

Ein Bitcoin-Dashboard fuer Linux und Android.

Angefangen hat es als Live-Ansicht des Mempools nach dem Vorbild von
[bitfeed.live](https://bitfeed.live) -- Block in der Mitte, Mempool als Halde
unten, neue Transaktionen fallen von oben hinein. Dazugekommen sind sechs
weitere Ansichten:

    Feed         der Mempool als Halde, Kacheln nach Alter, Gebuehr oder Art
    Uhr          Blockhoehe gross, Kennzahlen, Kursverlauf bis 2013 zurueck
    Miner        AxeOS und cgminer im Heimnetz, Hashrate und Freigaben
    Explorer     Suche, Transaktionsfluss, Bloecke, geplante Bloecke
    Markt        Kerzen, laufendes Band, Long/Short, Liquidationen, Heatmap
    Einstellungen

Jede Ansicht laesst sich einzeln abschalten, und jede laeuft in fuenf
Umgebungen: als eigenstaendiges Fenster, als Quickshell-Fenster, als
Dashboard-Tab, im Popout der Leistenpille und als Desktop-Widget. Verdrahtet
sind sie **einmal**, in `ui/qml/FeedTabs.qml`.

Ziel bleibt eine portable Qt-Anwendung fuer jeden Linux-Desktop plus eine
Android-Fassung, die ein Tablet zur Wanduhr macht — siehe `docs/ZIELBILD.md`.

Die Daten kommen von [mempool.space](https://mempool.space) (kein eigener Node
noetig), von einer anderen oeffentlichen Mempool-Instanz oder vom eigenen Node,
einzutragen unter Einstellungen > Allgemein > Mempool-Instanz, und, allein fuer
den Markt-Reiter, von den oeffentlichen
Schnittstellen von Binance, Bybit und OKX -- ueber den Dienst oder, wo es
keinen gibt, direkt aus der Anwendung. Ohne Schluessel, ohne Anmeldung.

## Wo es laeuft, und wie gut geprueft

Zwischen "baut" und "laeuft" liegt mehr, als man denkt -- dem Android-Paket
fehlte monatelang unbemerkt TLS. Deshalb hier getrennt:

| System | Baut | Gelaufen |
|---|---|---|
| Linux (Arch, Qt 6.11) | ja | taeglich, alle fuenf Wirte |
| Linux (Flatpak) | ja | **ja**, Ubuntu 24.04 GNOME und Fedora 44 KDE, frisch in einer VM (16.09.2026, 0.2.10) |
| Android | ja, signiert | **ja**, Galaxy A55 mit Android 16 (16.09.2026, 0.2.10, ohne Wallet); Emulator 9, 11, 14 |
| Windows | ja, unsigniert | **ja**, Windows 11 25H2 in einer VM (12.09.2026): Feed und Markt ueber den Dienst, Widgets; Feed, Mining und Markt ohne Dienst (13.09.2026); ohne Wallet, Widgets mit Win+D (16.09.2026, 0.2.10). Ausgeliefert ab 0.2.9 |
| macOS | ja, unsigniert | **noch von niemandem** |

Windows und macOS entstehen bei jedem Push in der Baustrecke
(`.github/workflows/build.yml`) und sind **ohne Signatur** -- SmartScreen und
Gatekeeper werden warnen. Ein Zertifikat kostet 200-400 EUR im Jahr, das
Apple-Programm 99; das Projekt soll nichts kosten. Flathub signiert selbst,
dort stellt sich die Frage nicht.

## Aufbau

    daemon/           orangedeck (Python, stdlib): holt die Daten, bietet sie
                      unter http://127.0.0.1:21021 an
    ui/qml/           die Grafik. Haengt nur an QtQuick -- kein Quickshell,
                      kein Qt Quick Controls (sonst laeuft es nicht ueberall)
    app/              eigenstaendige Qt-Anwendung (CMake), laeuft auf jedem
                      Linux-Desktop und ist die Grundlage fuer Android
    shell/dms/        DMS-Plugin
    shell/quickshell/ eigenes Fenster
    tools/            install-links.sh verlinkt das System gegen dieses Repo
    upstream/bitfeed/ das Original, per git subtree (MIT, siehe NOTICE.md)
    packaging/        Flatpak, Android, systemd-Dienst, Layer-Shell-Widgets

## Einrichten

    tools/install-links.sh

Setzt alle Symlinks unter `~/.local` und `~/.config`. Das Repo ist die Quelle
der Wahrheit, mehrfach aufrufbar.

## Eigenstaendige Anwendung bauen

    cmake -S app -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build build
    ./build/orangedeck-app

Braucht Qt 6.5 oder neuer (Core, Gui, Qml, Quick). Sie benutzt dieselben
QML-Dateien wie das DMS-Plugin -- `ui/qml/` wird nur zusaetzlich ins
QML-Modul gepackt, nicht kopiert.

Tasten: `c` Farbe, `s` Groesse, `i` Blockangaben, `l` Legende, `+`/`-`
Deckkraft, `F11` Vollbild, `q` beenden.

**Fehlersuche:** Qt schickt seine Meldungen auf systemd-Systemen ans Journal,
nicht auf stderr -- QML-Fehler bleiben dadurch unsichtbar. Mit
`QT_FORCE_STDERR_LOGGING=1` starten, dann erscheinen sie.

## Woher die Daten kommen

Zwei Wege, umschaltbar in den Einstellungen unter "Allgemein":

- **Eigener Dienst** (Vorgabe) -- `daemon/orangedeck` auf `127.0.0.1:21021`. Er
  haelt **eine** Verbindung fuer alle Fenster und Widgets, hoert den Markt
  rund um die Uhr mit und fragt den Miner im Heimnetz.
- **Direkt** -- die Oberflaeche redet selbst mit mempool.space oder der
  eingetragenen Instanz, ueber denselben WebSocket, den auch der Dienst benutzt. Kein Dienst noetig, kein systemd,
  keine Einrichtung. Den Miner erreicht auch der Direktbezug, sobald seine
  Adresse eingetragen ist.

Welche Mempool-Instanz beide Wege fragen, steht im Feld **Mempool-Instanz**
darunter: leer fuer mempool.space, sonst etwa `mempool.emzy.de`,
`mempool.ninja` oder der eigene Node wie `http://umbrel.local:3006`. Es gilt
auch fuer die Android-Widgets; den Dienst auf demselben Rechner stellt die
Oberflaeche mit um (`POST /config`, nur von 127.0.0.1), und er merkt sich die
Adresse in `~/.config/orangedeck/sources.json`.

Auf dem Rechner ist der Dienst die bessere Wahl, auf dem Handy gibt es ihn
nicht. **Unter Android und Windows gibt es nur den Direktbezug**: einen Dienst auf
einem anderen Rechner kann man dort seit dem 15.09.2026 nicht mehr eintragen.
Die Watch-only-Wallet gibt es seit 0.2.15 (26.09.2026) nirgends mehr; ueberall
laufen dieselben fuenf Ansichten. Auf der Befehlszeile: `orangedeck-app --source direct`. Der Direktbezug
braucht `qt6-websockets`; fehlt das Paket, bleibt der Dienst.

## Als Flatpak

    flatpak install --user flathub org.kde.Platform//6.9 org.kde.Sdk//6.9
    flatpak-builder --user --install --force-clean \
        build-flatpak packaging/flatpak/dev.orangedeck.OrangeDeck.dev.yml
    flatpak run --user dev.orangedeck.OrangeDeck

Das Paket bringt den Daemon mit und startet ihn, falls noch keiner laeuft.

## Als Widget auf dem Desktop

    orangedeck-app --layer top --anchor top,right --width 300 --height 220 \
                --margin 24 --view 1 --bare --id uhr

Jede Ansicht laesst sich einzeln als Layer-Shell-Flaeche auf den Desktop
legen -- unter niri, sway, Hyprland, river, labwc. **Unter Windows** macht
dieselbe Zeile ein randloses Fenster ohne Taskleisten-Eintrag daraus, das
auch "Desktop anzeigen" (Win+D) stehen laesst. Alle Schalter und
Startzeilen stehen in `packaging/widgets/README.md`.

## Wo weiterlesen

- `docs/ZIELBILD.md` — wohin es geht, in welcher Reihenfolge
- `docs/STAND.md` — offene Punkte, zuerst hier nachsehen
- `docs/journal/` — ein Tag je Datei, wie es dazu kam
- `docs/DOKUMENTATION.md` — Mechanik und alle Stolperfallen
- `NOTICE.md` — Herkunft und Lizenzen

## Lizenz

MIT, Copyright 2026 Satoshoe — Text in `LICENSE`.

Unter `upstream/bitfeed/` liegt bitfeed selbst, ebenfalls MIT, Copyright
mononaut (`LICENSE-bitfeed`). Zwei Dateien in `ui/qml/` sind Portierungen
daraus. Herkunft und Umfang stehen in `NOTICE.md` — bitte vor jeder
Weitergabe lesen, die MIT-Lizenz verlangt beide Urhebervermerke.
