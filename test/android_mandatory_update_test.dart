import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:muhajeerbooks/app_update_gate.dart';
import 'package:muhajeerbooks/remote_config.dart';

class ReleaseConfig extends RemoteConfigStore {
  ReleaseConfig(this.values) : super(backendConfigured: false);
  final Map<String, dynamic> values;
  @override
  Future<void> refresh({bool force = false}) async {}
  @override
  bool boolValue(String key, {bool fallback = false}) =>
      values[key] as bool? ?? super.boolValue(key, fallback: fallback);
  @override
  int intValue(String key, {int fallback = 0}) =>
      values[key] as int? ?? super.intValue(key, fallback: fallback);
  @override
  String stringValue(String key, {String fallback = ''}) =>
      values[key] as String? ?? super.stringValue(key, fallback: fallback);
}

class StoreLauncher extends UrlLauncherPlatform {
  String? opened;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened = url;
    return true;
  }
}

void main() {
  if (!const bool.fromEnvironment('PLAY_STORE_BUILD')) {
    test('mandatory Android gate is tested with PLAY_STORE_BUILD=true', () {},
      skip: 'Run the Play release test configuration');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  const playChannel = MethodChannel('de.ffuf.in_app_update/methods');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late StoreLauncher launcher;
  late UrlLauncherPlatform originalLauncher;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    PackageInfo.setMockInitialValues(appName: 'Muhajeer Books',
      packageName: 'com.muhajeerbooks.app', version: '2.5.26',
      buildNumber: '1215', buildSignature: '');
    originalLauncher = UrlLauncherPlatform.instance;
    launcher = StoreLauncher();
    UrlLauncherPlatform.instance = launcher;
    messenger.setMockMethodCallHandler(playChannel, (_) async {
      throw PlatformException(code: 'PLAY_UNAVAILABLE');
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    UrlLauncherPlatform.instance = originalLauncher;
    messenger.setMockMethodCallHandler(playChannel, null);
  });

  Future<void> show(WidgetTester tester, Map<String, dynamic> values) async {
    final remote = ReleaseConfig(values);
    addTearDown(remote.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<RemoteConfigStore>.value(
      value: remote, child: const MaterialApp(home: AppUpdateGate(
        child: Scaffold(body: Text('Book catalog'))))));
    await tester.pumpAndSettle();
  }

  final publicRelease = <String, dynamic>{
    'release.android_published_available': true,
    'release.android_published_version': '2.5.27',
    'release.android_published_build': 1216,
  };

  testWidgets('verified public release survives Play errors and cannot be dismissed', (tester) async {
    await show(tester, publicRelease);
    expect(find.text('Yangilanish kerak'), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Yangilanish kerak'), findsOneWidget);
    await tester.tap(find.text('Yangilash'));
    await tester.pumpAndSettle();
    expect(launcher.opened, 'https://play.google.com/store/apps/details?id=com.muhajeerbooks.app');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Yangilanish kerak'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending or internal release never blocks a customer', (tester) async {
    await show(tester, {...publicRelease, 'release.android_published_available': false});
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final publishedCode in [1215, 1214]) {
    testWidgets('current or newer tester build is not forced to code $publishedCode', (tester) async {
      await show(tester, {...publicRelease, 'release.android_published_build': publishedCode});
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Play device-specific available update uses the same one-button gate', (tester) async {
    messenger.setMockMethodCallHandler(playChannel, (call) async {
      expect(call.method, 'checkForUpdate');
      return <String, dynamic>{'updateAvailability': 2, 'immediateAllowed': true,
        'flexibleAllowed': true, 'availableVersionCode': 1216, 'installStatus': 0,
        'packageName': 'com.muhajeerbooks.app', 'updatePriority': 5};
    });
    await show(tester, {});
    expect(find.text('Yangilanish kerak'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('slow Play response times out into the verified public gate', (tester) async {
    final pending = Completer<dynamic>();
    messenger.setMockMethodCallHandler(playChannel, (_) => pending.future);
    await show(tester, publicRelease);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.text('Yangilanish kerak'), findsOneWidget);
    pending.complete(null);
    await tester.pumpWidget(const SizedBox());
  });
}
