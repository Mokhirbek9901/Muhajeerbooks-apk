import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/web_preorders.dart';

class MultiApi extends WebPreorderApi {
  int uploads = 0, attempts = 0;
  bool fail = false;
  Map<String, dynamic>? request;
  WebPreorderConfig settings = const WebPreorderConfig(enabled: true, arrival: '5-noyabr', deposit: 5000);
  @override
  Future<WebPreorderConfig> config() async => settings;
  @override
  Future<String> upload(String id, String kind, Uint8List bytes, int revision, {String? bookId, String? termsToken}) async {
    uploads++;
    return '$id/$kind-$uploads.jpg';
  }
  @override
  Future<dynamic> call(String action, [Map<String, dynamic> params = const {}]) async {
    expect(action, 'submit_multi');
    attempts++;
    request = Map<String, dynamic>.from(params['p_request'] as Map);
    if (fail) throw StateError('Vaqtincha xato');
    return {'id': request!['id'], 'status': 'waiting'};
  }
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> mount(WidgetTester tester, MultiApi api) async {
  SharedPreferences.setMockInitialValues({});
  final image = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => AppState(backendConfigured: false),
    child: MaterialApp(home: WebMultiPreorderPage(api: api, pickImage: () async => image)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('five book types remain independent and total advance includes every book', (tester) async {
    final api = MultiApi();
    await mount(tester, api);
    for (var i = 1; i <= 5; i++) {
      final field = find.widgetWithText(TextFormField, '$i-kitob nomi');
      await reveal(tester, field);
      await tester.enterText(field, 'Kitob $i');
      if (i < 5) {
        await reveal(tester, find.text('Yana kitob qo‘shish'));
        await tester.tap(find.text('Yana kitob qo‘shish'));
        await tester.pumpAndSettle();
      }
    }
    await reveal(tester, find.text('5 turdagi kitob • 5 dona'));
    expect(find.text('Jami avans: ₩25,000'), findsOneWidget);
    expect(api.attempts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancel an added book and undo restores its title and correct total', (tester) async {
    final api = MultiApi();
    await mount(tester, api);
    await tester.enterText(find.widgetWithText(TextFormField, '1-kitob nomi'), 'Birinchi kitob');
    await reveal(tester, find.text('Yana kitob qo‘shish'));
    await tester.tap(find.text('Yana kitob qo‘shish'));
    await tester.pumpAndSettle();
    await reveal(tester, find.widgetWithText(TextFormField, '2-kitob nomi'));
    await tester.enterText(find.widgetWithText(TextFormField, '2-kitob nomi'), 'Ikkinchi kitob');
    await tester.tap(find.text('Bekor qilish').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '2-kitob nomi'), findsNothing);
    await reveal(tester, find.text('1 turdagi kitob • 1 dona'));
    expect(find.text('Jami avans: ₩5,000'), findsOneWidget);
    // Recreate the undo promptly so it is independent of reveal's scroll duration.
    await tester.tap(find.text('Qaytarish'));
    await tester.pumpAndSettle();
    await reveal(tester, find.widgetWithText(TextFormField, '2-kitob nomi'));
    expect((tester.widget<TextFormField>(find.widgetWithText(TextFormField, '2-kitob nomi')).controller!).text, 'Ikkinchi kitob');
    await reveal(tester, find.text('2 turdagi kitob • 2 dona'));
    expect(find.text('Jami avans: ₩10,000'), findsOneWidget);
    expect(api.attempts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancel image can be undone and leaving can be declined without losing draft', (tester) async {
    final api = MultiApi();
    await mount(tester, api);
    await tester.enterText(find.widgetWithText(TextFormField, '1-kitob nomi'), 'Saqlangan nom');
    await reveal(tester, find.text('Kitob rasmini yuklash'));
    await tester.tap(find.text('Kitob rasmini yuklash'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Rasmni bekor qilish'));
    await tester.tap(find.text('Rasmni bekor qilish'));
    await tester.pumpAndSettle();
    expect(find.text('Rasmni almashtirish'), findsNothing);
    await tester.tap(find.text('Qaytarish'));
    await tester.pumpAndSettle();
    expect(find.text('Rasmni almashtirish'), findsOneWidget);
    await reveal(tester, find.text('Buyurtmani bekor qilish'));
    await tester.tap(find.text('Buyurtmani bekor qilish'));
    await tester.pumpAndSettle();
    expect(find.text('Buyurtmadan chiqasizmi?'), findsOneWidget);
    await tester.tap(find.text('Davom etish'));
    await tester.pumpAndSettle();
    await reveal(tester, find.widgetWithText(TextFormField, '1-kitob nomi'));
    expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, '1-kitob nomi')).controller!.text, 'Saqlangan nom');
    expect(api.attempts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty title scrolled out of view still blocks payment', (tester) async {
    final api = MultiApi();
    await mount(tester, api);
    for (var i = 0; i < 5; i++) {
      await reveal(tester, find.text('Yana kitob qo‘shish'));
      await tester.tap(find.text('Yana kitob qo‘shish'));
      await tester.pumpAndSettle();
    }
    await reveal(tester, find.text('Shartlarni ko‘rdim — to‘lovga o‘tish'));
    await tester.tap(find.text('Shartlarni ko‘rdim — to‘lovga o‘tish'));
    await tester.pumpAndSettle();
    expect(find.text('1-kitob nomini kiriting.'), findsOneWidget);
    expect(find.text('Bank o‘tkazmasi'), findsNothing);
    expect(api.attempts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('all book images required before showing payment instructions', (tester) async {
    final api = MultiApi();
    await mount(tester, api);
    await tester.enterText(find.widgetWithText(TextFormField, '1-kitob nomi'), 'Kitob A');
    await reveal(tester, find.widgetWithText(TextFormField, 'Ismingiz'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Ismingiz'), 'Test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Telefon raqam'), '01000000000');
    await reveal(tester, find.text('Shartlarni ko‘rdim — to‘lovga o‘tish'));
    await tester.tap(find.text('Shartlarni ko‘rdim — to‘lovga o‘tish'));
    await tester.pumpAndSettle();
    expect(find.text('1-kitob rasmini tanlang.'), findsOneWidget);
    expect(find.text('Bank o‘tkazmasi'), findsNothing);
    expect(api.uploads, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('one receipt submits both titles and images and retry reuses the same request', (tester) async {
    final api = MultiApi()..fail = true;
    await mount(tester, api);
    for (var i = 1; i <= 2; i++) {
      await reveal(tester, find.widgetWithText(TextFormField, '$i-kitob nomi'));
      await tester.enterText(find.widgetWithText(TextFormField, '$i-kitob nomi'), 'Kitob $i');
      await reveal(tester, find.text('Kitob rasmini yuklash').last);
      await tester.tap(find.text('Kitob rasmini yuklash').last);
      await tester.pumpAndSettle();
      if (i == 1) {
        await reveal(tester, find.text('Yana kitob qo‘shish'));
        await tester.tap(find.text('Yana kitob qo‘shish'));
        await tester.pumpAndSettle();
      }
    }
    await reveal(tester, find.widgetWithText(TextFormField, 'Ismingiz'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Ismingiz'), 'Test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Telefon raqam'), '01000000000');
    await reveal(tester, find.text('Shartlarni ko‘rdim — to‘lovga o‘tish'));
    await tester.tap(find.text('Shartlarni ko‘rdim — to‘lovga o‘tish'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('O‘tkaziladigan summa: ₩10,000'));
    expect(find.text('O‘tkaziladigan summa: ₩10,000'), findsOneWidget);
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    expect(find.text('Bank o‘tkazmasi'), findsNothing);
    await reveal(tester, find.text('Shartlarni ko‘rdim — to‘lovga o‘tish'));
    await tester.tap(find.text('Shartlarni ko‘rdim — to‘lovga o‘tish'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Avans chekini yuklash'));
    await tester.tap(find.text('Avans chekini yuklash'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Chekni bekor qilish'));
    await tester.tap(find.text('Chekni bekor qilish'));
    await tester.pumpAndSettle();
    expect(find.text('Chekni almashtirish'), findsNothing);
    await tester.tap(find.text('Qaytarish'));
    await tester.pumpAndSettle();
    expect(find.text('Chekni almashtirish'), findsOneWidget);
    await reveal(tester, find.text('Avans yubordim — buyurtma berish'));
    await tester.tap(find.text('Avans yubordim — buyurtma berish'));
    await tester.pumpAndSettle();
    expect(api.uploads, 3);
    expect(api.request!['deposit_amount'], 10000);
    expect((api.request!['items'] as List).map((b) => b['book_title']), ['Kitob 1', 'Kitob 2']);
    final id = api.request!['id'];
    api.fail = false;
    await tester.tap(find.text('Avans yubordim — buyurtma berish'));
    await tester.pumpAndSettle();
    expect(api.uploads, 3);
    expect(api.attempts, 2);
    expect(api.request!['id'], id);
    expect(find.text('Oldindan buyurtma yuborildi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
