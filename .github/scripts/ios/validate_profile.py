"""Validate the original Apple-signed CMS and its Distribution certificate."""
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys

TEAM = "8HJA5K2BQJ"
BUNDLE = "com.muhajeerbooks.app"
PROFILE_SHA256 = "03780f3ee0dd24845ddeed80c34dbe6a6143cf2d93ba1f24831236a474388a59"


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def validate(output):
    output.mkdir(parents=True, exist_ok=True)
    raw = base64.b64decode(Path(".github/signing/Muhajeer_Books_App_Store.mobileprovision.b64").read_text().strip(), validate=True)
    require(hashlib.sha256(raw).hexdigest() == PROFILE_SHA256,
            "Provisioning profile differs from the verified original Apple download.")
    profile_path = output / "profile.mobileprovision"
    profile_path.write_bytes(raw)
    # Verify the CMS content signature; never slice XML out of a binary container.
    # The pinned digest above identifies the original Apple-issued profile.
    decoded = subprocess.run(["openssl", "cms", "-verify", "-inform", "DER", "-noverify",
                              "-in", str(profile_path)], check=True, capture_output=True).stdout
    profile = plistlib.loads(decoded)
    (output / "profile.plist").write_bytes(decoded)
    entitlements = profile["Entitlements"]
    now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
    require(profile["CreationDate"] <= now < profile["ExpirationDate"], "Profile is not currently valid.")
    require(profile["TeamIdentifier"] == [TEAM], "Wrong profile team.")
    require(entitlements["application-identifier"] == f"{TEAM}.{BUNDLE}", "Wrong profile application identifier.")
    require(entitlements["com.apple.developer.team-identifier"] == TEAM, "Wrong entitlement team.")
    require(entitlements.get("get-task-allow") is False, "Development signing is not allowed for TestFlight.")
    require(entitlements.get("beta-reports-active") is True, "Profile does not authorize TestFlight.")
    require(not profile.get("ProvisionedDevices") and not profile.get("ProvisionsAllDevices"),
            "An App Store distribution profile is required.")
    cert = subprocess.run(["openssl", "x509", "-in", ".github/signing/apple_distribution.pem",
                           "-outform", "DER"], check=True, capture_output=True).stdout
    require(cert in profile["DeveloperCertificates"], "Profile does not contain this exact Distribution certificate.")
    subprocess.run(["openssl", "x509", "-in", ".github/signing/apple_distribution.pem",
                    "-checkend", "0", "-noout"], check=True)
    fingerprint = hashlib.sha1(cert).hexdigest().upper()
    metadata = {"uuid": profile["UUID"], "name": profile["Name"], "team": TEAM,
                "bundle": BUNDLE, "certificate_sha1": fingerprint,
                "profile_sha256": PROFILE_SHA256, "expires": profile["ExpirationDate"].isoformat()}
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    options = {"method": "app-store-connect", "destination": "export", "signingStyle": "manual",
               "teamID": TEAM, "signingCertificate": fingerprint,
               "provisioningProfiles": {BUNDLE: profile["UUID"]}, "uploadSymbols": True,
               "manageAppVersionAndBuildNumber": False}
    (output / "ExportOptions.plist").write_bytes(plistlib.dumps(options))
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a") as env:
            for k, v in {"PROFILE_UUID": profile["UUID"], "SIGNING_CERT_SHA1": fingerprint}.items():
                env.write(f"{k}={v}\n")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    validate(Path(sys.argv[1]))
