#!/usr/bin/env bash
# Construit l'APK Android d'Essence Arena sans Android Studio.
# Dépendances (Ubuntu/Debian) : apt-get install aapt apksigner zipalign dalvik-exchange android-sdk-platform-23 openjdk-17-jdk
set -euo pipefail
cd "$(dirname "$0")/.."

SDK=/usr/lib/android-sdk
ANDROID_JAR=$SDK/platforms/android-23/android.jar
BT=$SDK/build-tools/debian
OUT=build/android
APK=dist/EssenceArena.apk
KEYSTORE=${KEYSTORE:-android/essence-arena.keystore}
KS_PASS=${KS_PASS:-superessence}

npm run build
rm -rf "$OUT" && mkdir -p "$OUT/classes" "$OUT/assets/www" dist
cp -r www/* "$OUT/assets/www/"

# 1. Ressources + manifeste
aapt package -f -M android/AndroidManifest.xml -S android/res -I "$ANDROID_JAR" \
  -A "$OUT/assets" -F "$OUT/unsigned.apk" -0 arsc --min-sdk-version 21 --target-sdk-version 34

# 2. Java -> .class -> classes.dex
javac -source 8 -target 8 -encoding UTF-8 -Xlint:-options -bootclasspath "$ANDROID_JAR" \
  -d "$OUT/classes" $(find android/src -name '*.java')
"$BT/dx" --dex --min-sdk-version=21 --output="$OUT/classes.dex" "$OUT/classes"
(cd "$OUT" && zip -q unsigned.apk classes.dex)

# 3. Alignement + signature (v1 + v2)
zipalign -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" -alias essence \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=SuperEssence Studio, O=SuperEssence, C=FR"
fi
apksigner sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --ks-key-alias essence --out "$APK" "$OUT/aligned.apk"
apksigner verify --print-certs "$APK" | head -2
echo "APK prêt : $APK ($(du -h "$APK" | cut -f1))"
