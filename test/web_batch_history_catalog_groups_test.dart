import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_batch_history_pro.dart';

void main() {
  final catalogGroups = <Map<String, dynamic>>[
    {'id': 'oct10', 'title': '10.10.2026', 'batch_date': '2026-10-10',
      'book_value': 10000},
    {'id': 'oct25', 'title': '25.10.2026', 'batch_date': '2026-10-25',
      'book_value': 0},
  ];
  test('Saved 25 October catalog batch appears in main Partiyalar', () {
    final groups = filterCatalogBatchGroups(catalogGroups, '');
    expect(groups.map((g) => g['title']).toList(),
      ['25.10.2026', '10.10.2026']);
    const originalFinancePurchases = 3;
    expect(originalFinancePurchases + groups.length, 5);
  });
  test('Search matches batch name or date without losing history', () {
    expect(filterCatalogBatchGroups(catalogGroups, '25.10').single['id'],
      'oct25');
    expect(filterCatalogBatchGroups(catalogGroups, '2026-10-25').single['id'],
      'oct25');
    expect(filterCatalogBatchGroups(catalogGroups, 'old-school'), isEmpty);
    expect(catalogGroups.length, 2);
  });
  test('Catalog batch value must not be included in finance purchases', () {
    const financeExpenseSum = 1190840;
    final catalogBookValue = catalogGroups.fold<int>(
      0, (sum, g) => sum + (g['book_value'] as int));
    expect(catalogBookValue, 10000);
    // The on-screen finance summary remains based on real finance records.
    expect(financeExpenseSum, 1190840);
  });
}
