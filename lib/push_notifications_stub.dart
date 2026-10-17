bool get pushNotificationsSupported => false;

Future<bool> enablePushNotifications() async => false;
Future<bool> syncPushIdentity(String phone) async => false;

/// Native APNs/FCM requires a separate mobile push integration.
Future<String> existingWebPushEndpoint() async => '';

String pushNotificationPermissionStatusSync() => 'unsupported';
