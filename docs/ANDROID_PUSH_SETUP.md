# Android push activation

Android uses a native Firebase Messaging service and the `muhajeerbooks/android_fcm`
Flutter method channel. iOS retains its independent production APNs integration.

## Firebase configuration

1. Use the Firebase project associated with Muhajeer Books. Register the existing
   Android application ID `com.muhajeerbooks.app`; do not change its package or signing key.
2. Save that Android application's public `google-services.json` as
   `config/firebase-android.json`. This file must not contain a service account.
3. Enable Firebase Cloud Messaging HTTP v1. Put a dedicated, least-privilege FCM
   sender service account JSON in Railway's `FIREBASE_SERVICE_ACCOUNT_JSON` variable
   for `muhajeer-books-live`. Never commit or include that private JSON in an APK.
4. The sender project ID comes from that service account. It must match the Android
   configuration's project. No legacy FCM server key is used.

`tools/prepare_android_fcm.py` runs after the analytics and biometric preparation
scripts. It adds the FCM dependency, non-exported messaging service, monochrome
notification icon, channel, tap routing and Firebase string resources. The Android
SDK stays uninitialized when configuration is absent; store build preparation uses
`--require-config` to prevent accidentally releasing that state.

## Identity and privacy

- Token registration uses `customer_release_fcm` with the current PIN session and
  installation ID. It does not trust a customer-supplied phone number.
- Customer recipients must have opted in and still have the matching active session.
  Sign-out removes customer push authorization; token refresh re-enrolls on app resume.
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
