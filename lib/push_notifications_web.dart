import 'dart:js_interop';

@JS('muhajeerPushSupported')
external JSBoolean _pushSupported();

@JS('muhajeerEnablePush')
external JSPromise<JSBoolean> _enablePush();

@JS('muhajeerSyncPushPhone')
external JSPromise<JSBoolean> _syncPushPhone(JSString phone);

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

Future<bool> syncPushIdentity(String phone) async {
  try {
    return (await _syncPushPhone(phone.toJS).toDart).toDart;
  } catch (_) {
    return false;
  }
}
