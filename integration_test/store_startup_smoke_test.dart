import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/main.dart' as app;
import 'package:muhajeerbooks/fast_store_shell.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('release startup: real preferences channel, catalog and resume', (tester) async {
    // Exercises the Pigeon method that failed in the older R8 release.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qa:startup-probe', 'ok');
    expect(prefs.getString('qa:startup-probe'), 'ok');
    await prefs.remove('qa:startup-probe');
    await app.main();
    for (var i = 0; i < 120 && find.byType(FastStoreShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(FastStoreShell), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(FastStoreShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
