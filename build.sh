#!/usr/bin/env bash
# Usage: SDK=/path/with/{jdk,android-14,android-6.0} ./build.sh
set -euo pipefail
cd "$(dirname "$0")"
: "${SDK:?set SDK to dir containing jdk/, android-14/ (build-tools), android-6.0/ (platform)}"
export JAVA_HOME="$SDK/jdk" PATH="$SDK/jdk/bin:$PATH"
BT="$SDK/android-14"; JAR="$SDK/android-6.0/android.jar"

rm -rf build && mkdir -p build/classes build/dex
javac --release 8 -classpath "$JAR" -d build/classes $(find src -name '*.java') 2>&1 | grep -v 'warning: \[options\]' || true
"$BT/d8" --min-api 21 --lib "$JAR" --output build/dex $(find build/classes -name '*.class')
"$BT/aapt" package -f -M AndroidManifest.xml -I "$JAR" -F build/unsigned.apk
(cd build/dex && "$BT/aapt" add ../unsigned.apk classes.dex >/dev/null)
"$BT/zipalign" -f 4 build/unsigned.apk build/aligned.apk

KS=debug.keystore
[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -storepass android -keypass android \
    -alias key -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=hdmi-autostart" >/dev/null
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:android --out hdmi-autostart.apk build/aligned.apk
echo "OK: $(pwd)/hdmi-autostart.apk"
