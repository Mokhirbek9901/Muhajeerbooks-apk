import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/web_preorder_checkout_page.dart';

class _DeliveryState extends AppState {
  _DeliveryState({required this.payment})
      : super(backendConfigured: false);
  final String payment;
  int saveCount = 0;
  String lastAddress = '';
  String lastDelivery = '';
  @override
  Future<Map<String, dynamic>> webPreorderInvoice(String id) async => {
    'id': id, 'title': 'Yusufning qizi', 'status': 'arrived',
    'book_id': '79be42bd-91c3-4212-992b-1b785024d001',
    'quantity': 1, 'unit_price': 17000, 'price_ready': true,
    'deposit_credit': 5000, 'shipping_fee': 4000,
    'base_total': 21000, 'extra_total': 0,
    'amount_due': 16000, 'payment_state': payment,
    'can_edit': payment == 'requested',
    'delivery_saved': false,
    'extras': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> saveWebPreorderDelivery(String id, {
      required String recipientName, required String recipientPhone,
      required String address, required String deliveryType}) async {
    saveCount++;
    lastAddress = address;
    lastDelivery = deliveryType;
    return {
      ...await webPreorderInvoice(id),
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'delivery_type': deliveryType,
      'delivery_address': address,
      'delivery_saved': true,
    };
  }
}

void main() {
  for (final payment in ['requested', 'proof_submitted']) {
    testWidgets('old prepaid order $payment uses normal delivery checkout',
      (tester) async {
      tester.view.physicalSize = const Size(460, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final mock = _DeliveryState(payment: payment);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: mock,
        child: const MaterialApp(
          home: WebPreorderCheckoutPage(
            preorderId: 'fabb4d3a-fd96-470a-bcc8-738f59ce157d',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Buyurtmani rasmiylashtirish'), findsOneWidget);
      expect(find.text('1. Qabul qiluvchi'), findsOneWidget);
      expect(find.text('2. Yetkazib berish'), findsOneWidget);
      expect(find.text('3. Kitoblar'), findsOneWidget);
      expect(find.text('4. Buyurtma jami'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.at(0), 'Test Customer');
      await tester.enterText(inputs.at(1), '01012345678');
      await tester.enterText(inputs.at(2), '경상북도 경산시 계양로 37-3 101호');
      await tester.scrollUntilVisible(find.text('5. To‘lov va chek'), 260,
        scrollable: find.byType(Scrollable).last);
      expect(find.text('5. To‘lov va chek'), findsOneWidget);
      expect(find.text('Oldindan to‘langan avans'), findsOneWidget);
      final save = find.text('Qabul qiluvchi va manzilni saqlash');
      await tester.scrollUntilVisible(save, 180,
        scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(mock.saveCount, 1);
      expect(mock.lastDelivery, '택배');
      expect(mock.lastAddress, contains('경산시'));
      if (payment == 'proof_submitted') {
        expect(find.textContaining('cheki yuborilgan. Admin tekshiradi'), findsWidgets);
        expect(find.text('Yana kitob qo‘shish'), findsNothing);
      } else {
        expect(find.text('Yana kitob qo‘shish'), findsOneWidget);
      }
    });
  }
}
