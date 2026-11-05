"""Promote an immutable, CI-tested signed candidate authorized on 2026-11-05."""
import hashlib
import json
import os
from pathlib import Path

PACKAGE = 'com.muhajeerbooks.app'
NAME = '2.5.26'
API = 'https://androidpublisher.googleapis.com/androidpublisher/v3'


def main():
    evidence_dir = Path(os.environ['CANDIDATE_EVIDENCE_DIR'])
    files = list(evidence_dir.rglob('play-candidate.json'))
    bundles = list(evidence_dir.rglob('app-release.aab'))
    if len(files) != 1 or len(bundles) != 1:
        raise ValueError('Expected exactly one immutable candidate and signed AAB')
    candidate = json.loads(files[0].read_text())
    code = str(candidate['version_code'])
    source = os.environ['EXPECTED_CANDIDATE_SOURCE']
    if candidate.get('source') != source or candidate.get('track') != 'internal' or candidate.get('production_unchanged') is not True:
        raise ValueError('Candidate provenance is not the verified internal-only source')
    if os.environ.get('OWNER_APPROVED_EXACT_RELEASE') != f'{PACKAGE}:{NAME}:{code}':
        raise ValueError('Owner authorization does not match this exact signed candidate')
    local_hash = hashlib.sha256(bundles[0].read_bytes()).hexdigest()
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ['PLAY_SERVICE_ACCOUNT_JSON']),
        scopes=['https://www.googleapis.com/auth/androidpublisher'])
    session = AuthorizedSession(creds)

    def call(method, url, **kwargs):
        response = session.request(method, url, timeout=90, **kwargs)
        if not response.ok:
            raise RuntimeError(f'Google Play {method}: HTTP {response.status_code}: {response.text[:1200]}')
        return response.json() if response.content else {}

    base = f'{API}/applications/{PACKAGE}/edits'
    output = Path(os.environ['RUNNER_TEMP']) / 'final-play-production.json'
    report = {'version': NAME, 'version_code': code, 'source': source,
              'aab_sha256': local_hash, 'result': 'not_submitted',
              'physical_note8_test_performed': False,
              'automated_release_tests': ['Android API 28', 'Android API 35', 'Flutter regression suite']}
    edit = call('POST', base, json={})['id']
    committed = False
    try:
        tracks = call('GET', f'{base}/{edit}/tracks').get('tracks', [])
        internal = next((t for t in tracks if t['track'] == 'internal'), {})
        if not any(r.get('status') == 'completed' and r.get('name') == NAME and r.get('versionCodes') == [code]
                   for r in internal.get('releases', [])):
            raise ValueError('Exact tested binary is not the completed internal release')
        bundle = next((b for b in call('GET', f'{base}/{edit}/bundles').get('bundles', [])
                       if str(b.get('versionCode')) == code), None)
        if not bundle or bundle.get('sha256', '').lower() != local_hash:
            raise ValueError('Google bundle hash differs from the CI signed AAB')
        production = next((t for t in tracks if t['track'] == 'production'), {'track': 'production'})
        for release in production.get('releases', []):
            if release.get('status') in ('completed', 'inProgress') and any(int(c) > int(code) for c in release.get('versionCodes', [])):
                raise ValueError('Newer Production binary exists; refusing to replace it')
            if release.get('status') == 'draft' and code not in release.get('versionCodes', []):
                raise ValueError('Unrelated production draft exists; leave it untouched')
        report['production_before'] = production
        already = any(r.get('status') == 'completed' and r.get('versionCodes') == [code]
                      for r in production.get('releases', []))
        if not already:
            release = {'name': NAME, 'versionCodes': [code], 'status': 'completed',
                       'releaseNotes': [{'language': 'en-US', 'text':
                           'Updated book recommendations, preorders, arrival dates and batch summaries. Improved Android startup recovery and mandatory store update handling.'}]}
            call('PUT', f'{base}/{edit}/tracks/production', json={'track': 'production', 'releases': [release]})
            call('POST', f'{base}/{edit}:validate')
            report['result'] = 'validated'
            output.write_text(json.dumps(report, indent=2))
            call('POST', f'{base}/{edit}:commit', params={
                'changesNotSentForReview': 'false', 'changesInReviewBehavior': 'ERROR_IF_IN_REVIEW'})
            committed = True
        report['result'] = 'production_configured'
        check = call('POST', base, json={})['id']
        try:
            after = call('GET', f'{base}/{check}/tracks').get('tracks', [])
            production_after = next(t for t in after if t['track'] == 'production')
            if not any(r.get('status') == 'completed' and r.get('versionCodes') == [code]
                       for r in production_after.get('releases', [])):
                raise ValueError('Production did not retain the exact tested binary')
            before_other = sorted((t for t in tracks if t['track'] != 'production'), key=lambda t: t['track'])
            after_other = sorted((t for t in after if t['track'] != 'production'), key=lambda t: t['track'])
            if before_other != after_other:
                raise ValueError('Another testing track changed; investigate')
            report.update(production_after=production_after, other_tracks_unchanged=True)
        finally:
            call('DELETE', f'{base}/{check}')
        lifecycle = call('GET', f'{API}/applications/{PACKAGE}/tracks/production/releases')
        report['publishing_lifecycle'] = [r for r in lifecycle.get('releases', [])
            if any(str(a.get('versionCode')) == code for a in r.get('activeArtifacts', []))]
        print(json.dumps(report, indent=2))
    finally:
        output.write_text(json.dumps(report, indent=2))
        if not committed:
            call('DELETE', f'{base}/{edit}')


if __name__ == '__main__':
    main()
