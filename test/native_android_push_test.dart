import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/native_android_push.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('muhajeerbooks/android_fcm');
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('FCM tokens retain case and punctuation and pending taps retain routing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'getToken') return 'AA_case-Sensitive:bb';
      return {'kind': 'customer_order', 'order_id': 'opaque-order-id'};
    });
    expect(await NativeAndroidPush.deviceToken(), 'AA_case-Sensitive:bb');
    expect(await NativeAndroidPush.pendingNotification(),
        {'kind': 'customer_order', 'order_id': 'opaque-order-id'});
    expect(calls, ['getToken', 'getPendingNotification']);
  });

  test('FCM bridge never invokes Android channels on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => fail('Android channel used on iOS'));
    expect(await NativeAndroidPush.deviceToken(), isEmpty);
    expect(await NativeAndroidPush.pendingNotification(), isNull);
  });
}
