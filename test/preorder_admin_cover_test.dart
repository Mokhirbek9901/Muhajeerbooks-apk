import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_ui.dart';

void main() {
  const catalog = <String,String>{
    'book-1': 'https://example.com/catalog-cover.jpg',
  };

  test('5 people with 50+4 books shows 5 customers, 54 books', () {
    final rows = <Map<String,dynamic>>[
      {'id':1, '_origin':'native','phone':'01011110001','quantity':50},
      {'id':2, '_origin':'web','phone':'01011110002','quantity':1},
      {'id':3, '_origin':'web','phone':'01011110003','quantity':1},
      {'id':4, '_origin':'web','phone':'01011110004','quantity':1},
      {'id':5, '_origin':'web','phone':'01011110005','quantity':1},
    ];
    final result = preorderRowCounts(rows);
    expect(result.people, 5);
    expect(result.requests, 5);
    expect(result.books, 54);
  });

  test('same customer across native/web requests counted once', () {
    final rows = <Map<String,dynamic>>[
      {'id':1,'_origin':'native','phone':'010-1234-5678','quantity':2},
      {'id':'w2','_origin':'web','phone':'01012345678','quantity':3},
      {'id':'w3','_origin':'web','phone':'','quantity':4},
    ];
    final result = preorderRowCounts(rows);
    expect(result.people, 2);
    expect(result.requests, 3);
    expect(result.books, 9);
  });

  test('old receipt shows one vertical row per requested book with its photo', () {
    const pictures = <String>[
      'https://example.com/v1.jpg',
      'https://example.com/v2.jpg',
      'https://example.com/v3.jpg',
    ];
    final record = <String,dynamic>{
      'book_title':'Book one + 2 more',
      'quantity':5,
      'request_items':[
        {'book_title':'Viqor libosi', 'quantity':2,
         'book_image_url':pictures[0]},
        {'book_title':'Allohning o‘ziga tavakkul', 'quantity':1,
         'book_image_url':pictures[1]},
        {'book_title':'Nafs tarbiyasi', 'quantity':2,
         'book_image_url':pictures[2]},
      ],
    };
    // Detail invoice data must not replace the original per-book photos.
    final details=<String,dynamic>{
      'items':[{'title':'Book one + 2 more','quantity':5,'unit_price':0}],
    };
    final rows=preorderDetailDisplayItems(details,record);
    expect(rows.length,3);
    expect(rows.map((r)=>r['title']).toList(),
      ['Viqor libosi','Allohning o‘ziga tavakkul','Nafs tarbiyasi']);
    expect(rows.map((r)=>r['quantity']).toList(),[2,1,2]);
    expect(rows.map((r)=>r['image_url']).toList(),pictures);
  });

  test('single native preorder retains catalog cover and ordered quantity', () {
    final rows=preorderDetailDisplayItems(
      {'title':'Mukoshafatul qulub','quantity':4}, {
        '_origin':'native',
        '_cover_image_url':'https://example.com/one.jpg',
      });
    expect(rows.length,1);
    expect(rows.first['title'],'Mukoshafatul qulub');
    expect(rows.first['quantity'],4);
    expect(rows.first['image_url'],'https://example.com/one.jpg');
  });

  test('receipt displays invoiced book lines without losing the list', () {
    final rows=preorderDetailDisplayItems({
      'items':[
        {'title':'A', 'quantity':1, 'unit_price':5000},
        {'title':'B', 'quantity':2, 'unit_price':12000},
      ]
    }, {'_origin':'native'});
    expect(rows.length,2);
    expect(rows.last['title'],'B');
    expect(rows.last['quantity'],2);
  });

  test('native preorder uses linked catalog book image', () {
    expect(preorderCoverUrl({'_origin': 'native', 'book_id':'book-1'}, catalog),
      'https://example.com/catalog-cover.jpg');
  });

  test('private uploaded image uses signed URL, not storage path', () {
    const signed='https://example.com/storage/v1/object/sign/web-preorder-assets/cover.jpg?token=abc';
    expect(preorderCoverUrl({
      '_origin':'web',
      'book_image_path':'secret-private-storage/cover.jpg',
      'book_image_url':signed,
    }, catalog), signed);
    expect(preorderCoverUrl({
      '_origin':'web',
      'book_image_path':'secret-private-storage/cover.jpg',
    }, catalog), isEmpty);
  });

  test('multi preorder resolves individual signed cover', () {
    const signed='https://example.com/storage/v1/object/sign/multi.jpg?token=abc';
    expect(preorderCoverUrl({
      '_origin':'web',
      'request_items': [
        {'book_image_path':'private/multi.jpg','book_image_url':signed}
      ]
    }, catalog), signed);
  });

  test('falls back to linked item catalog image when no uploaded cover', () {
    expect(preorderCoverUrl({
      '_origin':'web',
      'request_items':[{'book_id':'book-1'}],
    },catalog),'https://example.com/catalog-cover.jpg');
  });

  test('invalid or relative image URL is never used in Image.network', () {
    expect(preorderCoverUrl({
      'book_image_url':'/private/not-signed.jpg',
    },catalog),isEmpty);
  });
}
