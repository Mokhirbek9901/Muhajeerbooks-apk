import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// APNs token for the current physical iPhone/iPad; requires Apple Push
/// capability and an explicit notification grant on device.
class NativeAdminPush {
  static const _channel = MethodChannel('muhajeerbooks/admin_apns');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<String> requestDeviceToken() async {
    if (!supported) return '';
    final value = await _channel.invokeMethod<String>('getToken');
    return (value ?? '').trim().toLowerCase();
  }
}
