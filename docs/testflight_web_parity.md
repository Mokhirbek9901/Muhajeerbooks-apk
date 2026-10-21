# Current web features in iOS TestFlight

The owner requested the full current web experience in TestFlight only. This
preview includes all source through web commit `9049e0a`, plus the platform
gates needed to make those features reachable on iOS. Production App Store and
Google Play submission workflows are not invoked.

## Features checked

- Catalog preorder card, linked out-of-stock preorders and the ₩4,000 postage note.
- Multi-book requests with independent titles/images/quantities and no three-book
  cap; aggregate advance, receipt upload, validation and idempotent submission.
- Remove/cancel/undo for books, images and receipts; leaving confirmation and
  return from bank-payment details without losing the draft.
- Admin preorder settings, acceptance/cancellation/arrival/reopening, notes,
  status version checks, event inbox, customer notifications, search/pagination.
- Confirmed sold-copy count beneath the author, historical count matching,
  explanation dialog, retry without fabricated zero.
- Corrected customer/source statistics and registered-customer lists.
- Catalog filter sheet, reset-all filters, gallery problem filters.
- Local saved addresses, receipt-first checkout, cart information,
  recommendations based only on the current customer's orders.
- Admin daily tasks, business tools, batch history/cost tools and packing check.
- Existing shared financial reports, inventory/profit terminology, yesterday
  filters, Korean/local timestamp display, catalog/navigation, reviews, stories
  and owner-only story exports remain in the same source tree.

`webPreviewFeaturesAvailable` is true only on web or when iOS is compiled with
`TESTFLIGHT_PREVIEW=true`. The upload build also sets `APP_STORE_BUILD=true` for
the previously established enhanced customer/admin/finance functionality.
Android and ordinary native builds do not gain these preview-only features.

## Platform integrations retained

Browser-only APIs still use `kIsWeb`: same-origin Supabase proxy, browser history
and deep links, PWA shell, web push, browser passkeys and browser image downloads.
iOS keeps direct Supabase access, native APNs, native Face ID/biometrics and the
iOS share/save sheet. These are platform equivalents rather than missing product
features. Desktop layout thresholds remain responsive platform layout choices.

## Validation/release boundary

Flutter CI runs the full suite both normally and with both preview build flags.
The native iOS route test verifies that the customer actually reaches the
multi-book form and can remove/undo an extra book. Existing preorder, sales
counter and Korean timestamp tests run with the same build flags before IPA
creation. The signed IPA is uploaded to TestFlight and Apple processing must
report `VALID`. App Store Review submission is absent from the upload workflow.

Railway's current deployment outage blocks publishing the web frontend but does
not block this GitHub-hosted iOS build. Its Supabase preorder/count endpoints
are already live; existing Railway runtime APIs remain the backend for AI/push.
