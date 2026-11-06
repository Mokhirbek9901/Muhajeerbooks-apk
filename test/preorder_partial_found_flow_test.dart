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
