import 'dart:js_interop';

@JS('muhajeerPushSupported')
external JSBoolean _pushSupported();

@JS('muhajeerEnablePush')
external JSPromise<JSBoolean> _enablePush();

bool get pushNotificationsSupported {
  try {
    return _pushSupported().toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> enablePushNotifications() async {
  try {
    return (await _enablePush().toDart).toDart;
  } catch (_) {
    return false;
  }
}
