"""Publish only store-verified, fully available Android release metadata."""
import datetime as dt
import json
import os
from pathlib import Path

PACKAGE = 'com.muhajeerbooks.app'
API = 'https://androidpublisher.googleapis.com/androidpublisher/v3'
PUBLISHED = 'RELEASE_LIFECYCLE_STATE_PUBLISHED'


def choose_public_release(tracks, lifecycle):
    public_codes = {
        str(a['versionCode'])
        for r in lifecycle.get('releases', [])
        if r.get('releaseLifecycleState') == PUBLISHED
        for a in r.get('activeArtifacts', [])
    }
    production = next((t for t in tracks if t.get('track') == 'production'), {})
    eligible = []
    for r in production.get('releases', []):
        if r.get('status') != 'completed' or r.get('countryTargeting') or r.get('userFraction') is not None:
            continue
        for code in r.get('versionCodes', []):
            if str(code) in public_codes:
                eligible.append((int(code), r.get('name', '')))
    return max(eligible, default=None)


def main(output):
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession
    credentials = service_account.Credentials.from_service_account_info(
        json.loads(os.environ['PLAY_SERVICE_ACCOUNT_JSON']),
        scopes=['https://www.googleapis.com/auth/androidpublisher'])
    session = AuthorizedSession(credentials)
    def call(method, url, **kwargs):
        response = session.request(method, url, timeout=45, **kwargs)
        response.raise_for_status()
        return response.json() if response.content else {}
    base = f'{API}/applications/{PACKAGE}'
    lifecycle = call('GET', f'{base}/tracks/production/releases')
    edit = call('POST', f'{base}/edits', json={})['id']
    try:
        tracks = call('GET', f'{base}/edits/{edit}/tracks').get('tracks', [])
        selected = choose_public_release(tracks, lifecycle)
    finally:
        call('DELETE', f'{base}/edits/{edit}')
    if selected is None:
        raise SystemExit('No fully published production binary confirmed. Preserve the last verified server configuration.')
    code, version = selected
    parts = version.split('.')
    if not 2 <= len(parts) <= 4 or not all(part.isdigit() for part in parts):
        raise SystemExit('Production release name is not a marketing version; leave metadata unchanged.')
    document = {'package': PACKAGE, 'version': version, 'build': code,
        'available': True, 'track': 'production', 'lifecycle': PUBLISHED,
        'full_rollout': True, 'verified_at': dt.datetime.now(dt.timezone.utc).isoformat()}
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(json.dumps(document, indent=2) + chr(10))
    print(json.dumps(document))


if __name__ == '__main__':
    import sys
    main(sys.argv[1])
