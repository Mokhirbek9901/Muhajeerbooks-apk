import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_ui.dart';

void main() {
  List<Map<String,dynamic>> lines({
    Object? bookId='a-book-id',
    int quantity=1,
    int unitPrice=24000,
  }) => [
    {'book_id':bookId,'title':'O‘smir (Dostoyevskiy)',
      'quantity':quantity,'unit_price':unitPrice},
  ];

  test('missing catalog match explains why save cannot proceed', () {
    final reason=preorderInvoiceValidationError(
      lines(bookId:null),requestedQuantity:1);
    expect(reason,contains('katalogdagi kitobni tanlang'));
    expect(reason,contains('Faqat narx yozish yetarli emas'));
  });

  test('valid title, quantity and price allow invoice save', () {
    expect(preorderInvoiceValidationError(lines(),requestedQuantity:1),isNull);
  });

  test('zero quantity and price explain precise invalid field', () {
    expect(preorderInvoiceValidationError(
      lines(quantity:0),requestedQuantity:1),contains('miqdor'));
    expect(preorderInvoiceValidationError(
      lines(unitPrice:0),requestedQuantity:1),contains('narxini'));
  });

  test('partial arrival must use Shular keldi instead of altering full order', () {
    final reason=preorderInvoiceValidationError(
      lines(quantity:1),requestedQuantity:3);
    expect(reason,contains('Shular keldi'));
  });

  test('multiple catalog lines match complete ordered total', () {
    final input=[
      {'book_id':'id-1','title':'Birinchi','quantity':2,'unit_price':18000},
      {'book_id':'id-2','title':'Ikkinchi','quantity':1,'unit_price':24000},
    ];
    expect(preorderInvoiceValidationError(input,requestedQuantity:3),isNull);
    expect(preorderInvoiceValidationError(input,requestedQuantity:4),
      contains('4 dona'));
  });
}
