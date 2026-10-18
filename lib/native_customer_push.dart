import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Android-only native Firebase Cloud Messaging transport.
///
/// These four Firebase Android app identifiers are public identifiers, but
/// they MUST come from the Firebase project registered for package
/// com.muhajeerbooks.app. Missing configuration disables this transport
/// rather than reporting "enabled" or risking an app startup failure.
class NativeCustomerPush {
  static const _apiKey = String.fromEnvironment('FCM_ANDROID_API_KEY');
  static const _appId = String.fromEnvironment('FCM_ANDROID_APP_ID');
  static const _senderId = String.fromEnvironment('FCM_SENDER_ID');
  static const _projectId = String.fromEnvironment('FCM_PROJECT_ID');

  static bool get supported => !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _apiKey.isNotEmpty && _appId.isNotEmpty &&
      _senderId.isNotEmpty && _projectId.isNotEmpty;

  static Future<void>? _startup;
  static StreamSubscription<String>? _refreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static void Function(RemoteMessage)? _onForeground;

  static Future<void> _initialize() {
    if (!supported) return Future.error(
      StateError('Android FCM configuration is missing'));
    return _startup ??= _initializeOnce().catchError((Object error) {
      _startup = null;
      throw error;
    });
  }

  static Future<void> _initializeOnce() async {
    await Firebase.initializeApp(options: const FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _senderId,
      projectId: _projectId,
    ));
  }

  static Future<bool> permissionGranted() async {
    if (!supported) return false;
    try {
      await _initialize();
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (error) {
      debugPrint('Android push permission status failed: ${error.runtimeType}');
      return false;
    }
  }

  /// Only call on explicit user action. Never show an OS permission prompt
  /// merely because a customer opens the app.
  static Future<String> requestToken() async {
    await _initialize();
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true, provisional: false);
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError('Bildirishnoma ruxsati berilmagan');
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Firebase qurilma tokenini olishning imkoni bo‘lmadi');
    }
    return token;
  }

  static Future<String> existingToken() async {
    if (!await permissionGranted()) return '';
    try {
      return await FirebaseMessaging.instance.getToken() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Show an in-app alert while the app is open. Android OS displays
  /// notification payloads when the app is backgrounded or closed.
  static Future<void> listenForeground(
      void Function(RemoteMessage) onMessage) async {
    if (!supported) return;
    _onForeground = onMessage;
    await _initialize();
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
      (message) => _onForeground?.call(message),
    );
  }

  static void listenForTokenRefresh(Future<void> Function(String) register) {
    if (!supported) return;
    _refreshSubscription?.cancel();
    _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => unawaited(register(token).catchError((Object error) {
        debugPrint('Android push token refresh failed: ${error.runtimeType}');
      })),
    );
  }
}
