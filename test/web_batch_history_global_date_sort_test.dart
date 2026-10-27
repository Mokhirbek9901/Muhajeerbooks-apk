import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_batch_history_pro.dart';

void main() {
  final catalog = <Map<String, dynamic>>[
    {
      'id': 'sept09', 'title': '9.09.2026 Partiyasi',
      'batch_date': '2026-09-09', 'book_value': 12000,
    },
    {
      'id': 'oct25', 'title': '25.10.2026',
      'batch_date': '2026-10-25', 'book_value': 823634,
    },
  ];
  final purchases = <Map<String, dynamic>>[
    {
      'id': 6, 'title': '2026-08 gacha qolgan kitoblar',
      'purchase_date': '2026-08-01', 'total_krw': 822489,
    },
    {
      'id': 7, 'title': 'Yangi partiya kitob',
      'purchase_date': '2026-10-10', 'total_krw': 1190840,
    },
  ];

  test('mixed sources sort by incoming batch date, not by source section', () {
    final entries = sortBatchHistoryByReceiptDate(
      catalogGroups: catalog, financePurchases: purchases);
    expect(entries.map((e) =>
      (e['item'] as Map<String, dynamic>)['title']).toList(), [
        '25.10.2026',
        'Yangi partiya kitob',
        '9.09.2026 Partiyasi',
        '2026-08 gacha qolgan kitoblar',
      ]);
    expect(entries.map((e) => e['date']).toList(), [
      '2026-10-25', '2026-10-10', '2026-09-09', '2026-08-01',
    ]);
    expect(entries.map((e) => e['kind']).toList(),
      ['catalog', 'finance', 'catalog', 'finance']);
  });

  test('sort is read-only and leaves money and counts unchanged', () {
    final originalCatalogOrder = catalog.map((e) => e['id']).toList();
    final originalFinanceOrder = purchases.map((e) => e['id']).toList();
    final entries = sortBatchHistoryByReceiptDate(
      catalogGroups: catalog, financePurchases: purchases);
    expect(entries.length, 4);
    expect(catalog.map((e) => e['id']).toList(), originalCatalogOrder);
    expect(purchases.map((e) => e['id']).toList(), originalFinanceOrder);
    expect(catalog.fold<int>(0, (sum, row) =>
      sum + (row['book_value'] as int)), 835634);
    expect(purchases.fold<int>(0, (sum, row) =>
      sum + (row['total_krw'] as int)), 2013329);
  });

  test('search results are still globally date-sorted', () {
    final catalogResults = filterCatalogBatchGroups(catalog, '2026');
    final purchaseResults = purchases.where((p) =>
      (p['title'] ?? '').toString().contains('2026')).toList();
    final entries = sortBatchHistoryByReceiptDate(
      catalogGroups: catalogResults,
      financePurchases: purchaseResults,
    );
    expect(entries.map((e) => e['date']).toList(),
      ['2026-10-25','2026-09-09','2026-08-01']);
  });

  test('empty inputs and same-day batches are safe', () {
    expect(sortBatchHistoryByReceiptDate(
      catalogGroups: [],financePurchases: []), isEmpty);
    final entries = sortBatchHistoryByReceiptDate(
      catalogGroups: [
        {'id': 'same', 'batch_date': '2026-10-10'}
      ],
      financePurchases: [
        {'id': 14, 'purchase_date': '2026-10-10'},
      ],
    );
    expect(entries.length, 2);
    expect(entries.every((e) => e['date'] == '2026-10-10'), isTrue);
  });
}
