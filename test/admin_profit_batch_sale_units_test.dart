import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_profit_batches.dart';

void main() {
  testWidgets('batch shows units sold and percent distinct from profit share',
      (tester) async {
    final groups=<Map<String,dynamic>>[
      {
        'group_key':'g1','title':'25.10.2026',
        'purchased_units':86,'book_titles':30,
        'estimated_sold_units':6,'projected_profit':550306,
        'date':'2026-10-25',
      },
      {
        'group_key':'g2','title':'10.10.2026',
        'purchased_units':127,'book_titles':26,
        'estimated_sold_units':20,'projected_profit':823675,
        'date':'2026-10-10',
      },
    ];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:
      SingleChildScrollView(child:AdminProfitBatchPanel(
        groups:groups,lots:const [],
      )),
    )));
    expect(find.text('86 dona kelgan · 30 xil kitob'),findsOneWidget);
    expect(find.text('6 / 86 dona taxminiy sotilgan'),findsOneWidget);
    expect(find.text('7%'),findsOneWidget);
    expect(find.text('Foyda ulushi: 40%'),findsOneWidget);
    expect(find.textContaining('Taxminiy sotilish (FIFO)'),findsWidgets);
  });
}
