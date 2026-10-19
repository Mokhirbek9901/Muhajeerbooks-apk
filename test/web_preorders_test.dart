import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/web_preorders.dart';

class FakePreorders extends WebPreorderApi {
  FakePreorders(this.value);
  WebPreorderConfig value;
  int saves = 0;
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
    if (action == 'list') return [];
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
}
