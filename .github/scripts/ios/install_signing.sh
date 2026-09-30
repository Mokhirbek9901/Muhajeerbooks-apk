#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${CSR_PRIVATE_KEY_PASSWORD:?Missing CSR_PRIVATE_KEY_PASSWORD secret}"
SIGNING_DIR="$RUNNER_TEMP/signing"
mkdir -p "$SIGNING_DIR"
python3 .github/scripts/ios/validate_profile.py "$SIGNING_DIR"
# Confirm the native Apple decoder agrees with the verified CMS payload.
security cms -D -i "$SIGNING_DIR/profile.mobileprovision" -o "$SIGNING_DIR/native-profile.plist"
python3 - "$SIGNING_DIR" <<'PY'
import plistlib, sys
from pathlib import Path
p = Path(sys.argv[1])
assert plistlib.loads((p/'native-profile.plist').read_bytes()) == plistlib.loads((p/'profile.plist').read_bytes())
PY

# CSR #4's original artifact expires after one day. Use an exact, verified
# encrypted copy from a previous signing run if the original has expired.
if ! gh api "repos/$GITHUB_REPOSITORY/actions/artifacts/11082514116/zip" > "$SIGNING_DIR/key-artifact.zip" 2> "$SIGNING_DIR/artifact-error.txt"; then
  ARTIFACT_ID=$(gh api "repos/$GITHUB_REPOSITORY/actions/artifacts?name=muhajeer-csr4-encrypted-key&per_page=100" \
    --jq '[.artifacts[] | select(.expired == false)] | sort_by(.created_at) | last | .id // empty')
  test -n "$ARTIFACT_ID" || { echo '::error::The CSR #4 encrypted key artifact is unavailable.'; exit 1; }
  gh api "repos/$GITHUB_REPOSITORY/actions/artifacts/$ARTIFACT_ID/zip" > "$SIGNING_DIR/key-artifact.zip"
fi
python3 - "$SIGNING_DIR" <<'PY'
from pathlib import Path
import hashlib, sys, zipfile
p = Path(sys.argv[1])
with zipfile.ZipFile(p/'key-artifact.zip') as z:
    data = z.read('MuhajeerBooks-signing-key.zip')
expected = 'fa853c4c34e66b526960d51ee54a0ee3408342b24718a37e72401f6760c38a48'
if hashlib.sha256(data).hexdigest() != expected:
    raise SystemExit('Encrypted key archive does not match the verified CSR #4 artifact.')
(p/'MuhajeerBooks-signing-key.zip').write_bytes(data)
PY
unzip -q -P "$CSR_PRIVATE_KEY_PASSWORD" "$SIGNING_DIR/MuhajeerBooks-signing-key.zip" -d "$SIGNING_DIR"
CERT_PUB=$(openssl x509 -in .github/signing/apple_distribution.pem -pubkey -noout | openssl pkey -pubin -outform DER | shasum -a 256 | awk '{print $1}')
KEY_PUB=$(openssl pkey -in "$SIGNING_DIR/distribution-private-key.pem" -passin env:CSR_PRIVATE_KEY_PASSWORD -pubout -outform DER | shasum -a 256 | awk '{print $1}')
test "$CERT_PUB" = "$KEY_PUB" || { echo '::error::CSR #4 private key does not match the Distribution certificate.'; exit 1; }
echo "CSR #4 private key and Distribution certificate match: $CERT_PUB"
openssl pkcs12 -export -legacy -inkey "$SIGNING_DIR/distribution-private-key.pem" \
  -passin env:CSR_PRIVATE_KEY_PASSWORD -in .github/signing/apple_distribution.pem \
  -out "$SIGNING_DIR/distribution.p12" -passout env:CSR_PRIVATE_KEY_PASSWORD
KEYCHAIN="$RUNNER_TEMP/app-signing.keychain-db"
security create-keychain -p "$CSR_PRIVATE_KEY_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$CSR_PRIVATE_KEY_PASSWORD" "$KEYCHAIN"
security import "$SIGNING_DIR/distribution.p12" -P "$CSR_PRIVATE_KEY_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security -t cert -f pkcs12 -k "$KEYCHAIN"
curl --fail --silent --show-error --location https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer \
  -o "$SIGNING_DIR/AppleWWDRCAG3.cer"
security import "$SIGNING_DIR/AppleWWDRCAG3.cer" -k "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN" login.keychain-db
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$CSR_PRIVATE_KEY_PASSWORD" "$KEYCHAIN" >/dev/null
security find-identity -v -p codesigning "$KEYCHAIN" > "$SIGNING_DIR/identities.txt"
CERT_SHA1=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["certificate_sha1"])' "$SIGNING_DIR/metadata.json")
grep -q "$CERT_SHA1" "$SIGNING_DIR/identities.txt" || { echo '::error::Distribution signing identity is not trusted/usable.'; exit 1; }
cat "$SIGNING_DIR/identities.txt"
PROFILE_UUID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["uuid"])' "$SIGNING_DIR/metadata.json")
for PROFILE_DIR in "$HOME/Library/MobileDevice/Provisioning Profiles" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; do
  mkdir -p "$PROFILE_DIR"
  cp "$SIGNING_DIR/profile.mobileprovision" "$PROFILE_DIR/$PROFILE_UUID.mobileprovision"
done
