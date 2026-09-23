#!/usr/bin/env bash
# Baut das DMS-Plugin als eigenstaendiges Verzeichnis -- so, wie DMS es
# installiert: ein Ordner unter ~/.config/DankMaterialShell/plugins/, kopiert,
# ohne Symlinks und ohne Repo dahinter.
#
# **Warum ueberhaupt.** Im Arbeitsbetrieb verteilt `tools/install-links.sh` die
# geteilten QML-Dateien per Symlink ins Plugin-Verzeichnis; das Repo ist die
# Quelle der Wahrheit, und eine Aenderung ist sofort in der laufenden Shell.
# Wer das Plugin aber aus dem Verzeichnis von DMS installiert, bekommt eine
# **Kopie** -- und Symlinks ins Nichts. Das hier erzeugt genau die Kopie, aus
# denselben Dateien, nach derselben Regel.
#
#   tools/dms-plugin.sh [zielverzeichnis]      (Vorgabe: build/dms-plugin)
#
# Danach probeweise installieren, ohne install-links.sh:
#   rm -rf ~/.config/DankMaterialShell/plugins/OrangeDeck
#   cp -r build/dms-plugin ~/.config/DankMaterialShell/plugins/OrangeDeck
#
# Mit `--repo` wird daraus ein Git-Arbeitsbaum, den man nur noch pushen muss:
#
#   tools/dms-plugin.sh --repo [verzeichnis]   (Vorgabe: build/dms-plugin-repo)
#
# Er behaelt seine Geschichte ueber die Laeufe hinweg -- erzeugt wird in ein
# eigenes Verzeichnis, und nur der Inhalt wandert hinueber.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPOMODUS=0
if [ "${1:-}" = "--repo" ]; then
  REPOMODUS=1
  REPOZIEL="${2:-$R/build/dms-plugin-repo}"
  ZIEL="$R/build/dms-plugin"
else
  ZIEL="${1:-$R/build/dms-plugin}"
fi

# **Dieselbe Regel wie in install-links.sh**, und aus demselben Grund aus dem
# Verzeichnis gelesen statt aufgezaehlt: eine Liste von Hand vergisst man.
# Die Pruefstaende (`Pruefstand*.qml`) sind Werkzeug und bleiben draussen.
QMLFILES="$(cd "$R/ui/qml" && command ls -1 *.qml *.js 2>/dev/null | grep -v '^Pruefstand')"
PLUGINFILES="OrangeDeckDaemon.qml OrangeDeckDesktop.qml OrangeDeckSettings.qml OrangeDeckWidget.qml plugin.json"
# Der Bausatz traegt `mondrian.js` und `colors.js` mit -- Portierungen aus
# bitfeed. Beide Lizenztexte gehen also mit, nicht nur der eigene.
BEIFILES="LICENSE LICENSE-bitfeed"

# Ein fremdes Verzeichnis wird nicht geloescht. Ausgeraeumt wird nur, was
# erkennbar von hier stammt (es traegt eine plugin.json) oder noch leer ist.
if [ -e "$ZIEL" ]; then
  if [ -f "$ZIEL/plugin.json" ] || [ -z "$(command ls -A "$ZIEL")" ]; then
    rm -rf "$ZIEL"
  else
    echo "abgebrochen: $ZIEL ist nicht leer und sieht nicht nach einem Plugin aus" >&2
    exit 1
  fi
fi
mkdir -p "$ZIEL"

# -L: dereferenzieren. Im Repo stehen echte Dateien, aber ein Arbeitsbaum, in
# dem doch einmal ein Symlink liegt, darf kein kaputtes Plugin erzeugen.
for f in $PLUGINFILES; do cp -L "$R/shell/dms/$f" "$ZIEL/$f"; done
for f in $QMLFILES;    do cp -L "$R/ui/qml/$f"   "$ZIEL/$f"; done
for f in $BEIFILES;    do cp -L "$R/$f"          "$ZIEL/$f"; done
# **Kein `[ -f ... ] && cp`**: unter `set -e` beendet eine fehlschlagende
# Pruefung das Skript, und dann faellt die ganze Kontrolle unten aus. Solange
# es noch kein Bild gibt, ist das Verzeichnis `assets/` genau so ein Fall.
if [ -f "$R/shell/dms/README.md" ]; then
  cp -L "$R/shell/dms/README.md" "$ZIEL/README.md"
fi
# Das Bild fuer das Verzeichnis liegt unter `assets/` -- der Eintrag im
# Registry zeigt mit einer Roh-URL genau dorthin.
if [ -d "$R/shell/dms/assets" ]; then
  cp -rL "$R/shell/dms/assets" "$ZIEL/assets"
fi

# --- Nachsehen, ob das Ergebnis allein steht --------------------------------
fehlt=0

# 1. Kein Symlink. Der haeufigste Weg, wie aus einer Kopie doch wieder ein
#    Verweis ins Repo wird.
if find "$ZIEL" -type l | grep -q .; then
  echo "Symlink im Ergebnis:" >&2
  find "$ZIEL" -type l >&2
  fehlt=1
fi

# 2. Jedes `import "...js"` muss im Verzeichnis liegen. Eine QML-Datei, die
#    eine fehlende .js importiert, laedt nicht -- und DMS zeigt dann eine
#    leere Kachel statt eines Fehlers.
for f in "$ZIEL"/*.qml; do
  while read -r js; do
    [ -n "$js" ] || continue
    [ -e "$ZIEL/$js" ] || { echo "fehlt: $js (aus $(basename "$f"))" >&2; fehlt=1; }
  done < <(grep -oE '^import "[^"]+\.js"' "$f" | sed 's/^import "//; s/"$//')
done

# 3. Die Bestandteile aus plugin.json muessen da sein.
while read -r c; do
  [ -e "$ZIEL/$c" ] || { echo "fehlt: $c (in plugin.json genannt)" >&2; fehlt=1; }
done < <(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
for p in list(d.get("components", {}).values()) + [d.get("settings")]:
    if p:
        print(p.lstrip("./"))
' "$ZIEL/plugin.json")

[ "$fehlt" = "0" ] || exit 1

n=$(find "$ZIEL" -type f | wc -l)
echo "$ZIEL: $n Dateien, $(du -sh "$ZIEL" | cut -f1), keine Symlinks"

[ "$REPOMODUS" = "1" ] || exit 0

# --- Dasselbe noch einmal als Git-Arbeitsbaum -------------------------------
# Derselbe Vorbehalt wie oben: ein fremdes Verzeichnis wird nicht angefasst.
if [ -e "$REPOZIEL" ] && [ ! -d "$REPOZIEL/.git" ] && [ -n "$(command ls -A "$REPOZIEL")" ]; then
  echo "abgebrochen: $REPOZIEL ist nicht leer und kein Git-Arbeitsbaum" >&2
  exit 1
fi
mkdir -p "$REPOZIEL"
[ -d "$REPOZIEL/.git" ] || git -C "$REPOZIEL" init -q -b main

# Alles ausser .git heraus, dann den frischen Stand hinein: so verschwinden
# geloeschte Dateien wirklich, statt als Leiche liegen zu bleiben.
find "$REPOZIEL" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$ZIEL"/. "$REPOZIEL"/

# **Die Identitaet des Hauptrepos, nicht die globale.** Ein frischer Klon
# nimmt sonst den Klarnamen aus ~/.gitconfig (19.09.2026, fdroid-repo.sh).
git -C "$REPOZIEL" config user.name  "$(git -C "$R" config user.name)"
git -C "$REPOZIEL" config user.email "$(git -C "$R" config user.email)"

fassung=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$REPOZIEL/plugin.json")
quelle=$(git -C "$R" rev-parse --short HEAD)
git -C "$REPOZIEL" add -A
if git -C "$REPOZIEL" diff --cached --quiet; then
  echo "$REPOZIEL: unveraendert"
else
  git -C "$REPOZIEL" commit -q -m "OrangeDeck $fassung for DankMaterialShell

Built from orangedeck@$quelle with tools/dms-plugin.sh."
  echo "$REPOZIEL: committet ($(git -C "$REPOZIEL" rev-parse --short HEAD))"
fi

echo
echo "Zum Veroeffentlichen (das Repo legt der Anwender auf GitHub an):"
echo "  git -C $REPOZIEL remote add origin git@github.com:orangedeck-dev/dms-plugin.git"
echo "  git -C $REPOZIEL push -u origin main"
echo "  git -C $REPOZIEL tag v$fassung && git -C $REPOZIEL push origin v$fassung"
