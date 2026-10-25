import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_batch_finance_math.dart';

void main() {
  group('Book purchase / transport reconciliation', () {
    test('Existing finance purchase equals itemized book costs', () {
      const calc=BatchExpenseMath(
        purchaseExpenses:827840,
        transportExpenses:363000,
        enteredBookCost:827840,
        hasPurchaseSelection:true,
      );
      expect(calc.financeTotal,1190840);
      expect(calc.enteredWithTransport,1190840);
      expect(calc.bookDifference,0);
      expect(calc.totalDifference,0);
    });

    test('Missing book entries show a positive discrepancy', () {
      const calc=BatchExpenseMath(
        purchaseExpenses:827840,transportExpenses:363000,
        enteredBookCost:800000,hasPurchaseSelection:true);
      expect(calc.bookDifference,27840);
      expect(calc.totalDifference,27840);
    });

    test('Too many book costs show a negative discrepancy', () {
      const calc=BatchExpenseMath(
        purchaseExpenses:827840,transportExpenses:363000,
        enteredBookCost:851000,hasPurchaseSelection:true);
      expect(calc.bookDifference,-23160);
    });

    test('Unknown purchase expense is not treated as zero discrepancy', () {
      const calc=BatchExpenseMath(
        purchaseExpenses:0,transportExpenses:363000,
        enteredBookCost:827840,hasPurchaseSelection:false);
      expect(calc.bookDifference,isNull);
      expect(calc.totalDifference,isNull);
    });

    test('Transport is displayed but not subtracted twice from book costs', () {
      const calc=BatchExpenseMath(
        purchaseExpenses:100000,
        transportExpenses:40000,
        enteredBookCost:90000,
        hasPurchaseSelection:true);
      expect(calc.bookDifference,10000);
      expect(calc.totalDifference,10000);
      expect(calc.financeTotal,140000);
    });
  });
}
