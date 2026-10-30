#!/usr/bin/env bash
# Exporte l'APK Android de Clash of Things avec Godot 4.3 (export templates installés).
# Variables optionnelles : KEYSTORE, KS_USER, KS_PASS
set -euo pipefail
cd "$(dirname "$0")/../godot"
KEYSTORE=${KEYSTORE:-$PWD/clash-of-things.keystore}
KS_USER=${KS_USER:-clashofthings}
KS_PASS=${KS_PASS:-superessence}
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" -alias "$KS_USER" \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=SuperEssence Studio, O=SuperEssence, C=FR"
fi
mkdir -p ../dist
godot --headless --import
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE" GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KS_USER" \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KS_PASS" godot --headless --export-release Android ../dist/ClashOfThings.apk
rm -f ../dist/*.idsig
echo "APK prêt : dist/ClashOfThings.apk"
