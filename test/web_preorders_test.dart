import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/web_preorders.dart';

class FakePreorders extends WebPreorderApi {
  FakePreorders(this.value);
  WebPreorderConfig value;
  int saves = 0, statusCalls = 0;
  Map<String, dynamic>? lastStatus;
  List<Map<String, dynamic>> rows = [];
  bool failStatus = false;
  @override
  Future<WebPreorderConfig> bookConfig(String bookId) async => value;
  @override
  Future<WebPreorderConfig> config() async => value;
  @override
  Future<dynamic> admin(
    String secret,
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (action == 'save') {
      saves++;
      return {};
    }
    if (action == 'list') return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    if (action == 'status') {
      statusCalls++;
      lastStatus = data;
      if (failStatus) throw StateError('Holat boshqa oynada o‘zgargan');
      rows = rows.map((r) => {...r, 'status': data['status'], 'status_version': (r['status_version'] as int) + 1}).toList();
      return {'status': data['status'], 'inbox_created': true};
    }
    return {
      'enabled': value.enabled,
      'arrival_note': value.arrival,
      'deposit_amount': value.deposit,
      'batch_quantity': 20,
      'revision': value.revision,
    };
  }
}

Widget app(Widget child) => ChangeNotifierProvider(
  create: (_) => AppState(backendConfigured: false),
  child: MaterialApp(home: child),
);

void main() {
  test(
    'missing arrival date fails closed and deposits multiply by quantity',
    () {
      expect(const WebPreorderConfig(enabled: true).accepting, isFalse);
      const c = WebPreorderConfig(
        enabled: true,
        arrival: '5-noyabr',
        deposit: 7500,
      );
      expect(c.accepting, isTrue);
      expect(c.total(3), 22500);
    },
  );
  testWidgets('customer sees arrival before any bank payment controls', (
    tester,
  ) async {
    final api = FakePreorders(
      const WebPreorderConfig(
        enabled: true,
        arrival: '5-noyabr',
        deposit: 10000,
      ),
    );
    await tester.pumpWidget(app(WebPreorderPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('5-noyabr'), findsOneWidget);
    expect(find.text('Bank o‘tkazmasi'), findsNothing);
    expect(find.text('Avans yubordim — buyurtma berish'), findsNothing);
    expect(find.text('Kitob rasmini yuklash'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('closed reception exposes no customer form or pay button', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(WebPreorderPage(api: FakePreorders(const WebPreorderConfig()))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Avans yubormang'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('preorder card fits the narrow catalogue tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 155,
            height: 258,
            child: WebPreorderCatalogCard(
              api: FakePreorders(
                const WebPreorderConfig(enabled: true, arrival: '10–14 kun'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Oldindan\nbuyurtma'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('admin must set arrival before enabling and saving', (
    tester,
  ) async {
    final api = FakePreorders(const WebPreorderConfig());
    await tester.pumpWidget(
      MaterialApp(
        home: WebPreorderAdminPage(secret: 'test', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sozlamalarni saqlash'));
    await tester.tap(find.text('Sozlamalarni saqlash'));
    await tester.pumpAndSettle();
    expect(api.saves, 0);
    expect(
      find.text('Qabulni ochishdan oldin sanani kiriting'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('linked book uses admin arrival and deposit without asking for book upload', (tester) async {
    final api = FakePreorders(const WebPreorderConfig(enabled: true, arrival: '10–14 kun',
      deposit: 5000, depositMax: 10000, bookId: 'book-id', bookTitle: 'Jinoyat va jazo', termsToken: 'terms'));
    final book = Book.fromMap({'id': 'book-id', 'title': 'Jinoyat va jazo'});
    await tester.pumpWidget(app(WebPreorderPage(api: api, book: book)));
    await tester.pumpAndSettle();
    expect(find.text('10–14 kun'), findsOneWidget);
    expect(find.text('Kitob rasmini yuklash'), findsNothing);
    expect(find.text('Bank o‘tkazmasi'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  Map<String, dynamic> requestRow(String status) => {
    'id': '12345678-1234-4234-8234-123456789abc', 'status': status, 'status_version': 3,
    'book_title': 'Jinoyat va jazo', 'quantity': 1, 'deposit_amount': 5000,
    'customer_name': 'Test', 'phone': '01000000000', 'arrival_note': '10–14 kun',
  };

  testWidgets('accept action saves exact row version and refreshes status with feedback', (tester) async {
    final api = FakePreorders(const WebPreorderConfig())..rows = [requestRow('waiting')];
    await tester.pumpWidget(MaterialApp(home: WebPreorderAdminPage(secret: 'test', api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Qabul qilish'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Qabul qilish'));
    await tester.pumpAndSettle();
    expect(api.statusCalls, 0);
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(api.statusCalls, 1);
    expect(api.lastStatus!['version'], 3);
    expect(find.text('Holat: Qabul qilindi'), findsOneWidget);
    expect(find.text('Kitob keldi'), findsOneWidget);
    expect(find.textContaining('Mijozning bildirishnomalariga xabar yozildi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancellation requires a reason and server errors keep original status', (tester) async {
    final api = FakePreorders(const WebPreorderConfig())..rows = [requestRow('accepted')]..failStatus = true;
    await tester.pumpWidget(MaterialApp(home: WebPreorderAdminPage(secret: 'test', api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Bekor qilish'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(api.statusCalls, 0);
    await tester.enterText(find.widgetWithText(TextFormField, 'Sababi (majburiy)'), 'Mijoz so‘rovi');
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(api.lastStatus!['note'], 'Mijoz so‘rovi');
    expect(find.text('Holat: Qabul qilindi'), findsOneWidget);
    expect(find.textContaining('Holat boshqa oynada o‘zgargan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

}
