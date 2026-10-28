import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/customer_form_scaffold.dart';
import 'package:muhajeerbooks/store_ui.dart';

class _CheckoutState extends AppState {
  _CheckoutState() : super(backendConfigured: false) {
    savedCustomer = {'name': 'Test Owner', 'phone': '01012345678', 'address': ''};
  }
  @override
  List<Book> get books => [Book.fromMap({
    'id': 'extra', 'title': 'Discounted book', 'price': 20000,
    'stock': 5, 'discount_percent': 25,
  })];
  int saves = 0;
  String recipient = '';
  String recipientPhone = '';
  @override
  Future<Map<String, dynamic>> webPreorderInvoice(String id) async => {
    'id': id, 'status': 'arrived', 'price_ready': true,
    'title': 'Test book', 'quantity': 1, 'unit_price': 17000,
    'main_items': [{'title': 'Test book', 'quantity': 1, 'unit_price': 17000}],
    'base_total': 21000, 'extra_total': 0, 'shipping_fee': 4000,
    'deposit_credit': 5000, 'amount_due': 16000,
    'payment_state': 'requested', 'can_edit': true,
    'delivery_saved': false, 'extras': <Map<String, dynamic>>[],
    'recipient_name': 'Gift Recipient', 'recipient_phone': '01087654321',
  };
  @override
  Future<Map<String, dynamic>> saveWebPreorderDelivery(String id, {
    required String recipientName, required String recipientPhone,
    required String address, required String deliveryType,
  }) async {
    saves++;
    recipient = recipientName;
    this.recipientPhone = recipientPhone;
    return {...await webPreorderInvoice(id), 'delivery_saved': true,
      'recipient_name': recipientName, 'recipient_phone': recipientPhone,
      'delivery_address': address, 'delivery_type': deliveryType};
  }
}

void main() {
  testWidgets('number pad can close above keyboard and preserves input', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 720), viewInsets: EdgeInsets.only(bottom: 280)),
      child: CustomerFormScaffold(body: ListView(children: [
        TextField(controller: controller, focusNode: focus, keyboardType: TextInputType.phone),
      ])),
    )));
    await tester.enterText(find.byType(TextField), '01012345678');
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    final close = find.byKey(const ValueKey('dismiss-customer-keyboard'));
    expect(tester.getBottomRight(close).dy, lessThanOrEqualTo(440));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(controller.text, '01012345678');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping empty form area closes keyboard without clearing draft', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(home: CustomerFormScaffold(
      body: Column(children: [TextField(focusNode: focus), const Expanded(child: SizedBox.expand())]),
    )));
    await tester.enterText(find.byType(TextField), 'Draft address');
    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(find.text('Draft address'), findsOneWidget);
  });

  testWidgets('checkout receipt picker is single flight and recovers from gallery error', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final pending = Completer<XFile?>();
    var calls = 0;
    final state = _CheckoutState();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state,
      child: MaterialApp(home: CheckoutPage(pickProof: () {
        calls++;
        return calls == 1 ? pending.future : Future.value(null);
      })),
    ));
    await tester.pumpAndSettle();
    final upload = find.text('To‘lov chekini yuklash');
    await tester.scrollUntilVisible(upload, 220, scrollable: find.byType(Scrollable).first);
    await tester.tap(upload);
    await tester.pump();
    await tester.tap(upload);
    await tester.pump();
    expect(calls, 1);
    pending.completeError(PlatformException(code: 'photo_access_denied'));
    await tester.pumpAndSettle();
    expect(find.text('Chekni tanlab bo‘lmadi. Qayta urinib ko‘ring.'), findsOneWidget);
    await tester.tap(upload);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prepaid address validation preserves gift recipient across PIN check', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = _CheckoutState();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state,
      child: const MaterialApp(home: CheckoutPage(preorderId: 'test')),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Manzil'), 'Test street 123, room 8');
    final button = find.text('Qolgan to‘lovni yuborish');
    await tester.scrollUntilVisible(button, 230, scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(state.saves, 1);
    expect(state.recipient, 'Gift Recipient');
    expect(state.recipientPhone, '01087654321');
  });

  testWidgets('offscreen invalid prepaid address blocks server request', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = _CheckoutState();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state,
      child: const MaterialApp(home: CheckoutPage(preorderId: 'test')),
    ));
    await tester.pumpAndSettle();
    final button = find.text('Qolgan to‘lovni yuborish');
    await tester.scrollUntilVisible(button, 230, scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(state.saves, 0);
    expect(find.text('To‘liq manzilni kiriting'), findsWidgets);
  });
  testWidgets('checkout Done closes multiline address keyboard and retains draft', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: _CheckoutState(),
      child: const MaterialApp(home: CheckoutPage()),
    ));
    await tester.pumpAndSettle();
    final address = find.widgetWithText(TextFormField, 'Manzil');
    await tester.enterText(address, 'Test street 123, room 8');
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('Test street 123, room 8'), findsOneWidget);
  });

  testWidgets('prepaid book picker fits keyboard on small landscape screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(660, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: _CheckoutState(),
      child: const MaterialApp(home: CheckoutPage(preorderId: 'test')),
    ));
    await tester.pumpAndSettle();
    final add = find.text('Yana kitob qo‘shish');
    await tester.scrollUntilVisible(add, 150, scrollable: find.byType(Scrollable).first);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.textContaining('15,000'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextField, 'Kitob qidirish'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

}
