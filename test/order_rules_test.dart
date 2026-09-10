import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_state.dart';

void main() {
  test('discounted price and stock rules stay consistent', () {
    const book = Book(
      id: 'book-1',
      title: 'Test',
      author: 'Author',
      category: 'Test',
      description: '',
      price: 20000,
      stock: 3,
      discountPercent: 25,
      imageUrl: '',
      isActive: true,
    );

    expect(book.currentPrice, 15000);
    expect(book.inStock, isTrue);
    expect(const CartLine(book: book, quantity: 2).total, 30000);
  });

  test('order source ownership is exact', () {
    ShopOrder order(String source) => ShopOrder(
      id: 'order-$source',
      customerName: 'Test',
      phone: '01012345678',
      address: 'Test address',
      deliveryType: '택배',
      deliveryFee: 4000,
      subtotal: 10000,
      total: 14000,
      status: 'new',
      source: source,
      items: const [],
      createdAt: DateTime(2026, 9, 8),
    );

    expect(order('app').isApp, isTrue);
    expect(order('app').isTelegram, isFalse);
    expect(order('app').isInstagram, isFalse);

    expect(order('telegram').isTelegram, isTrue);
    expect(order('telegram').isApp, isFalse);

    expect(order('instagram').isInstagram, isTrue);
    expect(order('instagram').isApp, isFalse);
  });

  test('recovery code is stable and short enough to share', () {
    final order = ShopOrder(
      id: '677ae40f-7c44-4420-acb6-fef72c6b1641',
      customerName: 'Test',
      phone: '01012345678',
      address: 'Test address',
      deliveryType: '택배',
      deliveryFee: 4000,
      subtotal: 10000,
      total: 14000,
      status: 'new',
      source: 'app',
      items: const [],
      createdAt: DateTime(2026, 9, 10),
      stockReserved: true,
    );

    expect(order.recoveryCode, 'fef72c6b1641');
    expect(order.stockReserved, isTrue);
  });
}
