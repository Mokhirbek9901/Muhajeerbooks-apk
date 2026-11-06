import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/preorder_partial_book_status.dart';

void main() {
  test('counts only unarrived book quantities', () {
    final rows = preorderMissingBookRows({
      'original_items': [
        {'book_title': 'Kitob A', 'quantity': 2},
        {'book_title': 'Kitob B', 'quantity': 1},
        {'book_title': 'Kitob C', 'quantity': 1},
      ],
      'batches': [
        {'status': 'prepared', 'items': [
          {'index': 0, 'quantity': 1},
          {'index': 1, 'quantity': 1},
        ]},
      ],
    });
    expect(rows.length, 2);
    expect(rows[0]['title'], 'Kitob A');
    expect(rows[0]['remaining_quantity'], 1);
    expect(rows[1]['title'], 'Kitob C');
    expect(rows[1]['remaining_quantity'], 1);
  });

  test('existing missing notices cannot be selected again', () {
    final rows = preorderMissingBookRows({
      'original_items': [
        {'book_title': 'Kelmadi', 'quantity': 3},
      ],
      'batches': [],
      'missing_items': [
        {'index': 0, 'quantity': 3},
      ],
    });
    expect(rows.single['reported_quantity'], 3);
    expect(rows.single['unreported_quantity'], 0);
  });

  test('cancelled arrivals do not hide unarrived book titles', () {
    final rows = preorderMissingBookRows({
      'closed': true,
      'original_items': [
        {'book_title': 'A', 'quantity': 1},
        {'book_title': 'B', 'quantity': 2},
      ],
      'batches': [
        {'status': 'cancelled', 'items': [
          {'index': 0, 'quantity': 1}
        ]},
        {'status': 'completed', 'items': [
          {'index': 1, 'quantity': 1}
        ]},
      ],
    });
    expect(rows.length, 2);
    expect(rows[0]['remaining_quantity'], 1);
    expect(rows[1]['remaining_quantity'], 1);
  });
}
