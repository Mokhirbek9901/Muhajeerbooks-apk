import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_ui.dart';
import 'package:muhajeerbooks/customer_preorder_partial.dart';

void main() {
  group('qisman topilgan kitoblar', () {
    test('only selected in-stock item reaches the server', () {
      final row = partialFoundSelectionRow(
        index: 1,
        bookId: 'book-1',
        requestedRemaining: 3,
        availableStock: 2,
        quantity: 2,
        unitPrice: 17500,
      );
      expect(row, {
        'index': 1,
        'book_id': 'book-1',
        'quantity': 2,
        'unit_price': 17500,
      });
      expect(row.containsKey('deposit'), false);
      expect(row.containsKey('status'), false);
    });

    test('cannot claim not-yet-arrived or previously claimed stock', () {
      expect(() => partialFoundSelectionRow(
        index: 0, bookId: 'book',
        requestedRemaining: 1, availableStock: 4,
        quantity: 2, unitPrice: 18000,
      ), throwsArgumentError);
      expect(() => partialFoundSelectionRow(
        index: 0, bookId: 'book',
        requestedRemaining: 3, availableStock: 1,
        quantity: 2, unitPrice: 18000,
      ), throwsArgumentError);
    });

    test('zero, negative and invalid prices are rejected', () {
      for (final bad in [0, -1, 10000001]) {
        expect(() => partialFoundSelectionRow(
          index: 0, bookId: 'book',
          requestedRemaining: 1, availableStock: 1,
          quantity: 1, unitPrice: bad,
        ), throwsArgumentError);
      }
    });

    test('customer never sees a fabricated zero before choosing advance', () {
      expect(partialPayableFromServer({
        'status': 'prepared',
        'amount_due': 0,
      }), isNull);
      expect(partialPayableFromServer({
        'status': 'awaiting_payment',
      }), isNull);
      expect(partialPayableFromServer({
        'status': 'proof_submitted',
        'amount_due': -10,
      }), isNull);
    });

    test('all remaining advance is the only admin-prepared policy', () {
      final items = [
        partialFoundSelectionRow(
          index: 0, bookId: 'b1', requestedRemaining: 2,
          availableStock: 2, quantity: 1, unitPrice: 12000),
      ];
      final payload = partialAllAdvancePreparePayload(items);
      expect(payload['items'], items);
      expect(payload['apply_all'], true);
      expect(payload.containsKey('keep'), false);
      expect(() => partialAllAdvancePreparePayload([]), throwsArgumentError);
    });

    test('customer request cannot retain any advance for missing titles', () {
      final payload = partialCustomerAllAdvanceRequest(
        recipientName: 'Xaridor', recipientPhone: '01012345678',
        address: 'Gyongsan apartment 12', deliveryType: '택배',
      );
      expect(payload['choice'], 'all');
      expect(payload.containsValue('keep'), false);
      expect(payload['recipient_phone'], '01012345678');
    });

    test('one arrived book: 24000 + 4000 postage - 10000 advance = 18000', () {
      final result = partialPreorderPostagePreview(
        subtotal: 24000, quantity: 1, unusedAdvance: 10000);
      expect(result['shipping_fee'], 4000);
      expect(result['total_with_shipping'], 28000);
      expect(result['deposit_applied'], 10000);
      expect(result['amount_due'], 18000);
      expect(result['refund_due'], 0);
    });

    test('four-book ordinary post is free unless discount blocks it', () {
      expect(partialPreorderPostagePreview(
        subtotal: 60000, quantity: 4, unusedAdvance: 10000)['shipping_fee'], 0);
      expect(partialPreorderPostagePreview(
        subtotal: 60000, quantity: 4, unusedAdvance: 10000,
        discountBlocksFreeShipping: true)['shipping_fee'], 4000);
    });

    test('full advance is not silently discarded if it exceeds the invoice', () {
      final result = partialPreorderPostagePreview(
        subtotal: 8000, quantity: 1, unusedAdvance: 15000);
      expect(result['amount_due'], 0);
      expect(result['refund_due'], 3000);
      expect(() => partialPreorderPostagePreview(
        subtotal: -1, quantity: 1, unusedAdvance: 0), throwsArgumentError);
    });

    test('remaining amount always comes from server invoice', () {
      expect(partialPayableFromServer({
        'status': 'awaiting_payment',
        'subtotal': 35000,
        'shipping_fee': 4000,
        'deposit_applied': 10000,
        'amount_due': 29000,
      }), 29000);
      expect(partialPayableFromServer({
        'status': 'awaiting_payment',
        'amount_due': 0,
      }), 0);
    });
  });
}
