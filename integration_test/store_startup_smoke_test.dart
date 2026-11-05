import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/main.dart' as app;
import 'package:muhajeerbooks/fast_store_shell.dart';
import 'package:muhajeerbooks/app_startup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('release startup: real preferences channel, catalog and resume', (tester) async {
    expect(kReleaseMode, isTrue, reason: 'This check must exercise the release binary');
    // Exercise recovery on the actual release engine before loading the store.
    var attempts = 0;
    await tester.pumpWidget(AppStartup(initialize: () async {
      if (++attempts == 1) throw StateError('simulated unavailable server');
    }, app: const MaterialApp(home: Text('Recovered'))));
    await tester.pumpAndSettle();
    expect(find.text('Qayta urinish'), findsOneWidget);
    await tester.tap(find.text('Qayta urinish'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
    final stalled = Completer<void>();
    await tester.pumpWidget(AppStartup(key: const ValueKey('slow'),
      timeout: const Duration(seconds: 1), initialize: () => stalled.future,
      app: const MaterialApp(home: Text('Connected'))));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Qayta urinish'), findsOneWidget);
    stalled.complete();
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
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
    // ADB runner accepts success only after every assertion above.
    // ignore: avoid_print
    print('MB_RELEASE_STARTUP_SMOKE_PASSED');
  });
}
