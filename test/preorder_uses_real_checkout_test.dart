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
  String savedDeliveryType = '택배';
  @override
  Future<Map<String, dynamic>> webPreorderInvoice(String id) async => {
    'source': 'web', 'id': id, 'title': 'Yusufning qizi',
    'book_id': 'fabb4d3a-fd96-470a-bcc8-738f59ce157d',
    'status': 'arrived', 'price_ready': true,
    'quantity': 1, 'unit_price': 17000,
    'extra_total': 0, 'base_total': savedDeliveryType == '택배' ? 21000 : 17000,
    'deposit_credit': 5000, 'amount_due': savedDeliveryType == '택배' ? 16000 : 12000,
    'shipping_fee': savedDeliveryType == '택배' ? 4000 : 0,
    'proof_submitted_amount': 16000,
    'shipping_refund_due': savedDeliveryType == '택배' ? 0 : 4000,
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
    savedDeliveryType = deliveryType;
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
    await tester.scrollUntilVisible(field, -230, scrollable: scroll);
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


  testWidgets('prepaid checkout has only postal and ORIGINAL Gyeongsan pickup (new city delivery removed)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(440, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _PrepaidCheckoutState();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: CheckoutPage(
        preorderId: 'fabb4d3a-fd96-470a-bcc8-738f59ce157d',
      )),
    ));
    await tester.pumpAndSettle();

    final scroll = find.byType(Scrollable).first;
    final oldPickup = find.text('경산dan (Gyeongsan) o‘zim olib ketaman');
    await tester.scrollUntilVisible(oldPickup, 170, scrollable: scroll);
    expect(find.text('Gyeongsan ichida manzilga bepul yetkazish'), findsNothing);
    expect(oldPickup, findsOneWidget);
    final values = tester.widgetList<RadioListTile<String>>(
      find.byType(RadioListTile<String>)).map((widget) => widget.value).toList();
    expect(values, containsAll(['택배', '경산 직접수령']));
    expect(values, isNot(contains('경산 무료배송')));
    expect(values.length, 2);
    await tester.tap(oldPickup);
    await tester.pumpAndSettle();
    expect(find.textContaining(
      'Bu faqat 경산 (Gyeongsan) hududida yashaydiganlar uchun. One Mart atrofiga olib boramiz.'),
      findsOneWidget);
    expect(find.textContaining(
      'Olib ketish joyi va vaqtini kelishish uchun admin siz bilan bog‘lanadi'),
      findsOneWidget);

    final addr = find.widgetWithText(TextFormField, 'Manzil');
    await tester.scrollUntilVisible(addr, -185, scrollable: scroll);
    await tester.enterText(addr, '경상북도 경산시 계양로 37길 7-3 808호');
    await tester.scrollUntilVisible(
      find.text('Admin qaytarishi kerak'), 170, scrollable: scroll);
    expect(find.text('Admin qaytarishi kerak'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Qabul qiluvchi va manzilni saqlash'), 175, scrollable: scroll);
    await tester.tap(find.text('Qabul qiluvchi va manzilni saqlash'));
    await tester.pumpAndSettle();

    expect(state.savedDeliveryType, '경산 직접수령');
    expect(state.deliverySaves, 1);
    expect(state.savedAddress, contains('경산시'));
    expect(find.text('Yana kitob qo‘shish'), findsNothing);
    expect(state.localOrders, isEmpty);
  });
}
