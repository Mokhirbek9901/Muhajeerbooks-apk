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
    await reveal(tester, find.text('Avans chekini yuklash'));
    await tester.tap(find.text('Avans chekini yuklash'));
    await tester.pumpAndSettle();
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
