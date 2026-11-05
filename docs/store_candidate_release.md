# Owner approval before public release

Store candidates use the same application source and full product features. The public App Store and Google Play releases are not automatically updated.

- iOS: TestFlight verifies the signed candidate; the follow-up workflow attaches that exact verified build to an App Store draft with `releaseType=MANUAL`. It does not submit a new review or call the public release endpoint. An outdated review may be withdrawn to attach the current candidate; a review for the same already-attached build is preserved.
- Android: API 28 and API 35 release startup/preferences integration tests must both succeed before signing and uploading the App Bundle. The upload track is fixed to `internal`. An API snapshot checks that Production releases remain unchanged.
- Public review/release scripts require approval tied to the exact version/build. The owner must test the candidate on their own iPhone and Android phone (including the previously affected Galaxy Note 8) and explicitly approve those candidate IDs before any public promotion.

Android generated-platform builds all apply `tools/prepare_android_release_safety.py`. The release disables code/resource shrinking and verifies those effective settings before building, preserving the preferences registrar that failed in earlier releases. Initial Flutter paint precedes plugin/backend initialization and presents loading/retry instead of an empty launch on startup failure. No saved customer/order data is cleared to recover startup.

Candidate artifacts record source SHA, build IDs and the pending owner approval. Never rebuild or promote a different binary based on approval of an earlier candidate.

## Final release authorized on 2026-11-05

The owner explicitly authorized the existing tested iOS 2.5.26 (340031) and a minimally hardened Android build with the same features after successful automated release checks. This authorization supersedes the generic pending-approval marker for the exact candidates below; it does not claim physical device testing.

- iOS 2.5.26 (340031): submitted unchanged, WAITING_FOR_REVIEW, releaseType AFTER_APPROVAL. No replacement iOS binary was built.
- Android 2.5.26 (1215): exact signed AAB from run 42027562708, source 464dd9594b12c42ca5b81e93e87d9e752da801be. All 236 Flutter tests and both API 28/API 35 release startup tests passed. SHA256 18bd7fdfdaea11a7a2271a693731caaf848c0c70cc7321b8f0ab2df39e809b8c matched the uploaded Google bundle. Submitted to Production in run 42030316316; Google lifecycle IN_REVIEW.
- Physical Galaxy Note 8 testing was not performed. Emulator results must not be described as physical-device results.
- Application differences from the tested iOS source are limited to Android mandatory update enforcement. Catalog, preorder, order, customer and financial data were not modified.
- iOS public versions are polled from Apple's Korean listing. Android metadata requires Google's PUBLISHED lifecycle plus a completed full Production rollout. Uploads, internal tests and review-pending releases cannot activate the server fallback.
- Google API workflows must use concurrency group muhajeer-google-play-api. One service account may only have one open edit; even a temporary read edit must not overlap a publication edit.
- Older installed binaries without update logic cannot acquire it from server configuration. Play 1213 already checks Play Core, but its failure path cannot be retroactively hardened without installing a newer binary.
