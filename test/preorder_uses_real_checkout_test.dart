import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/store_ui.dart';

class _PrepaidCheckoutState extends AppState {
  _PrepaidCheckoutState() : super(backendConfigured: false) {
    savedCustomer = {
      'name': 'Test Mijoz',
      'phone': '01012345678',
      'address': '',
    };
  }

  int deliverySaves = 0;
  int ordinaryOrders = 0;
  String savedAddress = '';
  @override
  Future<Map<String, dynamic>> webPreorderInvoice(String id) async => {
    'source': 'web', 'id': id, 'title': 'Yusufning qizi',
    'book_id': 'fabb4d3a-fd96-470a-bcc8-738f59ce157d',
    'status': 'arrived', 'price_ready': true,
    'quantity': 1, 'unit_price': 17000,
    'extra_total': 0, 'base_total': 21000,
    'deposit_credit': 5000, 'amount_due': 16000,
    'shipping_fee': 4000,
    'payment_state': 'proof_submitted', 'can_edit': false,
    'delivery_type': '택배', 'delivery_saved': false,
    'recipient_name': 'Test Mijoz', 'recipient_phone': '01012345678',
    'extras': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> saveWebPreorderDelivery(String id, {
    required String recipientName, required String recipientPhone,
    required String address, required String deliveryType,
  }) async {
    deliverySaves++;
    savedAddress = address;
    return {
      ...await webPreorderInvoice(id),
      'delivery_saved': true,
      'delivery_address': address,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'delivery_type': deliveryType,
    };
  }
}

void main() {
  testWidgets('prepaid book opens the real cart CheckoutPage and preserves paid advance',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(440, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _PrepaidCheckoutState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: CheckoutPage(
            preorderId: 'fabb4d3a-fd96-470a-bcc8-738f59ce157d',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutPage), findsOneWidget);
    expect(find.text('Buyurtmani rasmiylashtirish'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Manzil'), findsOneWidget);

    // The first Scrollable is the checkout ListView. The last one can be a
    // tiny TextFormField internal scroll viewport, which is not draggable.
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Yusufning qizi'), 250, scrollable: scroll,
    );
    expect(find.text('Yusufning qizi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Oldindan to‘langan avans'), 250, scrollable: scroll,
    );
    expect(find.text('Oldindan to‘langan avans'), findsOneWidget);
    expect(find.text('Qolgan to‘lov'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Qabul qiluvchi va manzilni saqlash'), 250,
      scrollable: scroll,
    );
    expect(find.text('Qabul qiluvchi va manzilni saqlash'), findsOneWidget);
    expect(find.text('Yana kitob qo‘shish'), findsNothing);

    final field = find.widgetWithText(TextFormField, 'Manzil');
    await tester.ensureVisible(field);
    await tester.enterText(field, '경상북도 경산시 계양로 37길 7-3 808호');
    await tester.scrollUntilVisible(
      find.text('Qabul qiluvchi va manzilni saqlash'), 250,
      scrollable: scroll,
    );
    await tester.tap(find.text('Qabul qiluvchi va manzilni saqlash'));
    await tester.pumpAndSettle();
    expect(state.deliverySaves, 1);
    expect(state.savedAddress, contains('경산시'));
    expect(state.localOrders, isEmpty);
  });
}
