#!/usr/bin/env bash
# Das eigene F-Droid-Repo mit einem signierten Release fuellen.
#
#     tools/fdroid-repo.sh 0.2.12
#
# **Was es ist.** Ein F-Droid-Repo ohne Bauserver: es verteilt genau das APK
# aus dem GitHub-Release, signiert mit dem Schluessel des Anwenders. F-Droid
# selbst baut nicht; das Hauptrepo von F-Droid kommt fuer uns nicht in Frage,
# solange Qt fuer Android dort aus dem Quelltext gebaut werden muesste
# (Stand 19.09.2026, docs/STAND.md).
#
# **Wo was liegt.**
#   ~/.local/share/orangedeck/fdroid/         Arbeitsverzeichnis von `fdroid`:
#       config.yml, keystore.p12              GEHEIM -- der Schluessel, der das
#                                             Inhaltsverzeichnis signiert. Nie
#                                             in ein Git-Repo. Mit sichern.
#       metadata -> packaging/fdroid/metadata Texte und Symbol, versioniert
#       repo/                                 das, was veroeffentlicht wird
#   ~/.local/share/orangedeck/fdroid-pages/   Klon von orangedeck-dev/fdroid
#
# **Warum ein eigenes Repo mit nur einem Commit.** Jedes APK wiegt rund 23 MB.
# Im Hauptrepo laege jedes davon fuer immer in der Geschichte. Hier wird bei
# jedem Lauf ein einziger neuer Commit ohne Vorgaenger gebaut; der Push mit
# --force ersetzt den alten. Das Repo bleibt so gross wie zwei APKs.
#
# **Nachsehen, nicht glauben**, wie in tools/apk.sh: das APK muss mit dem
# bekannten Schluessel signiert sein und unter 25 MiB bleiben, sonst bricht
# das Skript ab, bevor irgendetwas veroeffentlicht wird.
set -euo pipefail

V="${1:?Fassung angeben, z. B. 0.2.12}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARBEIT="${ORANGEDECK_FDROID_DIR:-$HOME/.local/share/orangedeck/fdroid}"
SEITE="${ORANGEDECK_FDROID_PAGES:-$HOME/.local/share/orangedeck/fdroid-pages}"
APK="${ORANGEDECK_APK_DIR:-$HOME/.local/share/orangedeck/auslieferung}/orangedeck-$V-arm64-v8a.apk"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/sdk}"

# Der Fingerabdruck des Zertifikats, mit dem jedes OrangeDeck-APK seit 0.2.8
# signiert ist. Ein anderer hiesse: falsche Datei oder falscher Schluessel.
ZERT=b3cc8379ce27934d30b548b3f5a1d5516ee11114ffd54ef17e57d238120292e0
BEHALTEN=2

command -v fdroid >/dev/null || { echo "fehlt: fdroid (pipx install fdroidserver)"; exit 1; }
[ -f "$ARBEIT/config.yml" ] || { echo "fehlt: $ARBEIT/config.yml"; exit 1; }
[ -f "$APK" ] || { echo "fehlt: $APK -- erst bauen und signieren"; exit 1; }

signer=$(ls -d "$ANDROID_HOME"/build-tools/*/ | sort -V | tail -1)apksigner
# `|| true`: ein unsigniertes APK laesst apksigner scheitern, und set -e
# wuerde dann ohne diese Meldung abbrechen.
zert=$("$signer" verify --print-certs "$APK" 2>/dev/null \
       | sed -n 's/.*certificate SHA-256 digest: //p' | head -1) || true
[ "$zert" = "$ZERT" ] || {
    echo "APK nicht mit dem OrangeDeck-Schluessel signiert (${zert:-unsigniert})"; exit 1; }
# **Und genau die Datei, die ausgeliefert wird.** Am 19.09.2026 stand im
# Repo zwanzig Minuten lang ein verworfener Bau derselben Fassung: gleicher
# Name, gleicher Schluessel, andere Datei -- das Skript lief vor der letzten
# Runde und danach nicht mehr. Massstab ist die gueltige (nicht
# auskommentierte) Zeile in PRUEFSUMMEN.txt.
soll=$(grep -v '^#' "$(dirname "$APK")/PRUEFSUMMEN.txt" 2>/dev/null \
       | awk -v n="$(basename "$APK")" '$2 == n {s=$1} END {print s}')
ist=$(sha256sum "$APK" | cut -d' ' -f1)
[ -n "$soll" ] && [ "$soll" = "$ist" ] || {
    echo "APK passt nicht zu PRUEFSUMMEN.txt (soll ${soll:-fehlt}, ist $ist)"; exit 1; }
groesse=$(stat -c %s "$APK")
[ "$groesse" -le $((25 * 1024 * 1024)) ] || {
    echo "APK ist $((groesse / 1048576)) MiB gross, erlaubt sind 25"; exit 1; }

ln -sfn "$REPO/packaging/fdroid/metadata" "$ARBEIT/metadata"
cp "$APK" "$ARBEIT/repo/"
# Nur die neuesten Fassungen behalten; aeltere fallen aus dem Verzeichnis.
ls -t "$ARBEIT"/repo/orangedeck-*.apk | tail -n +$((BEHALTEN + 1)) | xargs -r rm -f

( cd "$ARBEIT" && fdroid update )

# Die Seite: nur repo/, dazu .nojekyll, damit GitHub Pages die Dateien nicht
# durch Jekyll schickt (das liesse Verzeichnisse mit Unterstrich weg).
[ -d "$SEITE/.git" ] || git clone -q https://github.com/orangedeck-dev/fdroid.git "$SEITE"
git -C "$SEITE" checkout -q --orphan neu
git -C "$SEITE" rm -rqf --cached . 2>/dev/null || true
find "$SEITE" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$ARBEIT/repo" "$SEITE/repo"
touch "$SEITE/.nojekyll"
# Die eigene Adresse statt orangedeck-dev.github.io: die tragen Nutzer in
# F-Droid ein, und sie soll einen Umzug des Kontos oder weg von GitHub
# ueberstehen. Braucht bei Cloudflare einen CNAME fdroid -> orangedeck-dev.github.io.
echo fdroid.orangedeck.dev > "$SEITE/CNAME"
cp "$REPO/packaging/fdroid/SEITE.md" "$SEITE/README.md"
git -C "$SEITE" add -A
# **Mit der Identitaet des Hauptrepos**, nicht der globalen. Der frische Klon
# haette sonst die globale Einstellung genommen, und am 19.09.2026 stand
# darin ein Klarname, der in keinem oeffentlichen Commit stehen soll.
git -C "$SEITE" -c user.name="$(git -C "$REPO" config user.name)" \
    -c user.email="$(git -C "$REPO" config user.email)" \
    commit -qm "OrangeDeck $V"
git -C "$SEITE" branch -M neu main

echo
echo "  Fassung $V im Repo, $(ls "$SEITE"/repo/*.apk | wc -l) APK(s), Schluessel geprueft."
echo "  Veroeffentlichen (ersetzt den alten Stand):"
echo "    git -C $SEITE push --force origin main"
