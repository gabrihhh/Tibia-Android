#!/usr/bin/env bash
# Compila o APK sem Gradle, só com as ferramentas do Android SDK.
# Pré-requisito: android/assets/runtime.tar.gz (tools/build-runtime.py).
# Saída: android/build/TibiaDroid.apk
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
BT="$SDK/build-tools/36.0.0"
JAR="$SDK/platforms/android-36/android.jar"
APP="$ROOT/android"
OUT="$APP/build"
KEYSTORE="${KEYSTORE:-$HOME/.android/debug.keystore}"

[ -f "$APP/assets/runtime.tar.gz" ] || { echo "falta android/assets/runtime.tar.gz (rode tools/build-runtime.py)"; exit 1; }
rm -rf "$OUT" && mkdir -p "$OUT/res" "$OUT/classes" "$OUT/dex"

# recursos + manifesto
"$BT/aapt2" compile --dir "$APP/res" -o "$OUT/res/res.zip"
"$BT/aapt2" link -o "$OUT/unsigned.apk" -I "$JAR" --manifest "$APP/AndroidManifest.xml" \
  --java "$OUT/gen" -A "$APP/assets" -0 gz --debug-mode "$OUT/res/res.zip"

# código Java -> dex
# java.* vem do JDK (lambdas); android.* do android.jar. O d8 faz o desugar.
javac --release 11 -Xlint:-options -encoding UTF-8 -classpath "$JAR" \
  -d "$OUT/classes" $(find "$APP/src" "$OUT/gen" -name '*.java')
"$BT/d8" --release --min-api 28 --lib "$JAR" --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')
(cd "$OUT/dex" && zip -q "$OUT/unsigned.apk" classes.dex)

# alinhar e assinar (chave de debug; criada se não existir)
if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -keystore "$KEYSTORE" -storepass android -keypass android -alias androiddebugkey \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null
fi
"$BT/zipalign" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android \
  --out "$OUT/TibiaDroid.apk" "$OUT/aligned.apk"
ls -lh "$OUT/TibiaDroid.apk"
