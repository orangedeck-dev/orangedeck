#!/usr/bin/env bash
# OpenSSL fuer Android aus dem Quelltext bauen.
#
# **Warum das noetig ist:** Qt liefert fuer Android kein OpenSSL mit. Ohne es
# meldet die App auf dem Geraet nur
#
#     qt.network.ssl: No functional TLS backend was found
#
# und ist damit vollstaendig funktionslos -- mempool.space spricht nur https
# und wss. Auf dem Schreibtisch faellt es nicht auf, weil dort das
# System-OpenSSL benutzt wird. Am 04.09.2026 im Emulator aufgefallen.
#
# **Warum aus dem Quelltext und nicht fertig:** Qts eigene Doku verweist auf
# vorkompilierte Bibliotheken von Dritten. Die wandern dann in eine
# veroeffentlichte App, und pruefen laesst sich so ein Paket kaum. Hier wird
# stattdessen der offizielle Quelltext geladen, die Pruefsumme gegen die
# Angabe des Projekts gehalten und mit dem NDK uebersetzt, das ohnehin da ist.
# Nichts mittragen, was man nicht nachvollziehen kann.
#
# Das Ergebnis liegt unter `build-openssl-android/<abi>/` und wird von
# `app/CMakeLists.txt` aufgegriffen, wenn es da ist. Es gehoert **nicht** ins
# Repo -- deshalb steht das Verzeichnis in `.gitignore`.
#
#     tools/openssl-android.sh              # arm64-v8a, Vorgabe
#     tools/openssl-android.sh x86_64       # fuer den Emulator
set -euo pipefail

VERSION="3.5.8"
# Von https://github.com/openssl/openssl/releases/.../openssl-3.5.8.tar.gz.sha256
SHA256="a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2"
ABI="${1:-arm64-v8a}"

case "$ABI" in
  arm64-v8a)   ZIEL=android-arm64 ;;
  armeabi-v7a) ZIEL=android-arm ;;
  x86_64)      ZIEL=android-x86_64 ;;
  x86)         ZIEL=android-x86 ;;
  *) echo "unbekannte ABI: $ABI" >&2; exit 1 ;;
esac

R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUS="$R/build-openssl-android/$ABI"
ARBEIT="$R/build-openssl-android/_bau/$ABI"

if [ -f "$AUS/libssl_3.so" ] && [ -f "$AUS/libcrypto_3.so" ]; then
  echo "OpenSSL fuer $ABI liegt schon in $AUS"
  exit 0
fi

NDK="${ANDROID_NDK_ROOT:-}"
if [ -z "$NDK" ]; then
  NDK="$(find "${ANDROID_SDK_ROOT:-$HOME/Android/sdk}/ndk" -maxdepth 1 -mindepth 1 -type d \
         2>/dev/null | sort | tail -1)"
fi
[ -d "$NDK" ] || { echo "NDK nicht gefunden -- ANDROID_NDK_ROOT setzen" >&2; exit 1; }

mkdir -p "$ARBEIT" "$AUS"
cd "$ARBEIT"

TAR="openssl-$VERSION.tar.gz"
if [ ! -f "$TAR" ]; then
  echo "lade OpenSSL $VERSION ..."
  curl -sLO "https://github.com/openssl/openssl/releases/download/openssl-$VERSION/$TAR"
fi

# **Vor dem Auspacken pruefen, nicht danach.** Eine Pruefsumme, die man erst
# nach dem Entpacken bildet, prueft nichts mehr, was zaehlt.
echo "$SHA256  $TAR" | sha256sum -c - || {
  echo "Pruefsumme stimmt nicht -- Abbruch." >&2
  exit 1
}

[ -d "openssl-$VERSION" ] || tar xzf "$TAR"
cd "openssl-$VERSION"

export ANDROID_NDK_ROOT="$NDK"
export PATH="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

# `no-tests` und `no-docs` sparen den groessten Teil der Bauzeit; gebraucht
# wird nur `build_libs`, nicht das Kommandozeilenwerkzeug.
if [ ! -f Makefile ]; then
  ./Configure "$ZIEL" -D__ANDROID_API__=28 shared no-tests no-docs >/dev/null

  # **Qt sucht auf Android nach `libssl_3.so` und `libcrypto_3.so`.**
  # Nachgesehen im TLS-Plugin: es haengt an `ANDROID_OPENSSL_SUFFIX`, und die
  # Vorgabe ist `_3`. Ein leerer Wert der Variablen hilft nicht -- Qt nimmt
  # dann wieder die Vorgabe. Die Dateien muessen also so heissen.
  #
  # OpenSSLs Android-Ziele bauen aber `libssl.so` (unversioniert, weil
  # Android keine `.so.3` kennt). Deshalb wird der erzeugte Makefile
  # umgeschrieben, **bevor** gebaut wird: dann stimmen Dateiname, SONAME und
  # die Abhaengigkeit von libssl auf libcrypto von sich aus zusammen.
  #
  # Hinterher umbenennen waere schlechter: der SONAME und der NEEDED-Eintrag
  # blieben auf den alten Namen stehen. Man muesste beides mit `patchelf`
  # nachziehen -- oder beide Namen mitliefern, und dann laegen **zwei
  # OpenSSL-Instanzen** im selben Prozess, mit getrennten Fehlerschlangen und
  # getrenntem Zufallszustand. Das ist keine Kleinigkeit.
  sed -i -e 's/libcrypto\.so/libcrypto_3.so/g' \
         -e 's/libssl\.so/libssl_3.so/g' \
         -e 's/-lcrypto\b/-l:libcrypto_3.so/g' Makefile
fi
make build_libs -j "$(nproc)" >/dev/null

cp -f libssl_3.so libcrypto_3.so "$AUS/"
echo "OpenSSL $VERSION fuer $ABI liegt in $AUS"
readelf -d "$AUS/libssl_3.so" | grep -E "SONAME|NEEDED" | head -3
