#!/usr/bin/env bash
# Das Android-Paket aus einem beliebigen Stand bauen.
#
# **Warum es das Skript gibt.** Am 06.09.2026 wurde das APK aus `v0.2.0`
# gebaut, und der Bau scheiterte zweimal an Dingen, die nirgends standen:
#
#   1. `QT_HOST_PATH` fehlt. Ohne es meldet CMake nur "Qt6_FOUND to FALSE",
#      und der Grund steht zwoelf Zeilen weiter oben im Protokoll.
#   2. `build-openssl-android/` liegt **ausserhalb** des Repos. Ein frischer
#      Arbeitsbaum hat es nicht, und dann entsteht klaglos ein APK **ohne
#      TLS** -- auf dem Geraet vollstaendig funktionslos, weil mempool.space
#      nur https und wss spricht. Der Bau meldet keinen Fehler.
#
# Beides ist eine Umgebung, kein Wissen. Umgebungen gehoeren in eine Datei.
#
#     tools/apk.sh              aus dem Arbeitsstand bauen (in einem Worktree)
#     tools/apk.sh v0.2.0       aus einem Tag oder Commit bauen
#
# Das Ergebnis liegt unter ~/.local/share/orangedeck/auslieferung/ -- **nicht**
# im Kratzverzeichnis der Sitzung. Am 05.09.2026 lag die Pruef-VM dort und war
# am naechsten Tag weg; derselbe Fehler zweimal ist einer zu viel.
#
# Und **nicht** unter ~/.cache/: dort lag es bis zum 07.09.2026, und die
# Ausschlussliste der Sicherung beginnt mit genau dieser Zeile. Ein Paket,
# das ausgeliefert werden soll, ist kein Zwischenspeicher.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT="${ORANGEDECK_QT_ANDROID:-$HOME/Qt/6.11.2/android_arm64_v8a}"
# Host-Werkzeuge (qmlcachegen, moc, rcc) in derselben Fassung wie das
# Android-Qt. Bis zum 18.11.2026 kamen sie aus /usr; seit dem Systemupdate
# auf Qt 6.12 (12.10.) erzeugte qmlcachegen Code, den das Android-Qt 6.11.2
# nicht uebersetzt ("no member named 'AOTLookupValidation'").
# Nachinstallieren: aqt install-qt linux desktop 6.11.2 linux_gcc_64 -O ~/Qt
QT_HOST="${ORANGEDECK_QT_HOST:-$(dirname "$QT")/gcc_64}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/sdk}"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$(ls -d "$ANDROID_SDK_ROOT"/ndk/* 2>/dev/null | sort -V | tail -1)}"
ZIEL="${ORANGEDECK_APK_DIR:-$HOME/.local/share/orangedeck/auslieferung}"
STAND="${1:-}"

for p in "$QT/bin/qt-cmake" "$QT_HOST/libexec/qmlcachegen" "$ANDROID_SDK_ROOT" "$ANDROID_NDK_ROOT"; do
    [ -e "$p" ] || { echo "fehlt: $p"; exit 1; }
done
[ -e "$REPO/build-openssl-android" ] || {
    echo "fehlt: $REPO/build-openssl-android -- erst tools/openssl-android.sh"; exit 1; }

# **Auch der Arbeitsstand wird in einem frischen Worktree gebaut.** Im Repo
# liegt `build-flatpak/`, und darin legt `flatpak build-init` den Link
# `var/run -> /run` an. qmlimportscanner durchsucht den ganzen Quellordner
# (das schaltet Qt nicht ab) und folgt dem Link bis in die laufende
# DMS-Shell unter /run/user. Am 18.11.2026 kamen so QtQuick.Controls mit
# allen Stilen, Layouts, Shapes und folderlistmodel ins APK, 28 statt
# 23 MiB, je nachdem, was gerade auf dem Desktop lief. Ein Worktree hat
# kein build-flatpak. Nicht committete Aenderungen an versionierten Dateien
# nimmt `git stash create` mit; neue, unversionierte Dateien nicht.
if [ -z "$STAND" ]; then
    neu=$(git -C "$REPO" ls-files --others --exclude-standard -- app ui android CMakeLists.txt)
    [ -z "$neu" ] || { echo "unversioniert, waere nicht im Bau:"; echo "$neu"; exit 1; }
    STAND=$(git -C "$REPO" stash create)
    STAND="${STAND:-HEAD}"
    ARBEITSSTAND=1
fi

if [ -n "$STAND" ]; then
    BAUM="$(mktemp -d)/orangedeck"
    git -C "$REPO" worktree add --detach "$BAUM" "$STAND^{}" >/dev/null
    # Der Baum aus der Historie kennt OpenSSL nicht -- es liegt ausserhalb.
    ln -sfn "$REPO/build-openssl-android" "$BAUM/build-openssl-android"
    aufraeumen() { git -C "$REPO" worktree remove --force "$BAUM" 2>/dev/null || true; }
    trap aufraeumen EXIT
else
    BAUM="$REPO"
fi
echo "== Stand: $(git -C "$BAUM" log --oneline -1) =="

"$QT/bin/qt-cmake" -S "$BAUM" -B "$BAUM/build-android" \
    -DCMAKE_BUILD_TYPE=Release -DQT_ANDROID_ABIS=arm64-v8a \
    -DQT_HOST_PATH="$QT_HOST" -DQT_HOST_PATH_CMAKE_DIR="$QT_HOST/lib/cmake" \
    -DANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" -DANDROID_NDK_ROOT="$ANDROID_NDK_ROOT"
cmake --build "$BAUM/build-android" --target apk -j"$(nproc)"

APK="$BAUM/build-android/android-build/build/outputs/apk/release/android-build-release-unsigned.apk"
[ -f "$APK" ] || { echo "kein APK entstanden"; exit 1; }

# **Nachsehen, nicht glauben.** Ein APK ohne TLS sieht aus wie eines mit.
n=$(unzip -l "$APK" | grep -cE "libssl|libcrypto" || true)
[ "$n" -ge 2 ] || { echo "APK OHNE TLS ($n Bibliotheken) -- nicht ausliefern"; exit 1; }
# **Und die Groesse.** Seit dem 19.09.2026 sind die Bibliotheken gepackt
# (QT_ANDROID_LEGACY_PACKAGING in CMakeLists.txt), rund 23 statt 57 MB.
# Die Grenze von 25 MiB war fuer ein F-Droid-Repo auf Cloudflare Pages
# gedacht; es liegt inzwischen auf GitHub Pages, aber die Pruefung bleibt:
# waechst das APK darueber, ist das Packen still ausgefallen. Aeltere Staende
# (tools/apk.sh v0.2.0) sind noch ungepackt; fuer sie nur ein Hinweis.
groesse=$(stat -c %s "$APK")
if [ "$groesse" -gt $((25 * 1024 * 1024)) ]; then
    echo "APK ist $((groesse / 1048576)) MiB gross, erlaubt sind 25 -- sind die Bibliotheken gepackt?"
    [ -z "${ARBEITSSTAND:-}" ] || exit 1
fi
fassung=$(unzip -p "$APK" AndroidManifest.xml | strings -el | grep -oE "^[0-9]+\.[0-9]+\.[0-9]+$" | head -1)

mkdir -p "$ZIEL"
name="orangedeck-${fassung:-unbekannt}-arm64-v8a-unsigniert.apk"
cp "$APK" "$ZIEL/$name"
( cd "$ZIEL" && sha256sum "$name" >> PRUEFSUMMEN.txt )
echo
echo "  $ZIEL/$name"
echo "  Fassung $fassung, TLS an Bord ($n Bibliotheken)"
echo
echo "Signieren (Schluessel und Passwort kommen von dir):"
echo "  \"\$ANDROID_SDK_ROOT\"/build-tools/*/apksigner sign \\"
echo "      --ks ~/.local/share/orangedeck/signing/orangedeck.jks \\"
echo "      --out $ZIEL/orangedeck-$fassung-arm64-v8a.apk \\"
echo "      $ZIEL/$name"
