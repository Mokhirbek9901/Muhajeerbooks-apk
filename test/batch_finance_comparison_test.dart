import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_batch_add_picker.dart';

void main() {
  group('Batch finance and procurement comparison', () {
    test('unmodified historical multi-cost book keeps exact original total', () {
      // Two old entries have the same title but different unit costs:
      // 1×7000 + 1×9000 = 16000. A rounded average is not used.
      expect(batchBookCostValue(quantity: 2, unitCost: 8000,
        previousQuantity: 2, historicalLineValue: 16000), 16000);
    });

    test('correcting 12 stul from 2 to 3 increases amount by only ONE book', () {
      final previous = batchBookCostValue(quantity: 2, unitCost: 6500,
        previousQuantity: 2, historicalLineValue: 13000);
      final corrected = batchBookCostValue(quantity: 3, unitCost: 6500,
        previousQuantity: 2, historicalLineValue: 13000);
      expect(previous, 13000);
      expect(corrected, 19500);
      expect(corrected - previous, 6500);
    });

    test('changing cost deliberately recalculates all selected copies', () {
      expect(batchBookCostValue(quantity: 3, unitCost: 8000,
        previousQuantity: 2, historicalLineValue: 13000,
        changedUnitCost: true), 24000);
    });

    test('removing a book from the historical batch yields no book cost', () {
      expect(batchBookCostValue(quantity: 0, unitCost: 6500,
        previousQuantity: 2, historicalLineValue: 13000), 0);
    });

    test('adding a new selected book uses quantity times catalog cost', () {
      expect(batchBookCostValue(quantity: 4, unitCost: 4900), 19600);
    });

    test('same accounting value has zero gap, finance overage is positive', () {
      const financeAmount = 827840;
      const selectedBookCost = 827840;
      expect(financeAmount - selectedBookCost, 0);
      expect(financeAmount - 768444, 59396);
      expect(financeAmount - 1259601, -431761);
    });
  });
}
