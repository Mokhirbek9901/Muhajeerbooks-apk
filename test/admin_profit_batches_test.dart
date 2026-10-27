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
}
