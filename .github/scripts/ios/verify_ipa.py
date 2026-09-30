"""Verify the actual exported IPA before uploading, not just build settings."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess

from validate_profile import BUNDLE, TEAM, require

ipas = list(Path('build/ios/ipa').glob('*.ipa'))
require(len(ipas) == 1, f'Expected one signed IPA, found {len(ipas)}.')
ipa = ipas[0]
output = Path(os.environ['RUNNER_TEMP']) / 'ipa-verification'
output.mkdir(exist_ok=True)
# ditto preserves executable modes and symlinks in the signed application.
subprocess.run(['ditto', '-x', '-k', str(ipa), str(output)], check=True)
apps = list((output / 'Payload').glob('*.app'))
require(len(apps) == 1, 'Expected one application payload.')
app = apps[0]
info = plistlib.loads((app / 'Info.plist').read_bytes())
require(info['CFBundleIdentifier'] == BUNDLE, 'Wrong IPA bundle ID.')
require(set(info['UIDeviceFamily']) == {1, 2}, 'IPA must support both iPhone and iPad.')
require(str(info['CFBundleVersion']) == os.environ['IOS_BUILD_NUMBER'], 'Wrong IPA build number.')
require(info['CFBundleShortVersionString'] == os.environ['IOS_MARKETING_VERSION'], 'Wrong IPA version.')
subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], check=True)
profile = plistlib.loads(subprocess.run(['openssl', 'cms', '-verify', '-inform', 'DER', '-noverify',
                                      '-in', str(app/'embedded.mobileprovision')], check=True, capture_output=True).stdout)
require(profile['UUID'] == os.environ['PROFILE_UUID'], 'Export used a different profile.')
entitlements = plistlib.loads(subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)],
                                           check=True, capture_output=True).stdout)
require(entitlements['application-identifier'] == f'{TEAM}.{BUNDLE}', 'Wrong signed application identifier.')
require(entitlements['com.apple.developer.team-identifier'] == TEAM, 'Wrong signed team.')
require(not entitlements.get('get-task-allow', False), 'IPA is signed for debugging.')
prefix = str(output / 'certificate-')
subprocess.run(['codesign', '-d', '--extract-certificates=' + prefix, str(app)], check=True)
require(hashlib.sha1(Path(prefix + '0').read_bytes()).hexdigest().upper() == os.environ['SIGNING_CERT_SHA1'],
        'Export used a different signing certificate.')
result = {'ipa': str(ipa), 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
          'bundle_id': BUNDLE, 'device_families': info['UIDeviceFamily'],
          'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
          'profile_uuid': profile['UUID'], 'certificate_sha1': os.environ['SIGNING_CERT_SHA1']}
(Path(os.environ['RUNNER_TEMP'])/'ipa-verification.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
