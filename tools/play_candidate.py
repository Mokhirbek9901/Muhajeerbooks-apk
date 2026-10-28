"""Prepare/verify an internal-only Play candidate without modifying Production."""
import json
import os
from pathlib import Path

PACKAGE = 'com.muhajeerbooks.app'
BASE = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}/edits'


def production_state(tracks):
    return sorted((r.get('status'), tuple(sorted(r.get('versionCodes',[]))), r.get('userFraction'))
                  for t in tracks if t.get('track')=='production' for r in t.get('releases',[]))


def main(mode):
    if os.environ.get('PLAY_TRACK') != 'internal':
        raise SystemExit('Production is blocked; this workflow only prepares INTERNAL owner tests.')
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession
    secret = os.environ.get('PLAY_SERVICE_ACCOUNT_JSON','').strip()
    if not secret:
        raise SystemExit('PLAY_SERVICE_ACCOUNT_JSON is missing; no store upload was attempted.')
    creds = service_account.Credentials.from_service_account_info(json.loads(secret), scopes=['https://www.googleapis.com/auth/androidpublisher'])
    session = AuthorizedSession(creds)
    def call(method, url, **kwargs):
        result = session.request(method, url, timeout=90, **kwargs)
        if not result.ok:
            raise RuntimeError(f'Google Play API {method}: HTTP {result.status_code}: {result.text[:600]}')
        return result.json() if result.content else {}
    edit = call('POST',BASE,json={})['id']
    try:
        tracks=call('GET',f'{BASE}/{edit}/tracks').get('tracks',[])
        snapshot=Path(os.environ['RUNNER_TEMP'])/'play-production-before.json'
        if mode=='preflight':
            snapshot.write_text(json.dumps(production_state(tracks)))
            bundles=call('GET',f'{BASE}/{edit}/bundles').get('bundles',[])
            codes=[int(b['versionCode']) for b in bundles]
            codes += [int(v) for t in tracks for r in t.get('releases',[]) for v in r.get('versionCodes',[])]
            code=max([1000+int(os.environ['GITHUB_RUN_NUMBER'])]+[v+1 for v in codes])
            with open(os.environ['GITHUB_ENV'],'a') as out: out.write(f'PLAY_BUILD_NUMBER={code}\n')
            print(f'Internal candidate selected: {code}. Production remains unchanged.')
        else:
            expected=str(os.environ['PLAY_BUILD_NUMBER'])
            internal=next((t for t in tracks if t.get('track')=='internal'),{})
            assert any(expected in r.get('versionCodes',[]) and r.get('status')=='completed' for r in internal.get('releases',[])), 'Internal release was not confirmed'
            assert json.loads(snapshot.read_text())==json.loads(json.dumps(production_state(tracks))), 'Production changed during candidate upload; investigate before releasing anything'
            evidence={'version_code':expected,'track':'internal','source':os.environ['GITHUB_SHA'], 'production_unchanged':True,'owner_test_approval':'pending'}
            (Path(os.environ['RUNNER_TEMP'])/'play-candidate.json').write_text(json.dumps(evidence,indent=2))
            print(f'VERIFIED: {expected} is INTERNAL ONLY. Production unchanged; owner approval pending.')
    finally:
        call('DELETE',f'{BASE}/{edit}')

if __name__=='__main__':
    import sys
    main(sys.argv[1])
