#!/bin/bash
API_JAR=""
KS=""
PASS=""
ALIAS=""
MIN_SDK="21"
TARGET_SDK="35"
if [ ! -f .vcode ]; then echo "1" > .vcode; fi
V_CODE=$(cat .vcode)
V_NAME="1.$(($V_CODE - 1))"
echo $(($V_CODE + 1)) > .vcode
sed -i "s/android:versionCode=\"[^\"]*\"/android:versionCode=\"$V_CODE\"/" AndroidManifest.xml
sed -i "s/android:versionName=\"[^\"]*\"/android:versionName=\"$V_NAME\"/" AndroidManifest.xml
DIST_DIR="dist/$V_NAME"
mkdir -p "$DIST_DIR"
rm -rf build
mkdir -p build/gen build/obj build/base/manifest build/base/dex build/base/res
echo "Step 1: Resources..."
aapt2 compile --dir ./res -o build/res.zip || exit 1
aapt2 link --manifest ./AndroidManifest.xml -I "$API_JAR" \
    --proto-format --java build/gen \
    --min-sdk-version "$MIN_SDK" --target-sdk-version "$TARGET_SDK" \
    --version-code "$V_CODE" --version-name "$V_NAME" \
    -o build/base.zip build/res.zip --auto-add-overlay || exit 1
echo "Step 2: Java..."
ecj -d build/obj -cp "$API_JAR" "./src/com/abn/simpleweather/MainActivity.java" build/gen/com/abn/simpleweather/R.java || exit 1
echo "Step 3: DEX..."
mkdir -p build/base/dex/
d8 --output build/base/dex/ --lib "$API_JAR" $(find build/obj -name "*.class") || exit 1
echo "Step 4: Bundle..."
unzip -q build/base.zip -d build/base/
mkdir -p build/base/manifest
mv build/base/AndroidManifest.xml build/base/manifest/
rm -f build/base.zip
(cd build/base && zip -rq ../base_folder.zip .)
java -jar tools/bundletool.jar build-bundle --modules=build/base_folder.zip --output=build/OLED_Weather.aab || exit 1
jarsigner -keystore "$KS" -storepass "$PASS" -keypass "$PASS" build/OLED_Weather.aab "$ALIAS" || exit 1
echo "Step 5: APK..."
java -jar tools/bundletool.jar build-apks \
    --bundle=build/OLED_Weather.aab \
    --output=build/OLED_Weather.apks \
    --mode=universal \
    --aapt2=$(which aapt2) \
    --ks="$KS" --ks-pass=pass:"$PASS" --ks-key-alias="$ALIAS" --key-pass=pass:"$PASS" || exit 1
unzip -p build/OLED_Weather.apks universal.apk > "build/OLED_Weather_v$V_NAME.apk"
if [ -s "build/OLED_Weather_v$V_NAME.apk" ]; then
    mv build/OLED_Weather_v$V_NAME.apk "$DIST_DIR/"
    mv build/OLED_Weather.aab "$DIST_DIR/OLED_Weather_v$V_NAME.aab"
    rm -rf build
    echo "SUCCESS: Version $V_NAME (Code $V_CODE)"
else
    echo "ERROR: Build failed."
    exit 1
fi
