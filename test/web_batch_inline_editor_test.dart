import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_batch_inline_editor.dart';

void main(){
  final history=<Map<String,dynamic>>[
    {
      'id':123, 'book_id':'0ef72aa3-4fac-48e4-ab52-710942d81a10',
      'title':'Yashil kitob','quantity':10,'unit_cost':6900,
      'inventory_applied':false
    },
    {
      'id':124, 'book_id':'9b2fc831-4e89-4c38-8b40-17ad1cf9e5bf',
      'title':'Tobeʼyinlardan maktublar','quantity':4,'unit_cost':15418,
      'inventory_applied':false
    },
  ];
  Widget app()=>MaterialApp(home:Scaffold(
    body:SingleChildScrollView(child:Padding(
      padding:const EdgeInsets.all(12),child:WebBatchInlineEditor(
        secret:'test',kind:'import',batchKey:'6',lines:history,
        onSaved:(){},
      )))));

  testWidgets('Hide plus-minus, removal and Save before edit mode', (tester)async{
    await tester.pumpWidget(app());
    expect(find.text('Yashil kitob'),findsOneWidget);
    expect(find.text('10 dona · 1 dona ₩6,900'),findsOneWidget);
    expect(find.text('Kitob qo‘shish'),findsOneWidget);
    expect(find.text('Tahrirlash'),findsOneWidget);
    expect(find.byIcon(Icons.remove_rounded),findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded),findsNothing);
    expect(find.text('Saqlash'),findsNothing);
  });

  testWidgets('Steppers appear only after edit, cancel leaves saved count',
    (tester)async{
    await tester.pumpWidget(app());
    await tester.tap(find.text('Tahrirlash'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.remove_rounded),findsNWidgets(2));
    expect(find.byIcon(Icons.more_horiz_rounded),findsNWidgets(2));
    expect(find.text('Saqlash'),findsOneWidget);
    final adds=find.byIcon(Icons.add_rounded);
    await tester.tap(adds.first);
    await tester.pumpAndSettle();
    expect(find.text('11'),findsOneWidget);
    await tester.ensureVisible(find.text('Bekor qilish'));
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(find.text('10 dona · 1 dona ₩6,900'),findsOneWidget);
    expect(find.byIcon(Icons.remove_rounded),findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded),findsNothing);
  });
}
