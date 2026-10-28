import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/store_distribution.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('muhajeerbooks/admin_apns');
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  for (final entry in {'sandbox':'ios_testflight', 'production':'ios_app_store', 'unknown':null}.entries) {
    test('same iOS candidate reports ${entry.key} at runtime', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async => entry.key);
      expect(await iosInstallationPlatform(), entry.value);
    });
  }
}
