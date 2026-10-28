import 'package:flutter/foundation.dart';

/// Current web product features are also available in the explicitly built
/// iOS TestFlight preview. This never enables Android or a normal store build.
/// Keep browser APIs (URLs, web push, passkeys, downloads) on kIsWeb and use
/// their existing native equivalents on iOS.
bool get iosTestFlightPreview => !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS &&
    const bool.fromEnvironment('TESTFLIGHT_PREVIEW');

bool get nativeStoreFeaturesEnabled => !kIsWeb &&
    const bool.fromEnvironment('STORE_FEATURES');

bool get webPreviewFeaturesAvailable => kIsWeb || iosTestFlightPreview || nativeStoreFeaturesEnabled;
