#!/bin/sh
# Baut die zwei gebuendelten Bibliotheken fuer den Spendenteil neu:
#   functions/_lib/ableitung.js  Adressen aus dem zpub (Pages Function)
#   website/qr.js                QR-Codes im Browser
#
# **Warum gebuendelt und eingecheckt.** Das Pages-Projekt baut nicht (Build
# command leer), also gibt es dort kein npm install. Die Bibliotheken sind
# die gepruefte Familie von Paul Miller (noble/scure) und uqr; die Fassungen
# stehen hier fest und im Kopf jeder erzeugten Datei.
#
# Aufruf: tools/spenden/bau.sh <arbeitsordner>, danach tools/spenden/test.mjs.
set -eu
HIER=$(cd "$(dirname "$0")" && pwd)
WURZEL=$(cd "$HIER/../.." && pwd)
ARBEIT=${1:?Arbeitsordner angeben, z. B. im Scratchpad}
mkdir -p "$ARBEIT"
cd "$ARBEIT"
[ -f package.json ] || npm init -y >/dev/null
npm install --save-exact @scure/bip32@2.4.0 @scure/base@2.4.0 @noble/hashes@2.4.0 uqr@0.1.3 esbuild@0.28.2
cp "$HIER/ableitung.src.js" "$HIER/qr.src.js" .
npx esbuild ableitung.src.js --bundle --format=esm --platform=neutral --minify \
  --legal-comments=inline --outfile=ableitung.js
npx esbuild qr.src.js --bundle --format=iife --global-name=OrangeQR --minify \
  --legal-comments=inline --outfile=qr.js
{ printf '%s\n' "// Gebuendelt aus @scure/bip32 2.4.0, @scure/base 2.4.0, @noble/curves 2.4.0 und" \
    "// @noble/hashes 2.4.0 (alle MIT) durch tools/spenden/bau.sh. Nicht hier bearbeiten." \
    "// Geprueft gegen den Testvektor aus BIP84 (tools/spenden/test.mjs)."
  cat ableitung.js; } > "$WURZEL/functions/_lib/ableitung.js"
{ printf '%s\n' "// Gebuendelt aus uqr 0.1.3 (MIT) durch tools/spenden/bau.sh. Nicht hier bearbeiten."
  cat qr.js; } > "$WURZEL/website/qr.js"
echo "fertig; jetzt: node tools/spenden/test.mjs"
