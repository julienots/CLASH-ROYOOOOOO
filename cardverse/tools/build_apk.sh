#!/usr/bin/env bash
# Exporte l'APK Android de CARDVERSE (Godot 4.3 + export templates) puis le signe (APK Signature Scheme v2).
# Prérequis : godot 4.3 dans le PATH, templates Android installés, python3 + cryptography.
# La clé de signature est créée dans ~/.cardverse-signing si absente (à conserver pour publier des mises à jour).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=../dist/Cardverse.apk
TMP=$(mktemp -d)
mkdir -p ../dist
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release Android "$TMP/unsigned.apk"
python3 tools/sign_apk.py "$TMP/unsigned.apk" "$OUT" "${CARDVERSE_KEY_DIR:-$HOME/.cardverse-signing}"
rm -rf "$TMP"
echo "APK prêt : dist/Cardverse.apk"
