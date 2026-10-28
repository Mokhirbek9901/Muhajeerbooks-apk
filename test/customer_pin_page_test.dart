import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/customer_pin_page.dart';
import 'package:muhajeerbooks/customer_session.dart';

class _ContactState extends AppState {
  _ContactState() : super(backendConfigured: false);
  int saves = 0;
  @override
  Future<void> saveCustomerWithoutPin(String name, String phone) async {
    saves++;
    savedCustomer = {'name': name, 'phone': phone, 'address': ''};
  }
}

void main() {
  Future<void> open(WidgetTester tester, _ContactState state) async {
    tester.view.physicalSize = const Size(420, 1150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state, child: MaterialApp(home: Builder(builder: (context) =>
        Scaffold(body: TextButton(onPressed: () => Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const CustomerPinPage())),
          child: const Text('Open profile')))))));
    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
  }

  testWidgets('name and phone open profile without any code field', (tester) async {
    final state = _ContactState();
    addTearDown(state.dispose);
    await open(tester, state);
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    expect(find.textContaining('PIN'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is TextField && w.obscureText), findsNothing);
    await tester.enterText(fields.at(0), 'Sinov Mijoz');
    await tester.enterText(fields.at(1), '01012345678');
    await tester.tap(find.text('Saqlash va davom etish'));
    await tester.pumpAndSettle();
    expect(state.saves, 1);
    expect(state.savedCustomer['phone'], '01012345678');
    expect(find.text('Open profile'), findsOneWidget);
  });

  testWidgets('invalid contact details cannot submit; saved details prefill', (tester) async {
    final state = _ContactState();
    addTearDown(state.dispose);
    state.savedCustomer = {'name': 'Saqlangan Ism', 'phone': '01012345678', 'address': ''};
    await open(tester, state);
    expect(find.text('Saqlangan Ism'), findsOneWidget);
    expect(find.text('01012345678'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'A');
    await tester.enterText(fields.at(1), '01012');
    await tester.tap(find.text('Saqlash va davom etish'));
    await tester.pump();
    expect(find.text('Ismingizni kiriting'), findsOneWidget);
    expect(find.text('Telefon raqamini to‘liq kiriting'), findsOneWidget);
    expect(state.saves, 0);
  });

  testWidgets('other-device recovery explains independent verification, no code', (tester) async {
    final state = _ContactState();
    addTearDown(state.dispose);
    await open(tester, state);
    await tester.tap(find.text('Boshqa telefondagi buyurtmalarim'));
    await tester.pumpAndSettle();
    expect(find.text('Avvalgi buyurtmalarni tiklash'), findsOneWidget);
    expect(find.textContaining('Admin shaxsingizni'), findsOneWidget);
    expect(find.textContaining('PIN'), findsNothing);
    expect(find.text('So‘rov yuborish'), findsNothing);
  });

  test('device credential never overrides an explicit professional session', () {
    final token = 'device:${'a' * 64}';
    CustomerSession.token = token;
    addTearDown(() => CustomerSession.token = '');
    expect(CustomerSession.deviceFor('customer_release_quote', {}), token);
    expect(CustomerSession.deviceFor('customer_release_quote', {'p_session': ''}), '');
    expect(CustomerSession.deviceFor('admin_verify', {}), '');
    expect(CustomerSession.deviceFor('customer_device_recovery_request', {}), token);
    expect(CustomerSession.isDevice('device:1234'), isFalse);
  });
}
