import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/preview_features.dart';
import 'package:muhajeerbooks/web_preorders.dart';
import 'package:muhajeerbooks/store_ui.dart';
import 'package:muhajeerbooks/purchase_price_notice.dart';

class PreviewCart extends AppState {
  PreviewCart() : super(backendConfigured: false);
  static const book = Book(id: 'preview', title: 'Sinov kitobi', author: 'Muallif',
      category: 'Kitob', description: '', price: 21000, stock: 3,
      discountPercent: 0, imageUrl: '', isActive: true);
  @override
  List<CartLine> get cartLines => const [CartLine(book: book, quantity: 1)];
  @override
  List<CartLine> get cartStandaloneLines => cartLines;
}

class PreviewPreorders extends WebPreorderApi {
  @override
  Future<WebPreorderConfig> config() async => const WebPreorderConfig(
    enabled: true, arrival: '25–28-oktabr', deposit: 10000,
  );
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('iOS preview retains the currency explanation from cart through checkout', (tester) async {
    if (!const bool.fromEnvironment('TESTFLIGHT_PREVIEW') && !const bool.fromEnvironment('STORE_FEATURES')) return;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      previousErrorHandler?.call(details);
    };
    try {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ChangeNotifierProvider<AppState>(
        create: (_) => PreviewCart(),
        child: const MaterialApp(home: CartPage()),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(PurchasePriceNotice));
      await tester.pumpAndSettle();
      expect(find.text(purchasePriceExplanation), findsOneWidget);
      await tester.ensureVisible(find.text('Buyurtmani rasmiylashtirish'));
      await tester.tap(find.text('Buyurtmani rasmiylashtirish'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(find.text(purchasePriceExplanation), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      FlutterError.onError = previousErrorHandler;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('full features require web, explicit TestFlight or explicit store flag', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(webPreviewFeaturesAvailable, kIsWeb ||
          const bool.fromEnvironment('STORE_FEATURES') ||
          (platform == TargetPlatform.iOS &&
              const bool.fromEnvironment('TESTFLIGHT_PREVIEW')));
    }
  });

  testWidgets('iOS preview routes to the current multi-book form with remove and undo', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(backendConfigured: false),
      child: MaterialApp(home: WebPreorderPage(api: PreviewPreorders())),
    ));
    await tester.pumpAndSettle();
    final preview = kIsWeb || const bool.fromEnvironment('TESTFLIGHT_PREVIEW') || const bool.fromEnvironment('STORE_FEATURES');
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
    } finally {
      await tester.pumpWidget(const SizedBox());
      // Widget binding checks this before package-level tearDown callbacks.
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
