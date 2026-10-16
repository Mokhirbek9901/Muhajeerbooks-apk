# Server-driven app settings

Muhajeer Books uses Supabase for data that should change without a new App Store / Play Store binary.

## Already server-driven

- catalog, book descriptions, prices, stock and discounts
- orders and order statuses
- store notices / push history
- preorder and restock data
- finance and admin data

## Remote config

The installed app now also reads non-executable settings from `public.app_remote_config`
through the `customer_app_config()` RPC.

This is intentionally limited to data, copy and feature switches for capabilities that
already exist in the installed build. It must not be used to download or execute new
code or to bypass App Store review for a genuinely new native capability.

Initial keys:

- `config.refresh_minutes`
- `features.muhajeer_ai_enabled`
- `features.preorder_enabled`
- `features.reviews_enabled`
- `features.restock_enabled`
- `features.story_share_enabled`
- `ui.notification_permission_title`
- `ui.notification_permission_body`
- `ui.notification_permission_allow`
- `ui.notification_permission_later`
- `ui.home_announcement_enabled`
- `ui.home_announcement_title`
- `ui.home_announcement_body`
- `release.ios_store_url`
- `release.android_store_url`

The app caches the last successful config locally, uses safe built-in defaults when
offline, refreshes periodically, and refreshes again after the app returns to the
foreground.

## Operational rule

Prefer changing Supabase data/config for catalog, copy, visibility and operational
settings. Ship a new native store version only when the installed binary actually
needs new code, SDK/permission changes, a new native screen/capability, or a bug fix
that cannot be expressed by existing server-driven behavior.
