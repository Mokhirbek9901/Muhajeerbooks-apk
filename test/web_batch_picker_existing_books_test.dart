import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_batch_inline_editor.dart';

void main() {
  final catalog=<Map<String,dynamic>>[
    {'id':'book-a','title':'Cho‘pon yutib ketdi'},
    {'id':'book-b','title':'Dafina'},
    {'id':'book-c','title':'Daftar hoshiyasidagi bitiklar'},
    {'id':'book-d','title':'Yangi kelgan asar'},
  ];

  test('saved batch IDs disappear; other unsaved books remain', () {
    final visible=availableBatchPickerBooks(catalog,
      excludedBookIds:['book-a','book-b'],
      excludedTitles:[],
    );
    expect(visible.map((b)=>b['id']).toList(), ['book-c','book-d']);
  });

  test('a saved title disappears even when legacy ID differs', () {
    final visible=availableBatchPickerBooks(catalog,
      excludedBookIds:['historic-other-id'],
      excludedTitles:["  CHO'PON    YUTIB KETDI  "],
    );
    expect(visible.map((b)=>b['id']).toList(),['book-b','book-c','book-d']);
  });

  test('search only returns books not previously saved in this batch', () {
    final visible=availableBatchPickerBooks(catalog,
      excludedBookIds:['book-b'],
      excludedTitles:[],
      query:'daf',
    );
    expect(visible,isEmpty);
    expect(availableBatchPickerBooks(catalog,
      excludedBookIds:['book-b'],excludedTitles:[],query:'yangi').single['id'],
      'book-d');
  });

  test('Uzrnoma from August stock is available for 10 October batch', () {
    final books = <Map<String,dynamic>>[
      {'id':'7e0d54ad-4696-4aa2-89d6-e239b60b250d','title':'Uzrnoma'},
      {'id':'oct10-existing','title':'Oldin kiritilgan kitob'},
    ];
    // Only the October 10 (import 7) lines are excluded; an August
    // (import 6) receipt for Uzrnoma does not hide the same catalog book.
    final octoberSaved = <String>['oct10-existing'];
    final visible = availableBatchPickerBooks(books,
      excludedBookIds: octoberSaved,
      excludedTitles: ['Oldin kiritilgan kitob'],
      query: 'uzrnoma',
    );
    expect(visible.map((b)=>b['title']).toList(), ['Uzrnoma']);
  });

  test('another batch does not hide this batch’s available books', () {
    final visible=availableBatchPickerBooks(catalog,
      excludedBookIds:['book-a'],
      excludedTitles:[],
    );
    expect(visible.any((b)=>b['id']=='book-b'),true);
  });
}
