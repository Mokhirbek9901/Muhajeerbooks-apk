"""Publish exact tested Google Play internal candidate 1213 to Production.

No rebuild, no track replacements outside Production; abort if anything changed.
This is an explicit new owner request for version 2.5.22 (1213), independent of
the previous 1190 hold. A pending Google review can delay device updates.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

PACKAGE = "com.muhajeerbooks.app"
VERSION = "1213"
NAME = "2.5.22"
API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
BASE = f"{API}/applications/{PACKAGE}/edits"
EVIDENCE = Path(os.environ["RUNNER_TEMP"]) / "play-public-1213.json"

def run():
    if os.environ.get("OWNER_APPROVED_EXACT_RELEASE") != f"{PACKAGE}:{NAME}:{VERSION}":
        raise ValueError("Exact owner authorization missing")
    if os.environ.get("GITHUB_REF_NAME") != "android-testflight-sync-20261101":
        raise ValueError("Only the inspected Android synchronization branch may promote")
    credentials = service_account.Credentials.from_service_account_info(
        json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"]),
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    client = AuthorizedSession(credentials)

    def request(method, url, **kwargs):
        response = client.request(method, url, timeout=90, **kwargs)
        if not response.ok:
            raise RuntimeError(
                f"Google Play {method} HTTP {response.status_code}: {response.text[:1100]}"
            )
        return response.json() if response.content else {}

    edit = request("POST", BASE, json={})["id"]
    committed = False
    evidence = {
        "package": PACKAGE, "version": NAME, "versionCode": VERSION,
        "candidate_run_id": 41245216198, "source": "4ba3ca8678312c095e42115f0c3dcf6ceeb858ed",
        "result": "not_submitted"
    }
    try:
        tracks = request("GET", f"{BASE}/{edit}/tracks").get("tracks", [])
        track_map = {t["track"]: t for t in tracks}
        internal = track_map.get("internal", {})
        production = track_map.get("production", {})
        releases = internal.get("releases", [])
        if not any(r.get("status") == "completed" and VERSION in r.get("versionCodes", [])
                   for r in releases):
            raise ValueError("The exact tested 1213 candidate is not completed in Internal testing")
        bundles = request("GET", f"{BASE}/{edit}/bundles").get("bundles", [])
        bundle = next((b for b in bundles if str(b.get("versionCode")) == VERSION), None)
        if not bundle or not bundle.get("sha256"):
            raise ValueError("Signed 1213 App Bundle missing; refuse to rebuild/guess")
        current_codes = [
            int(code)
            for r in production.get("releases", [])
            for code in r.get("versionCodes", [])
            if r.get("status") in ("completed", "inProgress")
        ]
        if current_codes and max(current_codes) > int(VERSION):
            raise ValueError("Newer Production release exists; cannot downgrade")
        evidence.update(
            internal=internal, production_before=production,
            signed_bundle_sha256=bundle["sha256"],
        )
        if any(r.get("status") == "completed" and VERSION in r.get("versionCodes", [])
               for r in production.get("releases", [])):
            evidence["result"] = "already_production"
            print("VERIFIED: version 1213 already completed in Production")
            return

        # Android API 28 and 35 release smoke tests succeeded on run 41245216198.
        release = {
            "name": NAME,
            "versionCodes": [VERSION],
            "status": "completed",
            "releaseNotes": [{
                "language": "en-US",
                "text": "Improved book discovery: more titles by each author and similar books. Better preorder arrivals, deposit choices, and order handling."
            }],
        }
        request("PUT", f"{BASE}/{edit}/tracks/production",
                json={"track": "production", "releases": [release]})
        request("POST", f"{BASE}/{edit}:validate")
        evidence["result"] = "validated"
        EVIDENCE.write_text(json.dumps(evidence, indent=2), encoding="utf-8")
        request("POST", f"{BASE}/{edit}:commit", params={
            "changesNotSentForReview": "false",
            "changesInReviewBehavior": "ERROR_IF_IN_REVIEW"
        })
        committed = True
        evidence["result"] = "submitted"
        print("COMMITTED: exact internal version 1213 submitted to Google Play Production")

        check_edit = request("POST", BASE, json={})["id"]
        try:
            after = request("GET", f"{BASE}/{check_edit}/tracks").get("tracks", [])
            current = next((t for t in after if t["track"] == "production"), {})
            evidence["production_after"] = current
            previous_other = {k: v for k, v in track_map.items() if k != "production"}
            current_other = {t["track"]: t for t in after if t["track"] != "production"}
            evidence["other_tracks_unchanged"] = current_other == previous_other
            if not evidence["other_tracks_unchanged"]:
                raise ValueError("An unrelated testing track changed; inspect immediately")
            if not any(r.get("status") == "completed" and VERSION in r.get("versionCodes", [])
                       for r in current.get("releases", [])):
                raise ValueError("Production has not yet confirmed 1213")
            evidence["result"] = "production_configured"
            print("VERIFIED: Google Play Production configured with 1213")
            print("GOOGLE_REVIEW_OR_MANAGED_PUBLISHING_MAY_DELAY_VISIBILITY")
        finally:
            request("DELETE", f"{BASE}/{check_edit}")
    finally:
        EVIDENCE.write_text(json.dumps(evidence, indent=2), encoding="utf-8")
        if not committed:
            request("DELETE", f"{BASE}/{edit}")

if __name__ == "__main__":
    run()
