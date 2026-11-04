import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_preorders.dart';

void main() {
  test('general preorder config reads custom warning text', () {
    final configured = WebPreorderConfig.fromMap({
      'enabled': true,
      'arrival_note': '2026.11.17 ~ 2026.11.21',
      'deposit_amount': 5000,
      'customer_notice':
          'Ba’zi kitoblar topilmasligi mumkin. Topilmasa sizga xabar beramiz.',
    });
    expect(configured.customerNotice, contains('kitoblar topilmasligi'));
    expect(configured.accepting, isTrue);
    expect(const WebPreorderConfig().customerNotice, isEmpty);
  });

  testWidgets('customer must actively acknowledge the warning', (tester) async {
    bool acknowledged = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: PreorderCustomerNotice(
        notice: 'Ayrim kitoblar topilmasligi mumkin.',
        acknowledged: false,
        onChanged: (value) => acknowledged = value,
      ),
    )));
    expect(find.text('Oldindan buyurtma haqida muhim izoh'), findsOneWidget);
    expect(find.text('Ayrim kitoblar topilmasligi mumkin.'), findsOneWidget);
    expect(find.byKey(const Key('preorder_customer_notice_ack')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('preorder_customer_notice_ack')));
    await tester.pump();
    expect(acknowledged, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no admin warning keeps old customer preorder clean', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: PreorderCustomerNotice(
        notice: ' ',
        acknowledged: false,
        onChanged: (_) {},
      ),
    )));
    expect(find.byKey(const Key('preorder_customer_notice_ack')), findsNothing);
  });

  test('critical catalog blocks are retained for iOS, Android and web', () {
    final source = File('lib/store_ui.dart').readAsStringSync();
    expect(source, contains('_BookRelatedRecommendations(book: b)'));
    expect(source, contains("title: 'Yozuvchining boshqa kitoblari'"));
    expect(source, contains("title: 'Shunga o‘xshash kitoblar'"));
    // The former out-of-stock fallback is preserved.
    expect(source, contains('_SimilarAvailableBooks(book: b)'));
    // Customer reviews cannot be reinstated by enabling a remote flag.
    expect(source, isNot(contains('_WebBookReviews(book: b)')));
    expect(source, isNot(contains('if (requestReview)')));
    expect(source, isNot(contains("'Sharh qoldirish'")));
  });

  test('sold-out catalog preorders save both dates without touching stock', () {
    final source = File('lib/admin_soldout_bulk.dart').readAsStringSync();
    expect(source, contains("'end_date': DateFormat('yyyy-MM-dd').format(end)"));
    expect(source, contains("soldout_eta_start_"));
    expect(source, contains("soldout_eta_end_"));
    expect(source, contains("stored?['end_date']"));
    expect(source, contains("end.isBefore(arrival)"));
    expect(source, contains("mode: 'apply'"));
  });

  test('owner note appears on BOTH customer preorder paths before payment', () {
    final single = File('lib/web_preorders.dart').readAsStringSync();
    final multi = File('lib/web_preorder_multi.dart').readAsStringSync();
    expect(single, contains("'customer_notice': notice.text.trim()"));
    expect(single, contains("controller: notice"));
    expect(single, contains('config?.customerNotice.trim().isNotEmpty'));
    expect(multi, contains('PreorderCustomerNotice('));
    expect(multi, contains('!noticeAcknowledged'));
  });
}
