import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_startup.dart';

void main() {
  testWidgets('storage plugin failure shows retry instead of a blank launch', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(AppStartup(initialize: () async {
      if (++attempts == 1) throw PlatformException(code: 'channel-error');
    }, app: const MaterialApp(home: Text('Store ready'))));
    await tester.pumpAndSettle();
    expect(find.text('Qayta urinish'), findsOneWidget);
    await tester.tap(find.text('Qayta urinish'));
    await tester.pumpAndSettle();
    expect(find.text('Store ready'), findsOneWidget);
    expect(attempts, 2);
  });
  testWidgets('slow initialization stays visible, retry cannot overlap SDK startup', (tester) async {
    final pending = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(AppStartup(timeout: const Duration(seconds: 1),
      initialize: () { attempts++; return pending.future; },
      app: const MaterialApp(home: Text('Store ready'))));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Qayta urinish'), findsOneWidget);
    await tester.tap(find.text('Qayta urinish'));
    await tester.pump();
    expect(attempts, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Store ready'), findsOneWidget);
  });
}
