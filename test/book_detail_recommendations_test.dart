import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/store_ui.dart';

const current=Book(
  id:'book-1',title:'Sun’iy intellekt',author:'Muallif A',
  category:'Texnologiya',description:'Kitob haqida',
  price:15000,stock:4,discountPercent:0,imageUrl:'',isActive:true);
const byAuthor=Book(
  id:'book-2',title:'Muallifning ikkinchi kitobi',author:'Muallif A',
  category:'Tarix',description:'',price:10000,stock:2,discountPercent:0,
  imageUrl:'',isActive:true);
const byCategory=Book(
  id:'book-3',title:'Shu turdagi boshqa kitob',author:'Muallif B',
  category:'Texnologiya',description:'',price:12000,stock:3,discountPercent:0,
  imageUrl:'',isActive:true);
const inactive=Book(
  id:'book-4',title:'Yashirilgan kitob',author:'Muallif A',
  category:'Texnologiya',description:'',price:5000,stock:1,discountPercent:0,
  imageUrl:'',isActive:false);

class BooksForDetail extends AppState {
  BooksForDetail({this.selected=current}):super(backendConfigured:false);
  final Book selected;
  @override List<Book> get books=>[selected,byAuthor,byCategory,inactive];
}

void main(){
  test('other books lists exclude original and inactive records',(){
    final books=[current,byAuthor,byCategory,inactive];
    expect(otherBooksByAuthor(current,books).map((b)=>b.id).toList(),
      ['book-2']);
    expect(otherBooksInCategory(current,books).map((b)=>b.id).toList(),
      ['book-3']);
    expect(otherBooksByAuthor(
      const Book(id:'missing',title:'A',author:'',category:'A',
        description:'',price:0,stock:0,discountPercent:0,imageUrl:'',
        isActive:true),books),isEmpty);
  });

  testWidgets('App Store details restore author and category lists, not reviews',
    (tester)async{
      tester.view.physicalSize=const Size(390,1300);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>(
        create:(_)=>BooksForDetail(),
        child:const MaterialApp(home:BookDetailPage(bookId:'book-1')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Yozuvchining boshqa kitoblari'),findsOneWidget);
      expect(find.text('Shunga o‘xshash kitoblar'),findsOneWidget);
      expect(find.text('Muallifning ikkinchi kitobi'),findsOneWidget);
      expect(find.text('Shu turdagi boshqa kitob'),findsOneWidget);
      expect(find.text('Sharh qoldirish'),findsNothing);
      expect(find.text('Kitob bahosi va sharhlar'),findsNothing);
      expect(tester.takeException(),isNull);
    },
  );
}
