import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_profit_lot_price_editor.dart';

void main() {
  group('single purchase-lot price review', () {
    test('zero catalog sale price is missing, never free revenue', () {
      expect(profitLotHasMissingPrice({
        'unit_cost': 5633,
        'sale_price': 0,
      }), isTrue);
      expect(profitLotForecast(2, 5633, 0), isNull);
    });

    test('missing lot cost is reported separately', () {
      expect(profitLotHasMissingPrice({
        'unit_cost': 0,
        'sale_price': 14000,
      }), isTrue);
      expect(profitLotForecast(2, 0, 14000), isNull);
    });

    test('two valid prices produce only a forecast', () {
      expect(profitLotHasMissingPrice({
        'unit_cost': 6197,
        'sale_price': 16000,
      }), isFalse);
      expect(profitLotForecast(2, 6197, 16000), 19606);
    });

    test('negative projected margin stays negative', () {
      expect(profitLotForecast(3, 17000, 15000), -6000);
    });

    test('missing or invalid quantity cannot yield a forecast', () {
      expect(profitLotForecast(0, 1000, 2000), isNull);
      expect(profitLotForecast(2, null, 2000), isNull);
    });
  });
}
