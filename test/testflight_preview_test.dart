import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/preview_features.dart';
import 'package:muhajeerbooks/web_preorders.dart';

class PreviewPreorders extends WebPreorderApi {
  @override
  Future<WebPreorderConfig> config() async => const WebPreorderConfig(
    enabled: true, arrival: '25–28-oktabr', deposit: 10000,
  );
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('web preview is limited to explicit iOS TestFlight builds', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(webPreviewFeaturesAvailable, kIsWeb ||
          (platform == TargetPlatform.iOS &&
              const bool.fromEnvironment('TESTFLIGHT_PREVIEW')));
    }
  });

  testWidgets('iOS preview routes to the current multi-book form with remove and undo', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(backendConfigured: false),
      child: MaterialApp(home: WebPreorderPage(api: PreviewPreorders())),
    ));
    await tester.pumpAndSettle();
    final preview = kIsWeb || const bool.fromEnvironment('TESTFLIGHT_PREVIEW');
    expect(find.byType(WebMultiPreorderPage), preview ? findsOneWidget : findsNothing);
    if (preview) {
      await tester.scrollUntilVisible(find.text('Yana kitob qo‘shish'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Yana kitob qo‘shish'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('2-kitob'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('2-kitob'), findsOneWidget);
      await tester.ensureVisible(find.text('Bekor qilish').last);
      await tester.tap(find.text('Bekor qilish').last);
      await tester.pumpAndSettle();
      expect(find.text('2-kitob'), findsNothing);
      await tester.tap(find.text('Qaytarish'));
      await tester.pumpAndSettle();
      expect(find.text('2-kitob'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
