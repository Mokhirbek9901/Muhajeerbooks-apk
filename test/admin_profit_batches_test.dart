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

  testWidgets('every dated batch displays three sourced monetary figures',
      (tester) async {
    final groups=<Map<String,dynamic>>[
      {
        'group_key':'date:2026-12-01','title':'Yangi partiya',
        'date':'2026-12-01','purchased_units':2,'book_titles':1,
        'total_purchase_cost':15000,'projected_profit':5000,
        'estimated_sold_units':0,'estimated_remaining_units':2,
        'dated_order_sales_units':0,'dated_legacy_sales_units':0,
        'dated_order_gross_profit':0,'date_fifo_applied':true,
      },
      {
        'group_key':'date:2026-09-09','title':'Eski partiya',
        'date':'2026-09-09','purchased_units':3,'book_titles':2,
        'total_purchase_cost':30000,'projected_profit':12000,
        'estimated_sold_units':2,'estimated_remaining_units':1,
        'dated_order_sales_units':1,'dated_legacy_sales_units':1,
        'dated_order_gross_profit':3000,'date_fifo_applied':true,
      },
    ];
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:AdminProfitBatchPanel(
        groups:groups,lots:const [])))));
    expect(find.text('Partiya tan narxi'),findsNWidgets(2));
    expect(find.text('Kutilayotgan foyda'),findsNWidgets(2));
    expect(find.text('Hozirgacha olingan foyda'),findsNWidgets(2));
    expect(find.text('₩15,000'),findsOneWidget);
    expect(find.text('₩5,000'),findsOneWidget);
    expect(find.text('₩0'),findsOneWidget);
    expect(find.text('₩30,000'),findsOneWidget);
    expect(find.text('₩12,000'),findsOneWidget);
    expect(find.text('₩3,000'),findsOneWidget);
    expect(find.textContaining('eski narxsiz sotuv kiritilmagan'),
      findsOneWidget);
    // Neither the FIFO row nor the existing batch details are removed.
    expect(find.text('Sotuv sanasi bo‘yicha FIFO'),findsNWidgets(2));
  });

  testWidgets('unpriced historical sales never get an invented profit',
      (tester) async {
    final groups=<Map<String,dynamic>>[
      {
        'group_key':'date:2026-09-09','title':'Tarixiy partiya',
        'date':'2026-09-09','purchased_units':2,'book_titles':1,
        'total_purchase_cost':20000,'projected_profit':6000,
        'estimated_sold_units':1,'estimated_remaining_units':1,
        'dated_order_sales_units':0,'dated_legacy_sales_units':1,
        'dated_order_gross_profit':0,'date_fifo_applied':true,
      },
      {
        'group_key':'finance:123','title':'Kitoblari kiritilmagan',
        'date':'2026-08-01','missing_lot_details':true,
        'finance_purchase_count':1,'finance_recorded_cost':25000,
      },
    ];
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:AdminProfitBatchPanel(
        groups:groups,lots:const [])))));
    expect(find.text('Hozirgacha olingan foyda'),findsNWidgets(2));
    expect(find.text('—'),findsNWidgets(4));
    expect(find.textContaining('aniq hisoblab bo‘lmaydi'),findsOneWidget);
    expect(find.text('Kitoblari kiritilmagan'),findsOneWidget);
  });

}
