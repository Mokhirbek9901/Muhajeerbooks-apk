import 'dart:ui' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_ui.dart';

void main() {
  test('supplier quantities can exceed customer demand without touching order', () {
    final orders = <Map<String,dynamic>>[
      {'_origin':'native','id':1,'status':'waiting','book_id':'book-1',
       'title':'Obida ayollar','_publisher':'Hilol Nashr',
       'quantity':2,'customer_name':'Private customer','deposit_amount':5000},
    ];
    final output = supplierSourceRows(orders);
    expect(output,hasLength(1));
    expect(output.first['requested'],2);
    expect(output.first['quantity'],2);
    output.first['quantity']=5;
    expect(output.first['quantity'],5);
    expect(orders.first['quantity'],2);
    expect(orders.first['deposit_amount'],5000);
    expect(output.first.containsKey('customer_name'),false);
    expect(output.first.containsKey('phone'),false);
    expect(output.first.containsKey('deposit_amount'),false);
  });

  test('same catalog book aggregates quantities across people', () {
    final orders = <Map<String,dynamic>>[
      for(var i=0;i<5;i++)
        {'_origin':'native','id':i+1,'status':'waiting',
         'book_id':'book-1','title':'Qur’oni Karim','quantity':i==0?50:1,
         '_publisher':'Munir'},
    ];
    final output = supplierSourceRows(orders);
    expect(output,hasLength(1));
    expect(output.first['requested'],54);
    expect(output.first['quantity'],54);
  });

  test('web preorder with multiple titles becomes distinct supplier lines', () {
    final orders = <Map<String,dynamic>>[
      {'_origin':'web','id':'id-1','status':'waiting','quantity':3,
       'book_title':'Two titles +1','request_items':[
         {'book_title':'Kitob A','quantity':2,'book_image_url':'https://example.com/a.jpg'},
         {'book_title':'Kitob B','quantity':1,'book_image_url':'https://example.com/b.jpg'},
       ]},
    ];
    final output = supplierSourceRows(orders);
    expect(output,hasLength(2));
    expect(output.map((x)=>x['requested']).toList(),[2,1]);
    expect(output.every((x)=>(x['image_url'] as String).startsWith('https://')),true);
  });

  test('different publishers are separate, cancelled preorder excluded', () {
    final rows = <Map<String,dynamic>>[
      {'_origin':'web','id':1,'status':'waiting','book_title':'Kitob A',
       '_publisher':'Publisher 1','quantity':1},
      {'_origin':'web','id':2,'status':'waiting','book_title':'Kitob A',
       '_publisher':'Publisher 2','quantity':1},
      {'_origin':'web','id':3,'status':'cancelled','book_title':'Kitob A',
       '_publisher':'Publisher 1','quantity':200},
    ];
    final result=supplierSourceRows(rows);
    expect(result.length,2);
    expect(result.fold<int>(0,(sum,r)=>sum+r['quantity'] as int),2);
  });
  test('same named native and web orders merge without mixing other editions', () {
    final orders = <Map<String,dynamic>>[
      {'_origin':'native','id':1,'status':'accepted',
       'book_id':'catalog-1','title':'Bormisan?','quantity':1},
      {'_origin':'web','id':'a','status':'waiting',
       'book_title':' Bormisan? ','quantity':2},
      {'_origin':'web','id':'b','status':'cancelled',
       'book_title':'Bormisan?','quantity':20},
    ];
    final result = supplierSourceRows(orders);
    expect(result,hasLength(1));
    expect(result.first['quantity'],3);
    expect(result.first['requested'],3);
    expect(orders.last['quantity'],20);
  });

  test('vertical export image keeps titles separate from quantity', () {
    // A 6-cover page has 3 columns and 2 rows. A long, wrapped title
    // must not overlap its "1 dona" quantity label, including page 8/9.
    for (final layout in [2, 3, 4]) {
      final bounds = layout == 4
          ? const Rect.fromLTWH(34, 776, 304, 525)
          : layout == 3
              ? const Rect.fromLTWH(132, 235, 736, 1035)
              : const Rect.fromLTWH(36, 237, 454, 1010);
      final areas = supplierExportVerticalAreas(bounds, layout);
      expect(areas.cover.top, greaterThan(bounds.top));
      expect(areas.cover.height, greaterThan(0));
      expect(areas.cover.bottom, lessThan(areas.title.top));
      expect(areas.title.height, greaterThanOrEqualTo(54));
      expect(areas.title.bottom, lessThan(areas.quantity.top));
      expect(areas.quantity.bottom, lessThan(bounds.bottom));
    }
    expect(
      () => supplierExportVerticalAreas(
        const Rect.fromLTWH(0, 0, 304, 525), 6),
      throwsArgumentError,
    );
  });

  test('three new formats export six books per image', () {
    expect([for (var i=1;i<=6;i++) supplierExportBooksPerPage(i)],
      [5,2,1,6,6,6]);
    expect(() => supplierExportBooksPerPage(9),throwsArgumentError);
  });

  test('temporary signed cover is refreshed even in a customized old draft', () {
    const old='https://site/storage/v1/object/sign/web-preorder-assets/path?token=old';
    const fresh='https://site/storage/v1/object/sign/web-preorder-assets/path?token=new';
    expect(supplierIsTemporarySignedCover(old),isTrue);
    expect(supplierRestoredCoverUrl(old,fresh,customized:true),fresh);
    expect(supplierRestoredCoverUrl(old,'',customized:true),isEmpty);
    const permanent='https://site/storage/v1/object/public/book-covers/covers/custom.jpg';
    expect(supplierRestoredCoverUrl(permanent,fresh,customized:true),permanent);
  });

}
