# Muhajeer Books — Free plan migration readiness (2026-10-16)

**STATUS: preparation only; NOT ready for production cutover.**

## Goals and non-negotiable checks

- Reduce recurring infrastructure subscription costs without losing books, customers, orders, sales, stock, receipt files, bot orders, push notifications or book-share links.
- Keep the existing Google Play and App Store builds working.
- Do not cancel Railway until the current web origin and server-side APIs have been replaced, tested and the existing public URLs accounted for.
- Do not downgrade Supabase until a current *external* database + Storage backup is verified and the **monthly Usage (Egress, Cached Egress, Edge Function invocations, Realtime and Storage)** is checked on the billing dashboard. Database size alone is insufficient.

## Verified on 2026-10-16

| Service | State | Notes |
|---|---|---|
| Supabase project | Healthy; org on Pro | `rytfhjvhjxnbhgitowho` |
| Database | 22,736,019 bytes | Under 500 MB Free limit |
| Storage objects | 1,163 files; 336,851,672 bytes | Under 1 GB Free limit |
| Edge Functions | 11 active | Check function requests and CORS on new origin |
| Railway `muhajeer-books-live` | Running | Web storefront, `/supabase` proxy, Python API, AI, push |
| Railway `muhajeerbooks-link` | Running | Android/iOS store link routing |
| Railway `muhajeerbooks_bot` | Running | Telegram bot polling, Supabase RPC, 500 MB mounted volume |
| Older preview/empty Railway services | No latest deployed build | Do not delete without usage/domain review |

**Do not mistake capacity for usage:** file sizes fit Free, but Supabase API/Storage **egress** is not available from the connector used for this audit. Confirm it on the dashboard.

## Dependencies blocking a $0 Railway switch

1. `lib/main.dart`: native clients talk to Supabase directly; current web talks to Railway origin `/supabase`. The opt-in `WEB_DIRECT_SUPABASE=true` switch on this branch only allows a *test build* to target Supabase directly.
2. Supabase Edge Functions `customer-rpc`, `admin-rpc` accept an allowlist of web origins; they are **not** ready for an arbitrary free static site origin. Update/test allowed origins and CORS only after a final static URL is chosen.
3. Web server `nginx.conf` routes `/api/ai*`, `/api/push/*`, `/kitob/*`, `/share/*`, `/supabase/*` and SEO files. Copying Flutter's `build/web` to free static hosting does not replace these routes.
4. `lib/admin_ui.dart` uses `https://muhajeer-books-live-production.up.railway.app` for API calls on mobile, so removing Railway would break related push/admin functions unless backend/API is moved and mobile builds updated.
5. Telegram bot needs a continuously running process or a safe replacement with webhooks/jobs. Railway autosleep **must not** be enabled for the polling bot.
6. `muhajeerbooks-link` URLs used in bios or QR codes need a verified permanent replacement before deletion.

## Safe preparation completed

- Separate prep-only GitHub branch: `prep/free-plan-transition-20261016`.
- Opt-in `WEB_DIRECT_SUPABASE` for static web builds. Normal production build behavior remains unchanged.
- GitHub Actions build-only workflow `.github/workflows/free_web_static_preview.yml`. It generates an artifact; **it does not deploy**.
- Two pending Railway configuration changes: optional autosleep for `muhajeer-books-live` and `muhajeerbooks-link`. These changes are **STAGED, NOT APPLIED**. Bot remains untouched.

## Manual operations required at billing dashboard

1. Open Supabase `https://supabase.com/dashboard/project/rytfhjvhjxnbhgitowho` and check **Usage** for the current billing cycle: Egress, Cached Egress, Storage, Edge Function requests and Realtime.
2. While on Pro, obtain database backup from **Database > Backups**, and export/download actual Storage objects separately. Keep both outside the public GitHub repo. Verify a restore/test.
3. Once verified, downgrade the only Supabase organization to **Free** via **Organization > Billing > Change subscription plan > Free**, if the projected usage is within limit. The billing owner must carry out the final billing action.
4. Supabase Free may pause if insufficient activity in 7 days; backups are not automatically available. Set up off-platform backup and availability checks.
5. Railway account usage, subscription tier and invoice must be inspected in billing dashboard; connected project API doesn't expose billing. The Free plan has **$1 monthly credit**, not enough for the current three always-on services at recent RAM usage. Do **not** downgrade before migrating and testing.
6. Only after the new static web host, CORS, share URLs, AI endpoints, push API and bot run mode pass smoke tests: deploy to a separate preview, then transition production, then consider Railway subscription changes.

## Acceptance checks before cutover

- [ ] Existing iOS and Android: browse book, search, view images, add to cart, place test order and check status
- [ ] Admin: login, stock editing, order/sales totals unchanged
- [ ] Telegram bot: new order reflected in app; order status and stock synchronized
- [ ] Push: new-order and shipping event, iOS/Android/web delivery
- [ ] AI: paid image endpoints still restricted to admin; no secret leaks
- [ ] Book share links and old published bio link both work
- [ ] Database backup and Storage restore rehearsal completed
- [ ] Free-tier traffic budget and alerts checked
- [ ] Customer production traffic rolled over and observed without errors before any server cancellation

## Rollback

Keep Railway running until the new host and backend are stable; normal production code and data remain unchanged by this prep branch. If a Supabase Free limit affects service, go back to Pro using the billing dashboard; do not delete or recreate the original project. Any subscription refund/credit treatment depends on current Supabase policy.

Documentation: https://supabase.com/docs/guides/platform/manage-your-subscription , https://supabase.com/pricing , https://docs.railway.com/pricing/plans , https://supabase.com/docs/guides/platform/free-project-pausing .
