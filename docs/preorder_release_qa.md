# Preorder QA, 22 October 2026 (Korea)

Scope: customer catalog requests, linked sold-out book requests, admin status lifecycle and customer inbox. Public App Store and Google Play releases remain disabled; new code is for web source and iOS TestFlight validation.

## Fixed

- Linked requests validate all controllers before showing bank details, even when Form fields have scrolled out of the ListView.
- Bank payment Back returns to editing and retains the draft/receipt. Exiting a dirty request requires a confirmation. Receipt/image removal supports undo.
- Image selection locks navigation, editing and submission until it finishes; input images are resized before upload.
- A successful server submission stays successful if local profile persistence fails; completed requests cannot be resubmitted.
- Retrying an unsuccessful submission reuses its id and receipt upload. No extra payment is requested.
- Linked payment also explains the additional shipping fee, while the bank amount stays equal to the advance alone.
- Multi-request exit protection also covers contact-only edits; aggregate limits are checked before exposing payment instructions.

## Server verification

Existing linked and multi-book SQL integration fixtures passed against current functions. Each fixture rolls back all its rows, auth stub and transactional HTTP queue writes; existing order counts, request counts and auth function definitions were verified unchanged by the fixture assertions. Tests cover stale terms, invalid advance, reused receipts, idempotency, private admin access, status conflicts, accept/arrive/cancel/reopen, inbox creation and push retry/no-permission fallback.

Five Python notification delivery tests passed with mocked recipients/network. Read-only aggregate audit found no duplicate receipt paths, missing event inbox messages, failed/pending preorder deliveries or enabled book preorders without an arrival note. These results are a snapshot, not a guarantee about future network delivery.

## Remaining release gate

Run the full Flutter suite in ordinary and TestFlight mode and verify the signed TestFlight upload. Owner should exercise the new build on a physical device with its real photo picker and confirm bank receipt/status UX. No real bank transfer is required for automated testing.

Railway has been blocking new web deployments. Source/CI changes are not proof that the web frontend or server has deployed. Verify the actual live deployment before stating web is updated. Native closed-app push delivery is outside these web-push unit tests; the transactional customer inbox is verified separately.
