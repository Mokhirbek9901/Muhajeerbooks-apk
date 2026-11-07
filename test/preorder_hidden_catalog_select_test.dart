import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_ui.dart';
import 'package:muhajeerbooks/app_state.dart';

Book catalogBook({required bool active, required int stock}) => Book(
  id: active ? 'public-title' : 'hidden-title',
  title: active ? 'Ochiq kitob' : 'Yashirilgan kitob',
  author: 'Muallif',
  category: 'Kitoblar',
  description: '',
  price: 18000,
  stock: stock,
  discountPercent: 0,
  imageUrl: '',
  isActive: active,
);

void main() {
  group('Private preorder catalog selection', () {
    test('hidden title is selectable even with public stock 0', () {
      final hidden = catalogBook(active: false, stock: 0);
      expect(hidden.isActive, false);
      expect(preorderPartialCatalogSelectableForAdmin(hidden, 'Yashirilgan'),
          true);
      expect(hidden.stock, 0);
      expect(hidden.isActive, false);
    });

    test('published title is still selectable', () {
      final published = catalogBook(active: true, stock: 3);
      expect(preorderPartialCatalogSelectableForAdmin(published, 'ochiq'), true);
    });

    test('search still rejects unrelated titles', () {
      expect(preorderPartialCatalogSelectableForAdmin(
          catalogBook(active: false, stock: 0), 'boshqa'), false);
    });

    test('whitespace in admin search is ignored', () {
      expect(preorderPartialCatalogSelectableForAdmin(
          catalogBook(active: false, stock: 0), '  yashirilgan  '), true);
    });
  });
}
