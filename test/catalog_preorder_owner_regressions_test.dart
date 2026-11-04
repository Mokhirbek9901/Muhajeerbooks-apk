import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Every book detail has BOTH requested discovery sections', () {
    final code = File('lib/store_ui.dart').readAsStringSync();
    expect(code.contains('_BookRelatedSections(book: b)'), isTrue);
    expect(code.contains("title: 'Yozuvchining boshqa kitoblari'"), isTrue);
    expect(code.contains("title: 'Shunga o‘xshash kitoblar'"), isTrue);
    expect(code.contains('if (b.stock <= 0 && _webOrPlayCustomer)'), isFalse,
        reason: 'Related books must also be visible for in-stock titles.');
    expect(code.contains('_WebBookReviews(book: b)'), isFalse);
    expect(code.contains('Sharh qoldirish'), isFalse,
        reason: 'The owner permanently removed customer-written reviews.');
    expect(code.contains('if (requestReview)'), isFalse,
        reason: 'Old App Store builds must not expose a delayed review prompt.');
    expect(code.contains('_reviewPurchasedBook('), isFalse,
        reason: 'No hidden review dialog should remain in customer order history.');
    expect(code.contains('submitBookReview('), isFalse,
        reason: 'No customer review submission code should remain reachable.');
  });

  test('Sold-out per-book preorders keep both ETA dates and deposits', () {
    final code = File('lib/admin_soldout_bulk.dart').readAsStringSync();
    expect(code.contains('final Map<String, DateTime> _endDates'), isTrue);
    expect(code.contains("'end_date': DateFormat('yyyy-MM-dd').format(until)"), isTrue);
    expect(code.contains('soldout_start_'), isTrue);
    expect(code.contains('soldout_end_'), isTrue);
    expect(code.contains("'deposit': amount"), isTrue);
  });

  test('Owner notice must be seen and acknowledged before any advance', () {
    final admin = File('lib/web_preorders.dart').readAsStringSync();
    final customer = File('lib/web_preorder_multi.dart').readAsStringSync();
    expect(admin.contains("'customer_notice': customerNoticeEditor.text.trim()"),
        isTrue);
    expect(customer.contains("Key('preorder_customer_notice_visible')"), isTrue);
    expect(customer.contains("Key('preorder_notice_acknowledgement')"), isTrue);
    expect(customer.contains('!noticeAccepted'), isTrue);
    expect(customer.contains('old?.customerNotice != next.customerNotice'), isTrue);
  });
}
