#!/usr/bin/env bash
# Ein zweites DankMaterialShell, geschachtelt und mit eigenem HOME -- der
# Probestand fuer das Plugin.
#
# **Wozu.** Wer das Plugin aus dem Verzeichnis von DMS installiert, hat einen
# kopierten Ordner und sonst nichts: kein Repo, keine Unit, kein orangedeck im
# Pfad, keine gespeicherten Einstellungen, das Standard-Thema. Genau diese
# Lage laesst sich in der eigenen Sitzung nicht herstellen, und sie ist die
# einzige, in der sich "laeuft allein" beweisen laesst. Nebenbei ist es der
# Ort fuer die Bilder: Standard-Thema, leere Leiste, keine eigenen Daten.
#
#   tools/dms-probe.sh neu          Plugin erzeugen und frisches HOME anlegen
#   tools/dms-probe.sh start        Sitzung starten (Fenster auf dem Schirm)
#   tools/dms-probe.sh befehl ...   einen Befehl darin ausfuehren
#   tools/dms-probe.sh popout       Popout auf- oder zuklappen
#   tools/dms-probe.sh bild <datei> Bild der Sitzung
#   tools/dms-probe.sh ende         Sitzung beenden
#
# Ein Lauf von Null:
#
#   tools/dms-probe.sh neu && tools/dms-probe.sh start
#   tools/dms-probe.sh popout && tools/dms-probe.sh bild /tmp/probe.png
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PHOME="$HOME/.local/share/orangedeck/dms-probe"
# **Kurz muss er sein.** Unter dem Pfad eines Arbeitsverzeichnisses scheiterte
# niri an "path must be shorter than SUN_LEN": ein Unix-Sockel darf gut
# hundert Zeichen lang sein, und darin stecken Laufzeitverzeichnis und
# Sockelname. Ein eigener ist noetig, damit Dienst-Sockel und Zustandsdatei
# nicht die des Wirts sind.
PRUN="/run/user/$(id -u)/odprobe"
PROT="$PHOME/sitzung.log"

wirtssockel() {
    # Der Compositor des Wirts, als **absoluter Pfad**: nur so findet das
    # geschachtelte niri ihn, obwohl sein XDG_RUNTIME_DIR ein anderes ist.
    local d="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    echo "$d/${WAYLAND_DISPLAY:-wayland-1}"
}

umgebung() {
    export HOME="$PHOME"
    export XDG_RUNTIME_DIR="$PRUN"
    export WAYLAND_DISPLAY=wayland-1
    unset DISPLAY QT_QPA_PLATFORM
    # **Den Sockel der Probe, nicht den geerbten des Wirts.** Steht NIRI_SOCKET
    # in der Umgebung, redet `niri msg` sonst mit der Sitzung des Anwenders --
    # am 20.09.2026 genau darauf hereingefallen, die Fensterliste war seine.
    local s
    s="$(command ls "$PRUN"/niri.wayland-1.*.sock 2>/dev/null | head -1 || true)"
    [ -n "$s" ] && export NIRI_SOCKET="$s" || unset NIRI_SOCKET
}

befehl="${1:-}"
case "$befehl" in

neu)
    "$R/tools/dms-plugin.sh" >/dev/null
    rm -rf "$PHOME"
    mkdir -p "$PHOME/.config/DankMaterialShell/plugins" "$PHOME/.config/niri"
    cp -r "$R/build/dms-plugin" "$PHOME/.config/DankMaterialShell/plugins/OrangeDeck"

    # Eingeschaltet, so wie es ein Nutzer in den Einstellungen anklickt.
    # Sprache Englisch: dafuer ist der Probestand da (Bilder, Verzeichnis).
    printf '%s\n' '{"orangedeck":{"enabled":true,"lang":"en","currency":"usd"}}' \
        > "$PHOME/.config/DankMaterialShell/plugin_settings.json"

    # Sichtbar machen: Pille in der Leiste, Kachel im Kontrollzentrum, eine
    # Instanz auf dem Desktop. Ohne diese Eintraege laedt das Plugin zwar,
    # zeigt sich aber nirgends.
    cat > "$PHOME/.config/DankMaterialShell/settings.json" <<'JSON'
{
  "barConfigs": [
    {
      "id": "default", "name": "Main Bar", "enabled": true, "position": 0,
      "screenPreferences": ["all"], "showOnLastDisplay": true,
      "leftWidgets": ["launcherButton", "focusedWindow"],
      "centerWidgets": ["clock"],
      "rightWidgets": [{"id": "orangedeck", "enabled": true}, "controlCenterButton"]
    }
  ],
  "controlCenterWidgets": [{"id": "plugin_orangedeck", "enabled": true, "width": 50}],
  "desktopWidgetInstances": [
    {"id": "orangedeck-1", "widgetType": "orangedeck", "enabled": true,
     "config": {"displayPreferences": ["all"], "widgetView": "feed", "frosted": true}}
  ]
}
JSON
    # Sonst steht der Willkommensassistent im Bild -- und nach ihm das
    # "What's New" der Fassung, das ohne diese Marken bei jedem frischen HOME
    # aufgeht und ein Drittel des Bildes belegt.
    touch "$PHOME/.config/DankMaterialShell/.firstlaunch"
    for v in 1.4 1.5 1.6 1.7 1.8; do
        touch "$PHOME/.config/DankMaterialShell/.changelog-$v"
    done

    cat > "$PHOME/.config/niri/config.kdl" <<'KDL'
hotkey-overlay {
    skip-at-startup
}

binds {
    Mod+Shift+Q { quit skip-confirmation=true; }
}
KDL
    echo "Probestand angelegt: $PHOME"
    ;;

start)
    [ -d "$PHOME/.config/DankMaterialShell/plugins/OrangeDeck" ] \
        || { echo "erst: tools/dms-probe.sh neu" >&2; exit 1; }
    ws="$(wirtssockel)"
    [ -S "$ws" ] || { echo "kein Wayland-Sockel des Wirts: $ws" >&2; exit 1; }
    mkdir -p "$PRUN"; chmod 700 "$PRUN"
    (
        export HOME="$PHOME" XDG_RUNTIME_DIR="$PRUN" WAYLAND_DISPLAY="$ws"
        unset DISPLAY QT_QPA_PLATFORM DBUS_SESSION_BUS_ADDRESS NIRI_SOCKET
        # Eigener Sitzungsbus: sonst streiten sich zwei DMS um
        # org.freedesktop.Notifications.
        setsid dbus-run-session -- niri -- dms run >"$PROT" 2>&1 &
        # **Die Prozessgruppe merken, nicht das Muster.** `pkill -f` auf
        # "dbus-run-session -- niri -- dms run" traf am 20.09.2026 nichts: der
        # Elternprozess war da schon weg, das geschachtelte niri lief unter
        # seiner eigenen Befehlszeile weiter. `setsid` macht den Start zum
        # Gruppenfuehrer, und die Gruppe faellt als Ganzes.
        echo $! > "$PHOME/sitzung.pid"
    )
    for _ in $(seq 40); do
        [ -S "$PRUN/wayland-1" ] && break
        sleep 0.5
    done
    sleep 8
    echo "Sitzung laeuft, Protokoll: $PROT"
    ;;

befehl)
    shift
    umgebung
    exec "$@"
    ;;

popout)
    umgebung
    exec dms ipc call widget toggle orangedeck
    ;;

bild)
    ziel="${2:?Dateiname fehlt}"
    umgebung
    grim "$ziel"
    echo "$ziel"
    ;;

ende)
    # Nur die Prozesse der Probe: sie haengen alle unter dem geschachtelten
    # niri, das auf den eigenen Sockel hoert.
    #
    # **Das Laufzeitverzeichnis bleibt stehen.** Darin haengen Einhaengungen
    # der Sitzung (gvfs, das Dokumenten-Portal, der schreibgeschuetzte
    # Shell-Ordner von DMS); ein `rm -rf` darueber erzeugt nur eine Wand aus
    # "Gerät oder Ressource belegt" und raeumt trotzdem nichts. Beim naechsten
    # `start` wird es wiederverwendet, beim Abmelden ist es ohnehin weg.
    if [ -f "$PHOME/sitzung.pid" ]; then
        kill -TERM -"$(cat "$PHOME/sitzung.pid")" 2>/dev/null || true
        rm -f "$PHOME/sitzung.pid"
    fi
    # Wer den Probestand von Hand gestartet hat, hat keine Datei; dann bleibt
    # nur die Suche. **Und die fragt nicht das Muster, sondern die Umgebung
    # des Prozesses**: nur wer dieses Laufzeitverzeichnis traegt, gehoert zur
    # Probe. Ein blosses `pkill -f "niri -- dms run"` traf am 20.09.2026 auch
    # die Huelle, aus der es aufgerufen wurde, und beendete sie mit.
    for pid in $(pgrep -f -- "niri" 2>/dev/null || true); do
        [ "$pid" = "$$" ] && continue
        grep -qz "XDG_RUNTIME_DIR=$PRUN" "/proc/$pid/environ" 2>/dev/null || continue
        kill -TERM "$pid" 2>/dev/null || true
    done
    sleep 1
    rm -f "$PRUN/wayland-1" "$PRUN/wayland-1.lock" "$PRUN"/niri.wayland-1.*.sock 2>/dev/null || true
    echo "Probestand beendet."
    ;;

*)
    sed -n '3,30p' "${BASH_SOURCE[0]}"
    exit 1
    ;;
esac
