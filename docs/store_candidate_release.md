# Owner approval before public release

Store candidates use the same application source and full product features. The public App Store and Google Play releases are not automatically updated.

- iOS: TestFlight verifies the signed candidate; the follow-up workflow attaches that exact verified build to an App Store draft with `releaseType=MANUAL`. It does not submit a new review or call the public release endpoint. An outdated review may be withdrawn to attach the current candidate; a review for the same already-attached build is preserved.
- Android: API 28 and API 35 release startup/preferences integration tests must both succeed before signing and uploading the App Bundle. The upload track is fixed to `internal`. An API snapshot checks that Production releases remain unchanged.
- Public review/release scripts require approval tied to the exact version/build. The owner must test the candidate on their own iPhone and Android phone (including the previously affected Galaxy Note 8) and explicitly approve those candidate IDs before any public promotion.

Android generated-platform builds all apply `tools/prepare_android_release_safety.py`. The release disables code/resource shrinking and verifies those effective settings before building, preserving the preferences registrar that failed in earlier releases. Initial Flutter paint precedes plugin/backend initialization and presents loading/retry instead of an empty launch on startup failure. No saved customer/order data is cleared to recover startup.

Candidate artifacts record source SHA, build IDs and the pending owner approval. Never rebuild or promote a different binary based on approval of an earlier candidate.
