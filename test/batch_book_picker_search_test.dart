import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_batch_add_picker.dart';

void main() {
  final books = <Map<String,dynamic>>[
    {'id':'a','title':'12-stul kitobi','cost_price':6500},
    {'id':'b','title':'Oʻlimdan keyingi hayot','cost_price':4500},
    {'id':'c','title':'Yangi hayot','cost_price':5000},
    {'id':'d','title':'Arosat','cost_price':7000},
  ];

  test('search finds historical books despite spaces, hyphens and casing',(){
    final matches=searchBatchCatalogBooks(books,'12 STUL',<String>{});
    expect(matches.map((x)=>x['id']),['a']);
  });

  test('Uzbek apostrophe styles do not block book discovery',(){
    expect(searchBatchCatalogBooks(books,"o'lim",<String>{})
        .map((x)=>x['id']),['b']);
  });

  test('multiword search finds title even if words are nonadjacent',(){
    expect(searchBatchCatalogBooks(books,'hayot yangi',<String>{})
        .map((x)=>x['id']),['c']);
  });

  test('previously selected books are shown first',(){
    expect(searchBatchCatalogBooks(books,'',{'d','b'})
        .map((x)=>x['id']).take(2),['d','b']);
  });

  test('search has no duplicates and does not mutate original catalogue',(){
    final before=books.map((x)=>x['id']).toList();
    final matches=searchBatchCatalogBooks(books,'hayot',{'c'});
    expect(matches.map((x)=>x['id']),['c','b']);
    expect(books.map((x)=>x['id']),before);
  });
}
