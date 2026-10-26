import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/web_preorder_checkout_page.dart';

class CancelledWebPreorderState extends AppState {
  CancelledWebPreorderState() : super(backendConfigured: false);

  @override
  Future<Map<String, dynamic>> webPreorderInvoice(String id) async => {
        'id': id,
        'title': 'Sinov kitobi',
        'status': 'cancelled',
        'quantity': 1,
        'price_ready': true,
        'unit_price': 17000,
        'deposit_credit': 5000,
        'shipping_fee': 4000,
        'base_total': 21000,
        'extra_total': 0,
        'amount_due': 16000,
        'can_edit': false,
        'payment_state': 'cancelled',
        'extras': <Map<String, dynamic>>[],
      };
}

void main() {
  testWidgets('cancelled preorder never offers a stale balance checkout',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => CancelledWebPreorderState(),
      child: const MaterialApp(
        home: WebPreorderCheckoutPage(
          preorderId: 'fabb4d3a-fd96-470a-bcc8-738f59ce157d',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sinov kitobi'), findsOneWidget);
    expect(find.textContaining('admin tomonidan bekor qilingan'), findsOneWidget);
    expect(find.text('Buyurtma hisobi'), findsNothing);
    expect(find.text('Qolgan to‘lovni yuborish'), findsNothing);
    expect(find.text('Yana kitob qo‘shish'), findsNothing);
  });
}
