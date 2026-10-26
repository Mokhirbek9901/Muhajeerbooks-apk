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

  testWidgets('Search filters existing batch titles without changing saved totals',
    (tester)async{
    await tester.pumpWidget(app());
    expect(find.text('Yashil kitob'),findsOneWidget);
    expect(find.text('Tobeʼyinlardan maktublar'),findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('batch-book-search')),
      'yashil');
    await tester.pumpAndSettle();
    expect(find.text('Yashil kitob'),findsOneWidget);
    expect(find.text('Tobeʼyinlardan maktublar'),findsNothing);
    expect(find.text('Topildi: 1 ta'),findsOneWidget);
    expect(find.text('2 xil · 14 dona'),findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('batch-book-search')),
      'asdasd-not-found');
    await tester.pumpAndSettle();
    expect(find.text('Bu partiyada qidiruvga mos kitob topilmadi.'),
      findsOneWidget);
    expect(find.text('Kitob qo‘shish'),findsOneWidget);
  });

  testWidgets('Search while editing keeps unsaved counts for hidden books',
    (tester)async{
    await tester.pumpWidget(app());
    await tester.tap(find.text('Tahrirlash'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('batch-book-search')),
      'YASHIL');
    await tester.pumpAndSettle();
    expect(find.text('Yashil kitob'),findsOneWidget);
    expect(find.text('Tobeʼyinlardan maktublar'),findsNothing);
    expect(find.byIcon(Icons.add_rounded),findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('11'),findsOneWidget);
    expect(find.text('2 xil · 15 dona (tahrir)'),findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('batch-book-search')),
      "tobe'yin");
    await tester.pumpAndSettle();
    expect(find.text('Tobeʼyinlardan maktublar'),findsOneWidget);
    expect(find.text('Yashil kitob'),findsNothing);
    expect(find.text('2 xil · 15 dona (tahrir)'),findsOneWidget);
    await tester.ensureVisible(find.text('Bekor qilish'));
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(find.text('2 xil · 14 dona'),findsOneWidget);
    expect(find.byIcon(Icons.remove_rounded),findsNothing);
  });

  testWidgets('Correcting partiya unit price updates draft total only',
    (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Tahrirlash'));
    await tester.pumpAndSettle();
    expect(find.text('₩130,672'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-batch-cost-123')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('batch-unit-cost-input')),'7900');
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(find.text('Tan narx: ₩7,900'),findsOneWidget);
    expect(find.text('₩140,672'),findsOneWidget);
    expect(find.textContaining('O‘zgarish: +₩10,000'),findsOneWidget);
    await tester.ensureVisible(find.text('Bekor qilish'));
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(find.text('10 dona · 1 dona ₩6,900'),findsOneWidget);
    expect(find.byKey(const ValueKey('batch-draft-cost-summary')),findsNothing);
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
