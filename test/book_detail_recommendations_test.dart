import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/store_ui.dart';

Book sampleBook(String id, String title, String author, String category,
    {int stock=3,bool active=true,bool preorder=false}) =>
    Book(id:id,title:title,author:author,category:category,
      description:'Kitob tavsifi',price:15000,stock:stock,
      discountPercent:0,imageUrl:'',isActive:active,
      preorderEnabled:preorder);

class _BooksState extends AppState {
  _BooksState(this.catalog):super(backendConfigured:false);
  final List<Book> catalog;
  @override List<Book> get books=>catalog;
}

void main(){
  final current=sampleBook('main','Asosiy kitob','Muallif A','Psixologiya');
  final sameAuthor=sampleBook('author','Muallifning kitobi','Muallif A','Tarix');
  final sameCategory=sampleBook('similar','Shunga yaqin','Muallif B','Psixologiya');
  final hidden=sampleBook('hidden','Yashirilgan','Muallif B','Psixologiya',active:false);
  final soldout=sampleBook('soldout','Tugagan','Muallif B','Psixologiya',stock:0);
  final preorder=sampleBook('preorder','Oldindan sotuv','Muallif C','Psixologiya',
    stock:0,preorder:true);

  test('author shelf is separate from similar category and excludes current book',(){
    final books=[current,sameAuthor,sameCategory,hidden,soldout,preorder];
    expect(otherBooksByAuthor(current,books).map((b)=>b.id).toList(),['author']);
    expect(similarAvailableBooks(current,books).map((b)=>b.id).toSet(),
      {'similar','preorder'});
  });

  test('author books appear even when original product is in stock',(){
    expect(current.stock,greaterThan(0));
    expect(otherBooksByAuthor(current,[current,sameAuthor]),[sameAuthor]);
    expect(similarAvailableBooks(current,[current,sameCategory]),[sameCategory]);
  });

  testWidgets('book details show both shelves and no review controls', (tester) async {
    tester.view.physicalSize=const Size(390,1350);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state=_BooksState([current,sameAuthor,sameCategory,hidden,soldout,preorder]);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value:state,
      child:MaterialApp(home:BookDetailPage(bookId:current.id)),
    ));
    await tester.pump();
    expect(find.text('Yozuvchining boshqa kitoblari'),findsOneWidget);
    expect(find.text('Shunga o‘xshash kitoblar'),findsOneWidget);
    expect(find.text('Muallifning kitobi'),findsOneWidget);
    expect(find.text('Shunga yaqin'),findsOneWidget);
    expect(find.text('Sharh qoldirish'),findsNothing);
    expect(find.text('Kitob bahosi va sharhlar'),findsNothing);
    expect(find.text('Savatga solish'),findsWidgets);
    expect(tester.takeException(),isNull);
  });
}
