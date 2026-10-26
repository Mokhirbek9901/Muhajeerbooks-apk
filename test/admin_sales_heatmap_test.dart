import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_sales_heatmap.dart';

void main() {
  test('sales heatmap levels match volume, not sale revenue', () {
    expect(AdminSalesHeatmap.countOf({'sold':0}),0);
    expect(AdminSalesHeatmap.countOf({'sold':4,'revenue':9999999}),4);
    expect(AdminSalesHeatmap.levelColor(0),AdminSalesHeatmap.colors[0]);
    expect(AdminSalesHeatmap.levelColor(1),AdminSalesHeatmap.colors[1]);
    expect(AdminSalesHeatmap.levelColor(10),AdminSalesHeatmap.colors[4]);
  });

  testWidgets('30-day heatmap shows exact daily volume and opens day totals',
      (tester) async {
    final days=<Map<String,dynamic>>[
      for(var n=1;n<=30;n++)
        {
          'date':'2026-10-${n.toString().padLeft(2,'0')}',
          'sold':n==15?3:0,
          'revenue':n==15?48000:0,
          'profit':n==15?12000:0,
        },
    ];
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:Padding(
        padding:const EdgeInsets.all(12),
        child:AdminSalesHeatmap(
          days:days,totalSold:3,activeDays:1),
      )),
    )));
    expect(find.text('Sotuv faolligi (oxirgi 30 kun)'),findsOneWidget);
    expect(find.text('3 dona'),findsOneWidget);
    expect(find.text('1 / 30'),findsOneWidget);
    expect(find.text('Kam'),findsOneWidget);
    expect(find.text('Ko‘p'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
