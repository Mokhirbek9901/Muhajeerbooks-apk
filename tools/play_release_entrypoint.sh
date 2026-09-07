#!/usr/bin/env bash
set -euo pipefail

: "${PLAY_KEYSTORE_B64:?PLAY_KEYSTORE_B64 is required}"
: "${PLAY_STORE_PASSWORD:?PLAY_STORE_PASSWORD is required}"
: "${PLAY_KEY_PASSWORD:?PLAY_KEY_PASSWORD is required}"
: "${PLAY_KEY_ALIAS:?PLAY_KEY_ALIAS is required}"

rm -rf /work /output
mkdir -p /work /output
cp -a /src/. /work/
cd /work

flutter create . --platforms=android,web --project-name muhajeerbooks --org com.muhajeerbooks
flutter pub get
python3 tools/play_prepare_android.py

printf '%s' "$PLAY_KEYSTORE_B64" | base64 -d > android/app/upload-keystore.jks
chmod 600 android/app/upload-keystore.jks
cat > android/key.properties <<EOF
storePassword=$PLAY_STORE_PASSWORD
keyPassword=$PLAY_KEY_PASSWORD
keyAlias=$PLAY_KEY_ALIAS
storeFile=upload-keystore.jks
EOF
chmod 600 android/key.properties

# Replace Flutter's default launcher icon with the official Muhajeer Books logo.
LOGO="assets/images/muhajeer_logo.jpg"
for spec in "mdpi:48" "hdpi:72" "xhdpi:96" "xxhdpi:144" "xxxhdpi:192"; do
  density="${spec%%:*}"
  size="${spec##*:}"
  dir="android/app/src/main/res/mipmap-${density}"
  if [ -d "$dir" ]; then
    convert "$LOGO" -resize "${size}x${size}^" -gravity center -extent "${size}x${size}" "$dir/ic_launcher.png"
    if [ -f "$dir/ic_launcher_round.png" ]; then
      convert "$LOGO" -resize "${size}x${size}^" -gravity center -extent "${size}x${size}" "$dir/ic_launcher_round.png"
    fi
  fi
done

flutter build appbundle --release
flutter build web --release

cp -a build/web/. /output/
cp build/app/outputs/bundle/release/app-release.aab /output/muhajeer-books-release.aab
keytool -exportcert -rfc \
  -keystore android/app/upload-keystore.jks \
  -storepass "$PLAY_STORE_PASSWORD" \
  -alias "$PLAY_KEY_ALIAS" \
  -file /output/upload_certificate.pem >/dev/null 2>&1
sha256sum /output/muhajeer-books-release.aab | awk '{print $1}' > /output/muhajeer-books-release.sha256

rm -f android/app/upload-keystore.jks android/key.properties

exec python3 /src/tools/play_serve.py
