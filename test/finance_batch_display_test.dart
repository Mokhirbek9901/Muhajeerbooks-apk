import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/finance_batch_display.dart';

void main() {
  const group = 'fixture-group';
  final amounts = [486630, 168868, 107520, 104439, 120443];
  final imports = List.generate(5, (i) => <String, dynamic>{
    'id': i + 1,
    'finance_expense_id': 'purchase-$i',
    'finance_group_id': group,
    'finance_group_title': 'Sinov partiyasi',
    'finance_group_date': '2026-05-15',
  });
  final source = [
    for (var i = 0; i < amounts.length; i++)
      <String, dynamic>{
        'id': 'purchase-$i',
        'expense_date': '2026-05-15',
        'category': 'inventory_purchase',
        'amount': amounts[i],
      },
    <String, dynamic>{
      'id': 'transport',
      'expense_date': '2026-05-15',
      'category': 'transport',
      'amount': 19700,
    },
    <String, dynamic>{
      'id': 'ads',
      'expense_date': '2026-05-15',
      'category': 'ads',
      'amount': 3000,
    },
  ];
  final transport = [
    <String, dynamic>{'id': 'transport', 'batch_import_id': 1},
  ];

  test('five purchases plus linked transport become one display row', () {
    final before = source.fold<int>(0, (n, row) => n + row['amount'] as int);
    final shown = consolidatedFinanceDisplayRows(
      rows: source,
      purchases: imports,
      transports: transport,
    );
    expect(shown.length, 2);
    expect(shown.singleWhere((r) => r['_consolidated_display_only'] == true)
      ['amount'], 1007600);
    expect(shown.singleWhere((r) => r['_consolidated_display_only'] == true)
      ['expense_date'], '2026-05-15');
    expect(shown.singleWhere((r) => r['id'] == 'ads')['amount'], 3000);
    expect(shown.fold<int>(0, (n, row) => n + row['amount'] as int), before);
    expect(source.length, 7);
    expect(source.last['id'], 'ads');
  });

  test('all six historical expenses appear as a single sample day item', () {
    final day9 = source.where((r) =>
      r['expense_date'] == '2026-05-15').toList();
    final shown = consolidatedFinanceDisplayRows(
      rows: day9, purchases: imports, transports: transport);
    final group = shown.singleWhere(
      (r) => r['_consolidated_display_only'] == true);
    expect(group['amount'], 1007600);
    expect(group['expense_date'], '2026-05-15');
    expect(group['note'], contains('Sinov partiyasi'));
    expect(shown.fold<int>(0, (n, row) => n + (row['amount'] as int)),
      1010600);
    expect(shown.length, 2);
  });

  test('unlinked and missing overview do not fabricate groups', () {
    final shown = consolidatedFinanceDisplayRows(
      rows: source, purchases: [], transports: []);
    expect(shown.length, source.length);
    expect(shown.map((e) => e['amount']).toList(),
      source.map((e) => e['amount']).toList());
  });
}
