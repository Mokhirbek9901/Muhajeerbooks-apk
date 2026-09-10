import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_state.dart';

void main() {
  Book book(String id, String publisher, {bool active = true}) => Book.fromMap({
    'id': id, 'title': id, 'publisher': publisher, 'is_active': active,
  });

  test('publisher survives cloud/cache serialization and stock edits', () {
    final original = book('1', '  Hilol   Nashr  ');
    final edited = original.copyWith(stock: 9);
    expect(edited.publisher, 'Hilol Nashr');
    expect(Book.fromMap(edited.toLocalMap()).publisher, 'Hilol Nashr');
    expect(edited.toDbMap()['publisher'], 'Hilol Nashr');
    expect(edited.copyWith(publisher: '').publisher, '');
    expect(Book.fromMap({'id': 'old'}).publisher, '');
  });

  test('only named active publishers are grouped and renaming updates groups', () {
    final books = [book('1', 'Hilol Nashr'), book('2', ' hilol  nashr '),
      book('3', ''), book('4', 'Hidden', active: false), book('5', 'Asaxiy')];
    expect(bookPublishers(books), ['Asaxiy', 'Hilol Nashr']);
    expect(books.where((b) => b.isActive &&
      publisherKey(b.publisher) == publisherKey('HILOL NASHR')).length, 2);
    books[0] = books[0].copyWith(publisher: 'Yangi');
    books[1] = books[1].copyWith(publisher: 'Yangi');
    expect(bookPublishers(books), ['Asaxiy', 'Yangi']);
  });
}
