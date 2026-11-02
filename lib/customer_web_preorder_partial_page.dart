import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

/// The customer chooses a destination, not which advance to spend: all advance
/// credit is used once for the selected arrived titles by the database.
class CustomerWebPreorderPartialPage extends StatefulWidget {
  const CustomerWebPreorderPartialPage({super.key,required this.preorderId});
  final String preorderId;
  @override
  State<CustomerWebPreorderPartialPage> createState()=>_CustomerPartialState();
}
class _CustomerPartialState extends State<CustomerWebPreorderPartialPage> {
  final form=GlobalKey<FormState>();
  final name=TextEditingController(),phone=TextEditingController(),address=TextEditingController();
  Map<String,dynamic>? data; String delivery='택배',error=''; bool busy=false,loaded=false;
  String won(num value)=>'₩'+NumberFormat('#,##0','en_US').format(value);
  @override void initState(){super.initState();reload();}
  @override void dispose(){name.dispose();phone.dispose();address.dispose();super.dispose();}
  Future<void> reload() async {
    try {
      final result=await context.read<AppState>().webPreorderPartial(widget.preorderId,'detail');
      if(!mounted)return;
      if(!loaded){final saved=context.read<AppState>().savedCustomer;
        name.text=(saved['name']??result['customer_name']??'').toString();
        phone.text=(saved['phone']??result['phone']??'').toString();
        address.text=(saved['address']??'').toString();loaded=true;}
      setState((){data=result;error='';});
    }catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> action(String act,[Map<String,dynamic> payload=const {}]) async {
    if(busy)return;setState(()=>busy=true);
    try{await context.read<AppState>().webPreorderPartial(widget.preorderId,act,payload);
      if(mounted)await reload();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text('Hisob saqlanmadi: $e')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> choose() async {
    if(form.currentState?.validate()!=true)return;
    await action('choose',{'choice':'all','recipient_name':name.text.trim(),
      'recipient_phone':phone.text.trim(),'address':address.text.trim(),
      'delivery_type':delivery});
  }
  Future<void> proof() async {
    final f=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:78);
    if(f==null||!mounted||busy)return;
    setState(()=>busy=true);
    try{await context.read<AppState>().submitWebPreorderPartialProof(widget.preorderId,f);
      if(mounted)await reload();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text('Chek yuborilmadi: $e')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context) {
    final batches=data?['batches'] as List? ?? const [];
    Map<String,dynamic>? current;
    for(final x in batches.reversed)if(x is Map &&
      ['prepared','awaiting_payment','proof_submitted'].contains(x['status'])){
      current=Map<String,dynamic>.from(x);break;}
    current??=batches.isNotEmpty && batches.last is Map
      ?Map<String,dynamic>.from(batches.last as Map):null;
    final lines=current?['items'] as List? ?? const [];
    final totals=<int,int>{};
    for(final x in lines)if(x is Map){final i=(x['index'] as num?)?.toInt();
      if(i!=null)totals[i]=(totals[i]??0)+((x['quantity'] as num?)?.toInt()??0);}
    final originals=data?['original_items'] as List? ?? const [];
    final remaining=<String>[];
    for(var i=0;i<originals.length;i++)if(originals[i] is Map){
      final x=originals[i] as Map;
      final q=((x['quantity'] as num?)?.toInt()??0)-(totals[i]??0);
      if(q>0)remaining.add("${x['book_title']??'Kitob'} — $q dona");
    }
    int money(String key)=>(current?[key] as num?)?.toInt()??0;
    final status='${current?['status']??''}';
    return Scaffold(appBar:AppBar(title:const Text('Qisman kelgan kitoblar'),
      actions:[IconButton(icon:const Icon(Icons.refresh),onPressed:reload)]),
      body:data==null?Center(child:error.isNotEmpty?Text(error):
        const CircularProgressIndicator()):
      ListView(padding:const EdgeInsets.all(18),children:[
        const Text('Kelgan kitoblar',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
        for(final x in lines)if(x is Map)ListTile(
          title:Text('${x['requested_title']??x['title']??'Kitob'}'),
          trailing:Text('${x['quantity']} dona')),
        if(remaining.isNotEmpty)...[
          const Divider(),const Text('Hozircha topilmagan kitoblar',
            style:TextStyle(fontWeight:FontWeight.w800)),
          for(final t in remaining)Text('• $t'),
          const Text('Qolgan kitoblar hozir yuborilmaydi. Keyinchalik '
            'kerak bo‘lsa qayta zakaz qilishingiz mumkin.'),
        ],const Divider(),
        if(status=='prepared')...[
          const Text('To‘langan avansingizning hammasi kelgan kitoblar '
            'va pochta hisobidan ayiriladi.'),
          Form(key:form,child:Column(children:[
            TextFormField(controller:name,
              decoration:const InputDecoration(labelText:'Ism'),
              validator:(v)=>(v??'').trim().length<2?'Ism kiriting':null),
            TextFormField(controller:phone,keyboardType:TextInputType.phone,
              decoration:const InputDecoration(labelText:'Telefon'),
              validator:(v)=>RegExp(r'^010[0-9]{8}$').hasMatch(
                (v??'').replaceAll(RegExp(r'[^0-9]'),''))?null:'010 raqam kiriting'),
            DropdownButtonFormField<String>(value:delivery,
              decoration:const InputDecoration(labelText:'Yetkazib berish'),
              items:const [
                DropdownMenuItem(value:'택배',child:Text('Pochta')),
                DropdownMenuItem(value:'경산 직접수령',child:Text('Gyongsandan olib ketish')),
                DropdownMenuItem(value:'경산 무료배송',child:Text('Gyongsan bepul')),
              ],onChanged:(v)=>setState(()=>delivery=v??'택배')),
            if(delivery!='경산 직접수령')TextFormField(controller:address,
              decoration:const InputDecoration(labelText:'Manzil'),
              validator:(v)=>(v??'').trim().length<8?'Manzil kiriting':null),
          ])),
          FilledButton(onPressed:busy?null:choose,
            child:const Text('Avansni kelgan kitoblarga qo‘llash')),
        ]else if(current!=null)...[
          Text('Kitoblar: ${won(money('subtotal'))}'),
          Text('Pochta: ${won(money('shipping_fee'))}'),
          Text('Ishlatilgan avans: −${won(money('deposit_applied'))}'),
          Text('Qolgan to‘lov: ${won(money('amount_due'))}',
            style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
          if(money('refund_due')>0)Text(
            'Ortiqcha avans: ${won(money('refund_due'))} — '
            'bu pul avtomatik qaytarilmaydi, do‘kon bilan bog‘laning.'),
          if(status=='awaiting_payment' && money('amount_due')>0)
            FilledButton(onPressed:busy?null:proof,
              child:const Text('Qolgan to‘lov chekini yuborish')),
          if(status=='awaiting_payment' && money('amount_due')==0)
            const Text('Qolgan to‘lov yo‘q. Admin tasdiqlaydi.'),
          if(status=='proof_submitted')const Text('Chek yuborildi. Admin tekshiradi.'),
          if(status=='completed')const Text('Kelgan kitoblar tasdiqlandi.'),
        ],
        if(busy)const LinearProgressIndicator(),
      ]));
  }
}
