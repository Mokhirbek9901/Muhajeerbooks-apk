import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_profit_batches.dart';

void main() {
  final lots=<Map<String,dynamic>>[
    {'group_key':'date:2026-10-10','book_title':'Uzrnoma',
     'quantity':2,'unit_cost':7900,'sale_price':14000},
  ];
  final groups=<Map<String,dynamic>>[
    {'group_key':'date:2026-08-01','title':'01.08.2026 partiyasi',
      'date':'2026-08-01','purchased_units':92,'book_titles':51,
      'projected_profit':434477},
    {'group_key':'finance:8c07f621-112d-450b-a7f8-f15f6e215279',
      'title':'9.09.2026 — Birlashgan kitob partiyasi',
      'date':'2026-09-09','missing_lot_details':true,
      'finance_purchase_count':5,'finance_recorded_cost':1007600,
      'projected_profit':null,'purchased_units':0,'book_titles':0},
    {'group_key':'date:2026-10-10','title':'10.10.2026 partiyasi',
      'date':'2026-10-10','purchased_units':127,'book_titles':26,
      'projected_profit':823675},
  ];

  test('consolidated Sep purchase appears in calendar order', () {
    final ordered=sortedProfitBatchGroups(groups);
    expect(ordered.map((g)=>g['date']).toList(),
       ['2026-10-10','2026-09-09','2026-08-01']);
  });

  testWidgets('Sep finance group shows missing data, never fictional zero profit',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:AdminProfitBatchPanel(
        groups:groups,lots:lots)))));
    expect(find.textContaining('9.09.2026'),findsOneWidget);
    expect(find.text('Hisoblanmagan'),findsOneWidget);
    expect(find.textContaining('Kitoblar kiritilmagan'),findsOneWidget);
    expect(find.textContaining('1,007,600'),findsOneWidget);
    await tester.tap(find.textContaining('9.09.2026'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 ta'),findsWidgets);
    expect(find.textContaining('partiyaga kiriting'),findsOneWidget);
  });
}
