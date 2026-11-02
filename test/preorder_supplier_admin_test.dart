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
}
