import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/catalog_resume.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reset only after more than five minutes outside the app', () async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime(2026, 9, 12);
    final session = CatalogResume(now: () => now);
    await session.initialize();
    var resets = 0;
    session.addListener(() => resets++);
    session.didChangeAppLifecycleState(AppLifecycleState.hidden);
    now = now.add(const Duration(minutes: 5));
    session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resets, 0);
    session.didChangeAppLifecycleState(AppLifecycleState.hidden);
    now = now.add(const Duration(minutes: 4));
    session.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resets, 1);
    session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resets, 1);
    session.dispose();
  });

  test('temporary loss of focus does not count as leaving', () async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime(2026, 9, 12);
    final session = CatalogResume(now: () => now);
    await session.initialize();
    var resets = 0;
    session.addListener(() => resets++);
    session.didChangeAppLifecycleState(AppLifecycleState.inactive);
    now = now.add(const Duration(minutes: 10));
    session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resets, 0);
    session.dispose();
  });

  test('cold restart expires scroll only and preserves customer data', () async {
    final now = DateTime(2026, 9, 12);
    for (final minutes in [4, 6]) {
      SharedPreferences.setMockInitialValues({
        CatalogResume.awayKey:
            now.subtract(Duration(minutes: minutes)).millisecondsSinceEpoch,
        'scroll:home': 1200.0,
        'customer': 'kept',
      });
      final session = CatalogResume(now: () => now);
      await session.initialize();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('scroll:home'), minutes == 4 ? 1200.0 : null);
      expect(prefs.getString('customer'), 'kept');
      session.dispose();
    }
  });
}
