import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_batch_inline_editor.dart';

void main() {
  final catalog=<Map<String,dynamic>>[
    {'id':'old-book','title':'Assassin','cost_price':12000},
    {'id':'one','title':'Yashamoq','cost_price':7500},
    {'id':'two','title':'O‘tkan kunlar','cost_price':11500},
    {'id':'three','title':'1984','cost_price':13000},
    {'id':'old-alias','title':'Tobeʼyinlardan maktublar','cost_price':8500},
  ];

  test('existing book ids and normalized title aliases stay hidden', () {
    final allowed=availableBatchPickerBooks(catalog,
      excludedBookIds:{'old-book'},
      excludedTitles:{"Tobe'yinlardan maktublar"},
    );
    expect(allowed.map((x)=>x['id']).toList(),['one','two','three']);
  });

  testWidgets('select several books across searches, then return all at once',
    (tester) async {
      List<Map<String,dynamic>>? result;
      await tester.pumpWidget(MaterialApp(home:Scaffold(
        body:Builder(builder:(context)=>FilledButton(
          child:const Text('Ochish'),
          onPressed:() async {
            result=await showModalBottomSheet<List<Map<String,dynamic>>>(
              context:context,isScrollControlled:true,
              builder:(_)=>BatchBookMultiPicker(
                catalog:catalog,
                excluded:const {'old-book'},
                excludedTitles:const {"Tobe'yinlardan maktublar"},
              ));
          },
        )),
      )));
      await tester.tap(find.text('Ochish'));
      await tester.pumpAndSettle();

      expect(find.text('Assassin'),findsNothing);
      expect(find.text('Tobeʼyinlardan maktublar'),findsNothing);
      expect(find.text('Yashamoq'),findsOneWidget);
      expect(find.text('Tanlangan: 0 ta kitob'),findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('batch-picker-book-one')));
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan: 1 ta kitob'),findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('batch-multi-picker-search')), 'O‘tkan');
      await tester.pumpAndSettle();
      expect(find.text('Yashamoq'),findsNothing);
      await tester.tap(find.byKey(const ValueKey('batch-picker-book-two')));
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan: 2 ta kitob'),findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('batch-multi-picker-search')), '1984');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('batch-picker-book-three')));
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan: 3 ta kitob'),findsOneWidget);

      await tester.tap(find.byKey(
        const ValueKey('batch-multi-picker-add-selected')));
      await tester.pumpAndSettle();
      expect(result?.map((x)=>x['id']).toList(),['one','two','three']);
      expect(result?.map((x)=>x['cost_price']).toList(),[7500,11500,13000]);
      expect(find.text('Partiyaga kitoblarni tanlash'),findsNothing);
    });

  testWidgets('unselecting removes only that draft book; cancellation writes none',
    (tester)async{
      List<Map<String,dynamic>>? result;
      await tester.pumpWidget(MaterialApp(home:Scaffold(
        body:Builder(builder:(context)=>FilledButton(
          onPressed:() async{
            result=await showModalBottomSheet<List<Map<String,dynamic>>>(
              context:context,
              isScrollControlled:true,
              builder:(_)=>BatchBookMultiPicker(
                catalog:catalog,
                excluded:const {'old-book'},
                excludedTitles:const {},
              ));
          },
          child:const Text('Ochish'),
        )),
      )));
      await tester.tap(find.text('Ochish'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('batch-picker-book-one')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('batch-picker-book-one')));
      await tester.pumpAndSettle();
      expect(find.text('Tanlangan: 0 ta kitob'),findsOneWidget);
      final saveButton=tester.widget<FilledButton>(
        find.byKey(const ValueKey('batch-multi-picker-add-selected')));
      expect(saveButton.onPressed,isNull);
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(result,isNull);
    });
}
