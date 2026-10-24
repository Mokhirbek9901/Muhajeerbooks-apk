import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/muhajeer_ai.dart';

Book book(String id, String title, {
  String author = '',
  String category = 'Badiiy',
  String description = '',
  int stock = 3,
  bool active = true,
}) => Book(
  id: id,
  title: title,
  author: author,
  category: category,
  description: description,
  price: 12000,
  stock: stock,
  discountPercent: 0,
  imageUrl: '',
  isActive: active,
);

void main() {
  test('AI qidiruv aniq nomni topadi', () {
    final books = [book('1', 'Oq nilufarlar'), book('2', 'Binafsha shu’lasi')];
    expect(MuhajeerAi.localSearch('Oq nilufarlar', books).first, '1');
  });

  test('AI qidiruv apostrof va bitta imlo xatosini taniydi', () {
    final books = [book('1', 'Binafsha shu’lasi')];
    expect(MuhajeerAi.localSearch('Binafsha shulasi', books), ['1']);
    expect(MuhajeerAi.localSearch('Binafsha shulas', books), ['1']);
  });

  test('AI qidiruv 500 tadan keyingi kitobni ham topadi', () {
    final books = [
      for (var i = 0; i < 550; i++) book('old-$i', 'Oddiy ertak $i'),
      book('new', 'Pul psixologiyasi'),
    ];
    expect(MuhajeerAi.localSearch('Pul psixologiyasi', books).first, 'new');
  });

  test('AI qidiruv faol emas kitobni ko‘rsatmaydi', () {
    final books = [book('hidden', 'Pul psixologiyasi', active: false)];
    expect(MuhajeerAi.localSearch('Pul psixologiyasi', books), isEmpty);
  });

  test('AI qidiruv faqat umumiy so‘z bilan barcha kitobni chiqarmaydi', () {
    final books = [book('1', 'Oq nilufarlar')];
    expect(MuhajeerAi.localSearch('kitob', books), isEmpty);
    expect(MuhajeerAi.localSearch('', books), isEmpty);
  });

  test('O‘xshash kitoblarda asosiy kitob takrorlanmaydi', () {
    final books = [
      book('1', 'Binafsha shu’lasi', category: 'Badiiy'),
      book('2', 'Oq nilufarlar', category: 'Badiiy'),
      book('3', 'Pul psixologiyasi', category: 'Biznes'),
    ];
    final result = MuhajeerAi.localSearch('Binafsha shu’lasi', books, mode: 'similar');
    expect(result, contains('2'));
    expect(result, isNot(contains('1')));
  });
}
