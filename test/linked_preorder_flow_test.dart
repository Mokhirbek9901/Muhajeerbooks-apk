import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/web_preorders.dart';

const nextLabel = 'Shartlarni ko‘rdim — to‘lovga o‘tish';
const submitLabel = 'Avans yubordim — buyurtma berish';

class LinkedApi extends WebPreorderApi {
  WebPreorderConfig settings = const WebPreorderConfig(enabled: true,
    bookId: '12345678-1234-4234-8234-123456789abc', bookTitle: 'Sinov kitobi',
    arrival: '5-noyabr', deposit: 5000, depositMax: 10000, termsToken: 'first');
  int uploads = 0, attempts = 0;
  bool fail = false;
  Map<String, dynamic>? request;
  @override
  Future<WebPreorderConfig> bookConfig(String id) async => settings;
  @override
  Future<String> upload(String id, String kind, Uint8List bytes, int revision,
      {String? bookId, String? termsToken}) async {
    expect(kind, 'proof');
    expect(bookId, settings.bookId);
    expect(termsToken, settings.termsToken);
    uploads++;
    return '$id/proof.jpg';
  }
  @override
  Future<dynamic> call(String action, [Map<String, dynamic> params = const {}]) async {
    expect(action, 'submit');
    attempts++;
    request = Map<String, dynamic>.from(params['p_request'] as Map);
    if (fail) throw StateError('Aloqa uzildi');
    return {'id': request!['id'], 'status': 'waiting'};
  }
}

class BrokenProfileStorage extends AppState {
  BrokenProfileStorage() : super(backendConfigured: false);
  @override
  Future<void> setAuthenticatedCustomer(String name, String phone,
      {String? address, bool verified = true}) async => throw StateError('Local storage unavailable');
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> mount(WidgetTester tester, LinkedApi api,
    {AppState? state, Future<Uint8List?> Function()? pick}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final image = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
  await tester.pumpWidget(ChangeNotifierProvider<AppState>(
    create: (_) => state ?? AppState(backendConfigured: false),
    child: MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => WebPreorderPage(api: api,
          book: Book.fromMap({'id': api.settings.bookId, 'title': 'Sinov kitobi'}),
          pickImage: pick ?? () async => image))), child: const Text('Sinov katalogi'))))),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sinov katalogi'));
  await tester.pumpAndSettle();
}

Future<void> customer(WidgetTester tester) async {
  final name = find.widgetWithText(TextFormField, 'Ismingiz');
  await reveal(tester, name);
  await tester.enterText(name, 'Sinov Mijoz');
  final phone = find.widgetWithText(TextFormField, 'Telefon raqam');
  await reveal(tester, phone);
  await tester.enterText(phone, '01000000000');
}

Future<void> pay(WidgetTester tester) async {
  await customer(tester);
  await reveal(tester, find.text(nextLabel));
  await tester.tap(find.text(nextLabel));
  await tester.pumpAndSettle();
  await reveal(tester, find.text('Avans chekini yuklash'));
  await tester.tap(find.text('Avans chekini yuklash'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('invalid offscreen customer or advance never opens bank instructions', (tester) async {
    final api = LinkedApi();
    await mount(tester, api);
    final phone = find.widgetWithText(TextFormField, 'Telefon raqam');
    await reveal(tester, phone);
    await tester.enterText(phone, '01000000000');
    await reveal(tester, find.text(nextLabel));
    await tester.tap(find.text(nextLabel));
    await tester.pumpAndSettle();
    expect(find.text('Bank o‘tkazmasi'), findsNothing);
    expect(find.text('Ismingizni kiriting.'), findsOneWidget);
    await customer(tester);
    final advance = find.widgetWithText(TextFormField, 'Bir kitob uchun avans (₩)');
    await reveal(tester, advance);
    await tester.enterText(advance, '4999');
    await reveal(tester, find.text(nextLabel));
    await tester.tap(find.text(nextLabel));
    await tester.pumpAndSettle();
    expect(find.text('Bank o‘tkazmasi'), findsNothing);
    expect(api.attempts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('closed or changed book terms are rechecked before any payment', (tester) async {
    final api = LinkedApi();
    await mount(tester, api);
    await customer(tester);
    api.settings = const WebPreorderConfig(enabled: true, bookId: 'book', bookTitle: 'Sinov kitobi',
      arrival: '10-noyabr', deposit: 10000, termsToken: 'changed');
    await reveal(tester, find.text(nextLabel));
    await tester.tap(find.text(nextLabel));
    await tester.pumpAndSettle();
    expect(find.text('Bank o‘tkazmasi'), findsNothing);
    expect(find.text('10-noyabr'), findsOneWidget);
    api.settings = const WebPreorderConfig();
    await reveal(tester, find.text(nextLabel));
    await tester.tap(find.text(nextLabel));
    await tester.pumpAndSettle();
    expect(find.textContaining('Avans yubormang'), findsOneWidget);
    expect(api.uploads, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('receipt removal, undo and Back preserve linked-book draft and chosen advance', (tester) async {
    final api = LinkedApi();
    await mount(tester, api);
    await customer(tester);
    final advance = find.widgetWithText(TextFormField, 'Bir kitob uchun avans (₩)');
    await reveal(tester, advance);
    await tester.enterText(advance, '7500');
    final plus = find.widgetWithIcon(IconButton, Icons.add_circle_outline);
    await reveal(tester, plus);
    await tester.tap(plus);
    await reveal(tester, find.text('Jami avans: ₩15,000'));
    expect(find.textContaining('Pochtaga +4 000'), findsOneWidget);
    await reveal(tester, find.text(nextLabel));
    await tester.tap(find.text(nextLabel));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('O‘tkaziladigan summa: ₩15,000'));
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
    await tester.tap(find.byTooltip('Orqaga'));
    await tester.pumpAndSettle();
    await reveal(tester, advance);
    expect(tester.widget<TextFormField>(advance).controller!.text, '7500');
    await reveal(tester, find.text('Buyurtmani bekor qilish'));
    await tester.tap(find.text('Buyurtmani bekor qilish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Davom etish'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text(nextLabel));
    await tester.tap(find.text(nextLabel));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Chekni almashtirish'));
    expect(find.text('Chekni almashtirish'), findsOneWidget);
    expect(api.attempts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('successful server submission survives local profile failure and cannot be repeated', (tester) async {
    final api = LinkedApi();
    await mount(tester, api, state: BrokenProfileStorage());
    await pay(tester);
    await reveal(tester, find.text(submitLabel));
    await tester.tap(find.text(submitLabel));
    await tester.pumpAndSettle();
    expect(api.attempts, 1);
    expect(api.uploads, 1);
    expect(find.text('Oldindan buyurtma yuborildi'), findsOneWidget);
    expect(api.request!['book_id'], api.settings.bookId);
    expect(api.request!['deposit_amount'], 5000);
    expect(tester.takeException(), isNull);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, submitLabel));
    expect(button.onPressed, isNull);
    await tester.tap(find.text('Tushunarli'));
    await tester.pumpAndSettle();
    expect(find.text('Sinov katalogi'), findsOneWidget);
    expect(api.attempts, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed submission retries the same request and existing receipt without another upload', (tester) async {
    final api = LinkedApi()..fail = true;
    await mount(tester, api, state: BrokenProfileStorage());
    await pay(tester);
    await reveal(tester, find.text(submitLabel));
    await tester.tap(find.text(submitLabel));
    await tester.pumpAndSettle();
    final id = api.request!['id'];
    api.fail = false;
    await tester.tap(find.text(submitLabel));
    await tester.pumpAndSettle();
    expect(api.attempts, 2);
    expect(api.uploads, 1);
    expect(api.request!['id'], id);
    expect(find.text('Oldindan buyurtma yuborildi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('picker blocks Back and duplicate submit until image choice completes', (tester) async {
    final api = LinkedApi();
    final image = Completer<Uint8List?>();
    await mount(tester, api, pick: () => image.future);
    await customer(tester);
    await reveal(tester, find.text(nextLabel));
    await tester.tap(find.text(nextLabel));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Avans chekini yuklash'));
    await tester.tap(find.text('Avans chekini yuklash'));
    await tester.pump();
    expect(tester.widget<IconButton>(find.byTooltip('Orqaga')).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, submitLabel)).onPressed, isNull);
    image.complete(null);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.byTooltip('Orqaga')).onPressed, isNotNull);
    expect(api.attempts, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
