# Android push activation

Android uses a native Firebase Messaging service and the `muhajeerbooks/android_fcm`
Flutter method channel. iOS retains its independent production APNs integration.

## Firebase configuration

1. Use the dedicated Firebase project `muhajeer-books-push`. Register the existing
   Android application ID `com.muhajeerbooks.app`; do not change its package or signing key.
2. Save that Android application's public `google-services.json` as
   `config/firebase-android.json`. This file must not contain a service account.
3. Enable Firebase Cloud Messaging HTTP v1. Put a dedicated, least-privilege FCM
   sender service account JSON in Railway's `FIREBASE_SERVICE_ACCOUNT_JSON` variable
   for `muhajeer-books-live`. Never commit or include that private JSON in an APK.
4. The sender project ID comes from that service account. It must match the Android
   configuration's project. No legacy FCM server key is used.
5. The Android config loader rejects JSON credentials and configs from other Firebase
   projects. Only the Firebase-generated **public** `google-services.json` for
   `com.muhajeerbooks.app` may be committed at `config/firebase-android.json`.
6. PIN-less customers register directly with `customer_release_fcm` using their
   durable `device:` credential. The Edge gateway validates the credential format;
   SQL checks its hash, active profile and exact installation. Do not wrap this
   operation in a short-lived PIN compatibility session.
7. For a sender limited strictly to messaging, create a project custom IAM role
   containing only `cloudmessaging.messages.create`, and bind it to a dedicated
   service account. Enable `fcm.googleapis.com`. Do not grant Owner, Editor,
   Firebase Admin, database access, or change the billing plan.
8. If the Work browser cannot sign in, an authorized project owner can use their
   already signed-in phone/computer browser to download the **Android public**
   `google-services.json`. That public app config may be shared for validation.
   The private sender JSON must go directly to Railway's
   `FIREBASE_SERVICE_ACCOUNT_JSON`, never chat, GitHub, an artifact or an APK.
   These steps still require authorized access to the Google project; no alternate
   transport bypasses that requirement.

`tools/prepare_android_fcm.py` runs after the analytics and biometric preparation
scripts. It adds the FCM dependency, non-exported messaging service, monochrome
notification icon, channel, tap routing and Firebase string resources. The Android
SDK stays uninitialized when configuration is absent; store build preparation uses
`--require-config` to prevent accidentally releasing that state.

## Identity and privacy

- Token registration uses `customer_release_fcm` with the active device credential
  and installation ID (older valid PIN sessions remain compatible). It does not trust a customer-supplied phone number.
- Customer recipients must have opted in and still have the matching active session.
  Order events additionally require ownership of that exact order; a second
  device with the same contact phone cannot receive it.
  Sign-out revokes the profile and clears its FCM authorization through a database
  trigger; token refresh re-enrolls on app resume.
- Admin registration requires the existing verified admin secret. Admin order details
  are never sent through the customer broadcast lookup.
- Customer order lock-screen messages contain generic status text, with an opaque
  order ID opened only after the app authenticates the customer.
- Foreground, background and cold-start notification taps are handled. Android's
  normal notification permission and Google Play services are required.

## Validation and release hold

`Android push compile check (no publication)` compiles the native service and Dart
bridge without uploading to Play. Python tests check recipient isolation, HTTP v1
payloads, error accounting and repeatable host generation. Flutter tests check that
Android tokens are not lowercased and the Android bridge is not used on iOS.

An existing installed APK cannot acquire this native SDK from a server update.
A new signed APK is required for a real Android device test. Do not trigger Play,
App Store, TestFlight or publication workflows without the owner's approval.


## Verification on 2026-10-30 (Korea time)

- Live database migration and rollback-only device/ownership/token-rotation/logout
  SQL integration test passed. Synthetic orders, receipts and inventory changes
  were rolled back. Customer RPC version 29 preserves JWT verification.
- Local mocked Python and web push regression tests passed. Android/Flutter
  checks run on PR #114 without publishing to any store.
- Railway was Online/SUCCESS and answered HTTP 200. No Firebase sender variable
  exists. The real public Android config, HTTP v1 enablement, sender IAM/key and
  real-device delivery remain unverified and block activation.
- PR #114 integrates the PIN-less work from PR #113 with the newer Android FCM
  and serialized web subscription persistence. It remains a draft until the
  configuration and device-delivery checks are complete.
