import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/customer_web_preorder_partial_page.dart';

class FakePartialState extends AppState {
  FakePartialState():super(backendConfigured:false);
  int chooseCalls=0;
  Map<String,dynamic>? lastPayload;
  @override
  Future<Map<String,dynamic>> webPreorderPartial(
      String id,String action,[Map<String,dynamic> payload=const {}]) async {
    if(action=='choose'){chooseCalls++;lastPayload=payload;}
    final prepared=action=='choose'?'awaiting_payment':'prepared';
    return {
      'id':id,'customer_name':'Mijoz','phone':'01011112222',
      'original_items':[
        {'book_title':'Kelgan kitob','quantity':1},
        {'book_title':'Hozircha topilmagan','quantity':2},
      ],
      'batches':[{
        'status':prepared,'subtotal':18000,'shipping_fee':4000,
        'deposit_applied':15000,'amount_due':7000,'refund_due':0,
        'items':[{'index':0,'quantity':1,'requested_title':'Kelgan kitob'}],
      }],
    };
  }
}

void main(){
  testWidgets('Partial form lists arrived and unavailable books without changing original',
    (tester) async {
      tester.view.physicalSize=const Size(470,1900);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state=FakePartialState();
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value:state,
        child:const MaterialApp(home:CustomerWebPreorderPartialPage(
          preorderId:'4f44c073-b8b8-4815-83fa-0b2212105e11')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Kelgan kitoblar'),findsOneWidget);
      expect(find.text('Kelgan kitob'),findsOneWidget);
      expect(find.textContaining('Hozircha topilmagan'),findsWidgets);
      expect(find.textContaining('To‘langan avansingizning hammasi'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
}
