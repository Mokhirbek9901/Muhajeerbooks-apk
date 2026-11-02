import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_profit_batches.dart';

void main(){
  testWidgets('shows sourced purchase batch and projected margin', (tester) async {
    final groups=<Map<String,dynamic>>[{
      'group_key':'date:2026-10-10','title':'10.10.2026 partiyasi',
      'date':'2026-10-10','purchased_units':2,
      'book_titles':1,'projected_profit':10000,
    }];
    final lots=<Map<String,dynamic>>[{
      'id':17,'group_key':'date:2026-10-10',
      'book_id':'book-1','book_title':'Nafs tarbiyasi',
      'quantity':2,'unit_cost':10000,
      'sale_price':15000,'projected_profit':10000,
      'purchased_at':'2026-10-10',
    }];
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:SingleChildScrollView(
        child:AdminProfitBatchPanel(groups:groups,lots:lots)))));
    expect(find.text('Partiyalar bo‘yicha foyda'),findsOneWidget);
    expect(find.text('10.10.2026 partiyasi'),findsOneWidget);
    expect(find.text('₩10,000'),findsWidgets);
    expect(find.textContaining('Foyda ulushi sotilish foizi emas'),findsOneWidget);
    await tester.tap(find.text('10.10.2026 partiyasi'));
    await tester.pumpAndSettle();
    expect(find.text('Nafs tarbiyasi'),findsOneWidget);
    expect(find.text('O‘sha partiyadagi tan narxi'),findsOneWidget);
    expect(find.textContaining('hali haqiqiy olingan foyda emas'),findsOneWidget);
  });
  test('actual FIFO margin is unknown without sales allocation, never projected', () {
    expect(recognizedFifoBatchGrossProfit({
      'projected_profit':149594,'estimated_sold_units':0,
    }),isNull);
    expect(recognizedFifoBatchGrossProfit({
      'date_fifo_applied':true,'dated_order_gross_profit':212000,
      'projected_profit':557705,'dated_order_sales_units':33,
    }),212000);
    expect(recognizedFifoBatchGrossProfit({
      'date_fifo_applied':true,'dated_order_gross_profit':-1000,
      'projected_profit':7000,
    }),-1000);
    expect(recognizedFifoBatchGrossProfit({
      'date_fifo_applied':true,'dated_legacy_sales_units':22,
      'projected_profit':805143,
    }),isNull);
  });

  testWidgets('chosen first layout shows expected and to-date amounts separately',
      (tester) async {
    final groups=<Map<String,dynamic>>[{
      'group_key':'g1','title':'25.10.2026',
      'date':'2026-10-25','purchased_units':87,
      'estimated_sold_units':33,'estimated_remaining_units':54,
      'book_titles':30,'projected_profit':557705,
      'date_fifo_applied':true,'dated_order_gross_profit':212000,
      'dated_order_sales_units':33,
    }];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(
      child:AdminProfitBatchPanel(groups:groups,lots:const [])))));
    expect(find.text('₩557,705'),findsOneWidget);
    expect(find.text('Hozirgacha: ₩212,000'),findsOneWidget);
    expect(find.text('Foyda ulushi: 100%'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('missing historical sale prices show unknown, not zero',
      (tester) async {
    final group=<String,dynamic>{
      'group_key':'g','title':'Eski partiya',
      'date':'2026-09-09','purchased_units':4,
      'estimated_sold_units':2,'projected_profit':40000,
      'book_titles':1,'date_fifo_applied':false,
    };
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:AdminProfitBatchPanel(groups:[group],lots:const []))));
    expect(find.text('₩40,000'),findsOneWidget);
    expect(find.text('Hozirgacha: —'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

}
