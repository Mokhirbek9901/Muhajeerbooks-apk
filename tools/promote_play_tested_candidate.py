"""Promote only the exact Android binary that the owner tested and approved."""
import argparse
import copy
import json
import os
from pathlib import Path
import time

PACKAGE = 'com.muhajeerbooks.app'
VERSION = '1190'
SOURCE = '44917f721778c08e0e660a172c02bf1c4757f4b4'
APPROVAL = f'{PACKAGE}:2.5.20:{VERSION}'
API = 'https://androidpublisher.googleapis.com/androidpublisher/v3'
BASE = f'{API}/applications/{PACKAGE}/edits'
LIFECYCLE = f'{API}/applications/{PACKAGE}/tracks/production/releases'


def require_approval(approval, token):
    expected = {'package': PACKAGE, 'version_code': VERSION, 'source': SOURCE,
                'owner_test_passed': True, 'public_release_allowed': True,
                'scope': 'android_only'}
    if token != APPROVAL or any(approval.get(k) != v for k, v in expected.items()):
        raise ValueError('Exact owner approval for Android 1190 is required before credentials or writes')


def require_candidate(candidate):
    expected = {'version_code': VERSION, 'source': SOURCE, 'track': 'internal', 'production_unchanged': True}
    if any(candidate.get(k) != v for k, v in expected.items()):
        raise ValueError('Immutable successful internal candidate evidence does not match 1190')


def find_internal(tracks):
    internal = next((t for t in tracks if t.get('track') == 'internal'), {})
    match = next((r for r in internal.get('releases', [])
                  if r.get('status') == 'completed' and r.get('versionCodes') == [VERSION]), None)
    if match is None:
        raise ValueError('The exact owner-tested binary is not completed on the internal track')
    return match


def plan_production(production, internal):
    find_internal([{'track': 'internal', 'releases': [internal]}])
    previous = production.get('releases', [])
    for release in previous:
        if release.get('status') in ('completed', 'inProgress'):
            if any(int(code) > int(VERSION) for code in release.get('versionCodes', [])):
                raise ValueError('A newer public release exists; refusing to downgrade it')
    exact = next((r for r in previous if r.get('status') == 'completed'
                  and r.get('versionCodes') == [VERSION] and not r.get('countryTargeting')), None)
    if exact:
        return None
    preserved = [copy.deepcopy(r) for r in previous if r.get('status') in ('halted', 'draft')
                 and VERSION not in r.get('versionCodes', [])]
    release = {'name': '2.5.20 (1190)', 'versionCodes': [VERSION], 'status': 'completed'}
    if internal.get('releaseNotes'):
        release['releaseNotes'] = copy.deepcopy(internal['releaseNotes'])
    else:
        release['releaseNotes'] = [{'language': 'en-US', 'text': 'Fixed startup blank screens. Improved book photo galleries, preorder advance deduction, keyboard dismissal and order validation.'}]
    if 'inAppUpdatePriority' in internal:
        release['inAppUpdatePriority'] = internal['inAppUpdatePriority']
    return {'track': 'production', 'releases': preserved + [release]}


def verify_production(before, after):
    if not any(r.get('status') == 'completed' and r.get('versionCodes') == [VERSION]
               and not r.get('countryTargeting') and 'userFraction' not in r
               for r in after.get('releases', [])):
        raise ValueError('Production does not confirm the exact full-rollout 1190 candidate')
    halted = {code for r in before.get('releases', []) if r.get('status') == 'halted'
              for code in r.get('versionCodes', [])}
    if any(halted.intersection(r.get('versionCodes', [])) for r in after.get('releases', [])
           if r.get('status') in ('completed', 'inProgress')):
        raise ValueError('A previously halted binary was reactivated')


def lifecycle_for(result):
    return [r for r in result.get('releases', [])
            if any(str(a.get('versionCode')) == VERSION for a in r.get('activeArtifacts', []))]


def run(mode, approval_path, evidence_dir, output):
    approval = json.loads(Path(approval_path).read_text())
    require_approval(approval, os.environ.get('OWNER_APPROVED_PUBLIC_RELEASE'))
    candidates = list(Path(evidence_dir).rglob('play-candidate.json'))
    if len(candidates) != 1:
        raise ValueError('Expected one immutable internal candidate artifact')
    require_candidate(json.loads(candidates[0].read_text()))
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession
    credentials = service_account.Credentials.from_service_account_info(
        json.loads(os.environ['PLAY_SERVICE_ACCOUNT_JSON']),
        scopes=['https://www.googleapis.com/auth/androidpublisher'])
    session = AuthorizedSession(credentials)
    def call(method, url, **kwargs):
        response = session.request(method, url, timeout=60, **kwargs)
        if not response.ok:
            raise RuntimeError(f'Google Play {method}: HTTP {response.status_code}: {response.text[:1500]}')
        return response.json() if response.content else {}
    edit = call('POST', BASE, json={})['id']
    committed = False
    report = {'package': PACKAGE, 'version_code': VERSION, 'source': SOURCE,
              'mode': mode, 'owner_test_passed': True, 'approval_scope': 'android_only'}
    try:
        tracks = call('GET', f'{BASE}/{edit}/tracks').get('tracks', [])
        internal = find_internal(tracks)
        production = next((t for t in tracks if t.get('track') == 'production'), {'track': 'production', 'releases': []})
        bundle = next((b for b in call('GET', f'{BASE}/{edit}/bundles').get('bundles', [])
                       if str(b.get('versionCode')) == VERSION), None)
        if bundle is None or not bundle.get('sha256'):
            raise ValueError('The existing signed 1190 bundle/hash was not found; no rebuild is allowed')
        if approval.get('bundle_sha256') and bundle['sha256'] != approval['bundle_sha256']:
            raise ValueError('Bundle SHA256 differs from the inspected owner-tested binary')
        plan = plan_production(production, internal)
        report.update(production_before=production, production_plan=plan, bundle=bundle,
                      lifecycle_before=call('GET', LIFECYCLE))
        print('Production before:', json.dumps(production))
        print('Existing 1190 bundle SHA256:', bundle['sha256'])
        print('Current publishing lifecycle:', json.dumps(report['lifecycle_before']))
        Path(output).write_text(json.dumps(report, indent=2))
        if mode == 'inspect':
            print('READ ONLY: inspected the exact 1190 candidate. No track update or commit.')
            return
        if plan is not None:
            call('PUT', f'{BASE}/{edit}/tracks/production', json=plan)
            call('POST', f'{BASE}/{edit}:validate')
            call('POST', f'{BASE}/{edit}:commit', params={
                'changesNotSentForReview': 'false', 'changesInReviewBehavior': 'ERROR_IF_IN_REVIEW'})
            committed = True
        verify_edit = call('POST', BASE, json={})['id']
        try:
            after_tracks = call('GET', f'{BASE}/{verify_edit}/tracks').get('tracks', [])
            after = next(t for t in after_tracks if t['track'] == 'production')
            verify_production(production, after)
            others_before = sorted([t for t in tracks if t['track'] != 'production'], key=lambda t:t['track'])
            others_after = sorted([t for t in after_tracks if t['track'] != 'production'], key=lambda t:t['track'])
            if others_before != others_after:
                raise ValueError('Another testing track changed during publication; investigate')
            report.update(production_after=after, other_tracks_unchanged=True,
                          previous_halted_not_reactivated=True, production_committed=True)
        finally:
            call('DELETE', f'{BASE}/{verify_edit}')
        deadline = time.monotonic() + 90
        while True:
            live = call('GET', LIFECYCLE)
            exact = lifecycle_for(live)
            states = [r.get('releaseLifecycleState') for r in exact]
            report.update(publishing_lifecycle=live, exact_candidate_lifecycle=states)
            Path(output).write_text(json.dumps(report, indent=2))
            print('1190 live publishing lifecycle:', states)
            if states or time.monotonic() >= deadline:
                break
            time.sleep(10)
        print('VERIFIED: exact owner-tested 1190 is configured as completed on Production; no binary was rebuilt. iOS untouched.')
        print('PUBLIC_AVAILABILITY:', ','.join(states) if states else 'AWAITING_GOOGLE_PROCESSING')
    finally:
        if not committed:
            call('DELETE', f'{BASE}/{edit}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['inspect', 'promote'])
    parser.add_argument('--approval', required=True)
    parser.add_argument('--evidence-dir', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    run(args.mode, args.approval, args.evidence_dir, args.output)
