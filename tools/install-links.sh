#!/usr/bin/env bash
# Verlinkt das laufende System gegen dieses Repo.
# Das Repo ist die Quelle der Wahrheit; alles unter ~/.local und ~/.config
# zeigt nur noch hierher. Mehrfach aufrufbar.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Aus dem Verzeichnis gelesen, nicht aufgezaehlt -- siehe Kommentar in
# daemon/orangedeck-dashtab: eine fest verdrahtete Liste vergisst man.
#
# Ausgenommen sind die Pruefstaende (`Pruefstand*.qml`): sie sind Werkzeug,
# kein Bestandteil. Sie zeichnen ein einzelnes Bauteil zum Ansehen und haben
# in Shell, Dashboard und Plugin nichts verloren.
QMLFILES="$(cd "$R/ui/qml" && command ls -1 *.qml *.js 2>/dev/null | grep -v '^Pruefstand')"

# --check: nachsehen, ob im System etwas fehlt -- ohne etwas zu aendern.
# **Der Grund steht in der DOKUMENTATION**: die Shell liest per Symlink direkt
# ins Repo. Eine neue geteilte QML-Datei macht das laufende Dashboard in dem
# Moment kaputt, in dem eine andere Datei auf sie verweist -- nicht erst beim
# naechsten Neustart. Zwischen "angelegt" und "verteilt" darf also nichts
# liegen, und das hier sagt, ob etwas dazwischenliegt.
if [ "${1:-}" = "--check" ]; then
  fehlt=0
  for f in $QMLFILES; do
    for d in "$HOME/.local/share/orangedeck/qml" \
             "$HOME/.config/DankMaterialShell/plugins/OrangeDeck" \
             "$HOME/.config/quickshell/OrangeDeckApp" \
             "$HOME/.config/quickshell/dms-custom/Modules/DankDash"; do
      [ -d "$d" ] || continue
      [ -e "$d/$f" ] || { echo "fehlt: $d/$f"; fehlt=1; }
    done
    case "$f" in
      *.qml)
        grep -q "ui/qml/$f\b" "$R/CMakeLists.txt" \
          || { echo "fehlt in CMakeLists.txt: $f"; fehlt=1; } ;;
    esac
  done
  if [ "$fehlt" = "0" ]; then
    echo "Alles verteilt."
  else
    echo
    echo "Beheben mit:  tools/install-links.sh && python3 daemon/orangedeck-dashtab"
    echo "Danach ist ein  systemctl --user restart dms  noetig:"
    echo "eine **neu hinzugekommene** Datei sieht die laufende Shell nicht,"
    echo "auch nicht nach  dms ipc call plugin-scan reload orangedeck."
  fi
  exit "$fehlt"
fi

link() {  # link <ziel-im-repo> <ort-im-system>
  local src="$1" dst="$2"
  [ -e "$src" ] || { echo "fehlt im Repo: $src" >&2; return 1; }
  mkdir -p "$(dirname "$dst")"
  [ -L "$dst" ] && rm -f "$dst"
  [ -e "$dst" ] && rm -f "$dst"
  ln -s "$src" "$dst"
}

# QML-Grafik: der eine Ort, auf den Plugin und Quickshell-App zeigen
for f in $QMLFILES; do
  link "$R/ui/qml/$f" "$HOME/.local/share/orangedeck/qml/$f"
done

# Daemon und Werkzeuge
for f in orangedeck orangedeck-window orangedeck-dashtab; do
  chmod +x "$R/daemon/$f"
  link "$R/daemon/$f" "$HOME/.local/bin/$f"
done

# DMS-Plugin
P="$HOME/.config/DankMaterialShell/plugins/OrangeDeck"
for f in OrangeDeckDaemon.qml OrangeDeckDesktop.qml OrangeDeckSettings.qml OrangeDeckWidget.qml plugin.json README.md; do
  link "$R/shell/dms/$f" "$P/$f"
done
for f in DOKUMENTATION.md STAND.md ZIELBILD.md; do
  link "$R/docs/$f" "$P/$f"
done
# **Das Journal als Ganzes**, nicht Datei fuer Datei: hier kommt am Ende
# jedes Tages eine dazu, und eine Liste, die man von Hand nachfuehren muss,
# ist am zweiten Tag unvollstaendig.
link "$R/docs/journal" "$P/journal"
# die QML-Dateien des Plugins zeigen weiter auf ~/.local/share/orangedeck/qml
for f in $QMLFILES; do
  link "$HOME/.local/share/orangedeck/qml/$f" "$P/$f"
done

# Eigenes Quickshell-Fenster
Q="$HOME/.config/quickshell/OrangeDeckApp"
link "$R/shell/quickshell/shell.qml" "$Q/shell.qml"
for f in $QMLFILES; do
  link "$HOME/.local/share/orangedeck/qml/$f" "$Q/$f"
done

# --- Benutzerdienst ---------------------------------------------------------
# Ohne ihn laeuft orangedeck als loser Prozess und stirbt mit der Sitzung.
UNIT="$HOME/.config/systemd/user/orangedeck.service"
mkdir -p "$(dirname "$UNIT")"
[ -L "$UNIT" ] && rm -f "$UNIT"
ln -sf "$R/packaging/systemd/orangedeck.service" "$UNIT"
systemctl --user daemon-reload
systemctl --user enable orangedeck.service >/dev/null 2>&1 && echo "Dienst orangedeck eingerichtet"

echo "Verlinkt gegen $R"

# --- Was NICHT verlinkt ist -------------------------------------------------
# Die Verweise oben halten Shell und Dashboard von selbst aktuell. Zwei Wege
# nicht: die eigenstaendige Anwendung wird gebaut, und das Flatpak traegt eine
# **Kopie** in sich. Am 02.09.2026 genau daran vorbeigelaufen -- die Aenderungen
# waren da, das geoeffnete Flatpak zeigte sie nur nicht.
if [ -d "$R/build" ]; then
  echo "Eigenstaendige Anwendung neu bauen:  cmake --build $R/build"
fi
if flatpak info --user dev.orangedeck.OrangeDeck >/dev/null 2>&1; then
  echo "Flatpak ist installiert und jetzt VERALTET. Neu bauen mit:"
  echo "  flatpak-builder --user --install --force-clean \\"
  echo "      $R/build-flatpak $R/packaging/flatpak/dev.orangedeck.OrangeDeck.dev.yml"
fi
