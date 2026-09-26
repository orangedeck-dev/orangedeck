# Widgets auf dem Desktop -- ohne DMS

In DankMaterialShell legt man die Ansichten ueber die Einstellungen des
Plugins auf den Desktop. Ueberall sonst geht dasselbe mit **Layer-Shell**:

    orangedeck-app --layer <ebene> --anchor <kanten> [--width N] [--height N]
                [--margin N] [--exclusive N] [--view N] [--bare] [--id name]

**Nicht aus dem Flatpak.** Compositoren blenden privilegierte Protokolle vor
Sandkastenprogrammen aus (`wp_security_context_v1`), und Layer-Shell gehoert
dazu -- ein Programm im Sandkasten soll sich nicht ueber den ganzen Bildschirm
legen koennen. Aus dem Flatpak zeigt `--layer` deshalb nur ein gewoehnliches
Fenster. Fuer Widgets die Anwendung selbst bauen.

**Am 05.09.2026 gemessen**, nicht mehr nur hergeleitet -- gleiche Maschine,
gleicher Compositor (niri), gleiches Binary, nur der Sandkasten unterscheidet
sich:

| Lauf | `niri msg layers` | `niri msg windows` |
|---|---|---|
| aus dem Bauverzeichnis | neue Flaeche, Namensraum `orangedeck` | -- |
| aus dem installierten Flatpak | nichts | ein gewoehnliches Fenster |

**Die Fehlermeldung dabei zeigt in die falsche Richtung:**

    layershellqt: Failed to initialize layer-shell integration,
    possibly because compositor does not support the layer-shell protocol

Der Compositor unterstuetzt es sehr wohl -- er zeigt es dem Sandkasten nur
nicht. Wer der Meldung glaubt, sucht den Fehler beim Compositor und findet
dort nichts.

Das setzt `layer-shell-qt` (Qt6) beim Bauen voraus. Fehlt es, faellt nur
`--layer` weg -- `cmake` sagt das beim Einrichten. Getragen wird es von allen
wlroots-nahen Compositoren: **niri, sway, Hyprland, river, labwc, Wayfire**.
Auf X11 gibt es keine Layer-Shell; dort bleibt das gewoehnliche Fenster.

| Schalter | Bedeutung |
|---|---|
| `--layer` | `background`, `bottom` (Vorgabe), `top`, `overlay` |
| `--anchor` | Kanten mit Komma: `top,bottom,left,right`. Zwei gegenueberliegende dehnen die Flaeche |
| `--width` / `--height` | gewuenschte Groesse; an gedehnten Kanten entscheidet der Compositor |
| `--margin` | eine Zahl, oder `oben,rechts,unten,links` |
| `--exclusive` | Platz, den andere Fenster freilassen. `0` keiner, `-1` sich ueberlappen lassen |
| `--view` | `0` Feed, `1` Uhr, `2` Miner, `3` Explorer, `5` Einstellungen, `6` Markt (`4` war bis 0.2.14 die Wallet und zeigt jetzt die erste Ansicht) |
| `--bare` | ohne Reiter, Kopf- und Fusszeile -- die Ansicht allein |
| `--id` | eigener Einstellungsspeicher (`~/.config/orangedeck/orangedeck-<name>.conf`) |

**`--id` ist der Punkt, an dem mehrere Widgets nebeneinander gehen.** Ohne ihn
teilen sich alle dieselbe Datei und schreiben sich gegenseitig um -- mit ihm
behaelt jedes seine Ansicht, seine Sprache, seine Waehrung.

## Beispiele

Uhr als Kachel rechts oben, ohne Reiter:

    orangedeck-app --layer top --anchor top,right --width 300 --height 220 \
                --margin 24 --view 1 --bare --id uhr

Der Feed als Leiste ueber die ganze Breite, unter den Fenstern, mit
freigehaltenem Platz:

    orangedeck-app --layer bottom --anchor bottom,left,right --height 110 \
                --exclusive 110 --view 0 --bare --id leiste

Der Miner links oben:

    orangedeck-app --layer top --anchor top,left --width 300 --height 300 \
                --margin 24 --view 2 --bare --id miner

## Beim Anmelden mitstarten

**niri** (`~/.config/niri/config.kdl`):

    spawn-at-startup "orangedeck-app" "--layer" "top" "--anchor" "top,right" \
        "--width" "300" "--height" "220" "--margin" "24" \
        "--view" "1" "--bare" "--id" "uhr"

**Hyprland** (`~/.config/hypr/hyprland.conf`):

    exec-once = orangedeck-app --layer top --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id uhr

**sway** (`~/.config/sway/config`):

    exec orangedeck-app --layer top --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id uhr

**labwc** (`~/.config/labwc/autostart`):

    orangedeck-app --layer top --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id uhr &

Ueberall gilt: der Daemon muss laufen. `tools/install-links.sh` richtet ihn als
Benutzerdienst ein, danach genuegt

    systemctl --user enable --now orangedeck.service

## Unter Windows

Dieselbe Befehlszeile, ohne Layer-Shell. `--layer` macht das Fenster dort
**randlos, nimmt es aus der Taskleiste** und haelt es je nach Ebene unter
(`background`, `bottom`) oder ueber (`top`, `overlay`) allen anderen Fenstern.
`--anchor`, `--margin`, `--width` und `--height` legen es in den Arbeitsbereich
des Bildschirms, also neben die Taskleiste, nicht darunter.

    orangedeck-app.exe --layer bottom --anchor top,right --width 300 --height 220 --margin 24 --view 1 --bare --id uhr

Unterschiede zu Wayland:

| | Wayland (Layer-Shell) | Windows |
|---|---|---|
| `--exclusive` | haelt Platz frei | wirkt nicht (Warnung) |
| `--keyboard` | Tasten nur auf Wunsch | Tasten immer -- **anklicken, dann Q schliesst** |
| `--id` | `~/.config/orangedeck/orangedeck-<name>.conf` | Registry: `HKCU\Software\orangedeck\orangedeck-<name>` |
| Daten | vom Dienst | Direktbezug |

**Beim Anmelden mitstarten:** `Win+R`, `shell:startup`, dort eine Verknuepfung
auf `orangedeck-app.exe` anlegen und die Schalter hinten an das Ziel haengen.

**Gemessen am 12.09.2026** in einer frischen Windows-11-VM (25H2), mit
einem Widget auf `bottom` rechts oben und einem auf `top` links unten.
Fensterdaten ueber user32, nicht vom Bild geraten:

| Pruefung | Ergebnis |
|---|---|
| ohne Rahmen, an der gewuenschten Ecke, 24 px Rand | ja |
| nicht in der Taskleiste (`WS_EX_TOOLWINDOW`) | ja, bei beiden |
| maximiertes Fenster darueber | `bottom` verschwindet dahinter, `top` bleibt davor |
| `Win+D` | **beide bleiben stehen** |

**`Win+D` brauchte zwei Anlaeufe.** Windows 11 holt beim "Desktop anzeigen"
die Desktop-Ebene nach vorn; ein Widget auf `bottom` lag dahinter -- nicht
minimiert, nur verdeckt. Deshalb bekommt es `Progman` als Besitzer, und das
erst **nach** dem Zeigen: vorher gesetzt, stand der Besitzer danach wieder
leer.

Nicht geprueft: das Schliessen mit **Q** (der Zeiger laesst sich in der VM
nicht verlaesslich setzen) und Bildschirme mit mehr als 100 % Skalierung.

## Leisten statt Widgets

Wer nur eine Zahl in der vorhandenen Leiste will, braucht das alles nicht:
`packaging/bars/` hat fertige Bausteine fuer waybar und polybar, die den
Daemon direkt abfragen.
