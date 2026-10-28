import 'package:flutter/services.dart';

/// The same tested iOS binary can later ship publicly. Never bake tester
/// analytics into that binary; unknown distribution is left uncounted.
Future<String?> iosInstallationPlatform() async {
  try {
    final result = await const MethodChannel('muhajeerbooks/admin_apns')
        .invokeMethod<String>('getStoreDistribution')
        .timeout(const Duration(seconds: 5));
    if (result == 'production') return 'ios_app_store';
    if (result == 'sandbox') return 'ios_testflight';
  } catch (_) {}
  return null;
}
