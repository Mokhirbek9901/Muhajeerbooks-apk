import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only native Firebase bridge; iOS continues using its APNs channel.
class NativeAndroidPush {
  static const _channel = MethodChannel('muhajeerbooks/android_fcm');
  static final _tokens = StreamController<void>.broadcast();
  static final _taps = StreamController<Map<String, String>>.broadcast();
  static bool _initialized = false;
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Stream<void> get tokenChanges { _initialize(); return _tokens.stream; }
  static Stream<Map<String, String>> get notificationTaps { _initialize(); return _taps.stream; }

  static void _initialize() {
    if (_initialized || !supported) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'tokenUpdated') _tokens.add(null);
      if (call.method == 'notificationTapped' && call.arguments is Map) {
        _taps.add(_message(call.arguments as Map));
      }
    });
  }

  static Map<String, String> _message(Map value) => value.map(
      (key, value) => MapEntry('$key', '$value'));

  static Future<String> deviceToken() async {
    if (!supported) return '';
    _initialize();
    return (await _channel.invokeMethod<String>('getToken') ?? '').trim();
  }

  static Future<Map<String, String>?> pendingNotification() async {
    if (!supported) return null;
    _initialize();
    final value = await _channel.invokeMapMethod<String, String>('getPendingNotification');
    return value == null ? null : Map<String, String>.from(value);
  }
}
