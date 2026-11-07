import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_ui.dart';

void main() {
  group('preorder private customer stock', () {
    test('existing sold-out catalog book can be allocated privately', () {
      final row = privatePreorderSelectionRow(
        index: 2,
        remaining: 1,
        quantity: 1,
        unitPrice: 16000,
        existingBookId: 'book-at-stock-zero',
      );
      expect(row['book_id'], 'book-at-stock-zero');
      expect(row['private_preorder_stock'], true);
      expect(row.containsKey('stock'), false);
      expect(row.containsKey('expected_stock'), false);
      expect(row.containsKey('create_catalog'), false);
    });

    test('missing catalog title is created inside server transaction at stock zero', () {
      final row = privatePreorderSelectionRow(
        index: 4,
        remaining: 2,
        quantity: 1,
        unitPrice: 19000,
        createCatalog: true,
      );
      expect(row['create_catalog'], true);
      expect(row.containsKey('book_id'), false);
      expect(row['private_preorder_stock'], true);
      expect(row['quantity'], 1);
    });

    test('private allocation refuses zero quantity and impossible selections', () {
      for (final n in [0, -1, 4, 201]) {
        expect(() => privatePreorderSelectionRow(
          index: 0,
          remaining: 3,
          quantity: n,
          unitPrice: 16000,
          existingBookId: 'book',
        ), throwsArgumentError);
      }
      expect(() => privatePreorderSelectionRow(
        index: 0, remaining: 1, quantity: 1,
        unitPrice: 0, createCatalog: true), throwsArgumentError);
      expect(() => privatePreorderSelectionRow(
        index: 0, remaining: 1, quantity: 1,
        unitPrice: 10000), throwsArgumentError);
      expect(() => privatePreorderSelectionRow(
        index: 0, remaining: 1, quantity: 1,
        unitPrice: 10000, existingBookId: 'book', createCatalog: true),
        throwsArgumentError);
    });
  });
}
