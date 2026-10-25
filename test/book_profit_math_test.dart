import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_book_profit_page.dart';

void main() {
  group('Per-sale immutable book profit arithmetic', () {
    test('different costs in consecutive sales are not blended', () {
      const firstCost = 10000;
      const firstSale = 15000;
      const secondCost = 15000;
      const secondSale = 16000;
      final oldSaleProfit = BookProfitMath.profit(firstSale, firstCost);
      final newSaleProfit = BookProfitMath.profit(secondSale, secondCost);

      expect(oldSaleProfit, 5000);
      expect(newSaleProfit, 1000);
      expect(oldSaleProfit + newSaleProfit, 6000);

      // Changing the catalog's current cost must not affect the snapshot.
      const laterCatalogCost = 17500;
      expect(BookProfitMath.profit(firstSale, firstCost), 5000);
      expect(BookProfitMath.profit(secondSale, secondCost), 1000);
      expect(BookProfitMath.profit(16000, laterCatalogCost), -1500);
    });

    test('projected stock profit uses current, not historical cost', () {
      expect(BookProfitMath.potential(16000, 12000, 8), 32000);
      expect(BookProfitMath.potential(16000, 15000, 8), 8000);
    });

    test('negative sales margin is retained as a loss', () {
      expect(BookProfitMath.profit(13000, 15000), -2000);
    });

    test('money formatting keeps won and sign', () {
      expect(BookProfitMath.won(6000), '₩6,000');
      expect(BookProfitMath.won(-1500), '−₩1,500');
    });
  });
}
