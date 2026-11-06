import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'uzbek_customer_style.dart';

/// Customer view for the titles already found in a multi-book preorder.
/// The original advance is ALWAYS applied in full to this wave. Missing
/// titles are not automatically ordered or charged.
class CustomerWebPreorderPartialPage extends StatefulWidget {
  const CustomerWebPreorderPartialPage({super.key, required this.preorderId});
  final String preorderId;
  @override
  State<CustomerWebPreorderPartialPage> createState() =>
      _CustomerWebPreorderPartialPageState();
}

class _CustomerWebPreorderPartialPageState
    extends State<CustomerWebPreorderPartialPage> {
  final _picker = ImagePicker();
  final _fmt = NumberFormat('#,##0','en_US');
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String _method = '택배';
  Map<String,dynamic>? _detail;
  bool _loading = true, _saving = false;
  String? _error;
  String won(int n) => '₩${_fmt.format(n)}';
  int numOf(dynamic x) => x is num ? x.toInt() : int.tryParse('$x')??0;

  List<Map<String,dynamic>> get batches =>
      (_detail?['batches'] as List? ?? const [])
        .whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();

  Map<String,dynamic>? get wave {
    for(final b in batches.reversed) {
      if (b['status']!='cancelled') return b;
    }
    return null;
  }

  /// Include original missing titles even when a completed all-advance
  /// wave closes the old preorder (the SQL display then zeroes remaining).
  List<String> get remainingTitles {
    final original=(_detail?['original_items'] as List? ?? const [])
      .whereType<Map>().toList();
    final reserved=<int,int>{};
    for(final b in batches) {
      if (b['status']=='cancelled') continue;
      final lines=(b['items'] as List? ?? const []).whereType<Map>();
      for(final l in lines) {
        final index=numOf(l['index']);
        reserved[index]=(reserved[index]??0)+numOf(l['quantity']);
      }
    }
    final left=<String>[];
    for(var i=0;i<original.length;i++) {
      final o=original[i];
      final count=numOf(o['quantity'])-(reserved[i]??0);
      if(count>0) left.add('${o['book_title']??'Kitob'} — $count dona');
    }
    return left;
  }

  Future<void> _load() async {
    try {
      final response=await context.read<AppState>()
        .customerWebPartial(widget.preorderId,'detail');
      if(!mounted)return;
      final saved=context.read<AppState>().savedCustomer;
      setState((){
        _detail=response;
        _loading=false;
        _error=null;
        if (_name.text.isEmpty) _name.text='${saved['name']??''}';
        if (_phone.text.isEmpty) _phone.text='${saved['phone']??''}';
        if (_address.text.isEmpty) _address.text='${saved['address']??''}';
      });
    } catch(e) {
      if(mounted)setState((){
        _loading=false;
        _error='Qisman zakas yuklanmadi: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();_phone.dispose();_address.dispose();
    super.dispose();
  }

  Future<void> _chooseAll() async {
    final b=wave;
    if (_saving || b==null || b['status']!='prepared') return;
    final confirmed=await showDialog<bool>(
      context:context,
      builder:(d)=>AlertDialog(
        title:const Text('Kelgan kitoblar hisobini tasdiqlash'),
        content:Text(
          'Hali ishlatilmagan ${won(numOf(_detail?['deposit_remaining']))} '
          'avansingiz TO‘LIQ topilgan kitoblar va ularning pochta '
          'haqidan ayriladi. Qolgan kitoblar ushbu jo‘natmaga kirmaydi. '
          'Ularni keyinchalik qayta oldindan buyurtma qilishingiz mumkin.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(d,false),
            child:const Text('Bekor qilish')),
          FilledButton(onPressed:()=>Navigator.pop(d,true),
            child:const Text('Hisobni ko‘rish')),
        ],
      ),
    );
    if(confirmed!=true||!mounted)return;
    setState((){_saving=true;_error=null;});
    try {
      final result=await context.read<AppState>().customerWebPartial(
        widget.preorderId,'choose',
        payload:{
          'choice':'all',
          'recipient_name':_name.text.trim(),
          'recipient_phone':_phone.text.trim(),
          'address':_address.text.trim(),
          'delivery_type':_method,
        },
      );
      if(mounted)setState(()=>_detail=result);
    }catch(e) {
      if(mounted)setState(()=>_error='Hisob saqlanmadi: $e');
    }finally{
      if(mounted)setState(()=>_saving=false);
    }
  }

  Future<void> _proof() async {
    if(_saving)return;
    final picked=await _picker.pickImage(
      source:ImageSource.gallery,maxWidth:1600,
      maxHeight:2200,imageQuality:85);
    if(picked==null)return;
    if(!mounted)return;
    setState((){_saving=true;_error=null;});
    try{
      final result=await context.read<AppState>()
        .submitWebPartialPayment(widget.preorderId,picked);
      if(mounted)setState(()=>_detail=result);
    }catch(e){
      if(mounted)setState(()=>_error='Chek yuborilmadi: $e');
    }finally{
      if(mounted)setState(()=>_saving=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b=wave;
    final items=(b?['items'] as List? ?? const []).whereType<Map>().toList();
    final originalAdvance=numOf(_detail?['deposit_amount']);
    final remainingCredit=numOf(_detail?['deposit_remaining']);
    final applied=numOf(b?['deposit_applied']);
    final price=numOf(b?['subtotal']);
    final shipping=numOf(b?['shipping_fee']);
    final amount=numOf(b?['amount_due']);
    final refund=numOf(b?['refund_due']);
    return Scaffold(
      backgroundColor:UzbekCustomerColors.background,
      appBar:AppBar(
        title:const Text('Topilgan kitoblarim'),
        actions:[IconButton(onPressed:_saving?null:_load,
          icon:const Icon(Icons.refresh))]),
      body: _loading
        ? const Center(child:CircularProgressIndicator())
        : ListView(
            padding:const EdgeInsets.all(16),
            children:[
              if(_error!=null)Padding(
                padding:const EdgeInsets.only(bottom:12),
                child:Text(_error!,style:const TextStyle(
                  color:Colors.red,fontWeight:FontWeight.w700))),
              if(b==null) const Card(child:Padding(
                padding:EdgeInsets.all(16),
                child:Text('Hozircha buyurtmangizdagi kitoblar '
                  'qisman topilgani belgilanmagan. Kitob kelganda '
                  'shu yerda ko‘rsatiladi.')))
              else Card(child:Padding(
                padding:const EdgeInsets.all(16),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.stretch,
                  children:[
                    const Text('Quyidagi kitoblaringiz topildi',
                      style:TextStyle(fontSize:20,
                        fontWeight:FontWeight.w900)),
                    const SizedBox(height:10),
                    for(final i in items)
                      Padding(
                        padding:const EdgeInsets.symmetric(vertical:5),
                        child:Text(
                          '${i['requested_title']??i['title']??'Kitob'} — '
                          '${i['quantity']??1} dona • '
                          '${won(numOf(i['unit_price'])*numOf(i['quantity']))}',
                        )),
                    const Divider(height:25),
                    Text('Kitoblar summasi: ${won(price)}'),
                    if(b['status']!='prepared')
                      Text('Yetkazish: ${won(shipping)}')
                    else
                      const Text('Pochta haqi manzil tanlanganda aniqlanadi.'),
                    Text('Oldindan to‘langan jami avans: ${won(originalAdvance)}'),
                    Text(
                      b['status']=='prepared'
                        ? 'To‘liq ishlatiladigan avans: ${won(remainingCredit)}'
                        : 'Avansdan ayrilgan: −${won(applied)}',
                      style:const TextStyle(fontWeight:FontWeight.w800)),
                    if(b['status']!='prepared') ...[
                      const SizedBox(height:10),
                      Text('Qolgan to‘lov: ${won(amount)}',
                        style:const TextStyle(fontSize:21,
                          fontWeight:FontWeight.w900)),
                      if(refund>0)Text(
                        'Ortiqcha avans qaytarilishi kerak: ${won(refund)}',
                        style:const TextStyle(fontWeight:FontWeight.w800)),
                    ],
                  ],
                ),
              )),
              const SizedBox(height:10),
              Card(child:Padding(
                padding:const EdgeInsets.all(16),
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.stretch,
                  children:[
                    const Text('Qolgan kitoblar',
                      style:TextStyle(fontWeight:FontWeight.w900)),
                    if(remainingTitles.isEmpty)
                      const Text('Boshqa kutilayotgan kitob qolmagan.')
                    else
                      for(final title in remainingTitles)
                        Padding(padding:const EdgeInsets.only(top:5),
                          child:Text('• $title')),
                    const SizedBox(height:8),
                    const Text(
                      'Qolgan kitoblarni keyinchalik yana '
                      'oldindan buyurtma berib olib kelishingiz mumkin. '
                      'Ular hozirgi jo‘natmaga qo‘shilmaydi va '
                      'avansingiz ularga saqlab qolinmaydi.',
                      style:TextStyle(fontSize:13,height:1.5)),
                  ],
                ),
              )),
              if(b!=null && b['status']=='prepared') ...[
                const SizedBox(height:14),
                const Text('Yetkazish ma’lumotlari',
                  style:TextStyle(fontSize:17,
                    fontWeight:FontWeight.w900)),
                TextField(controller:_name,
                  decoration:const InputDecoration(labelText:'Ism')),
                TextField(controller:_phone,
                  keyboardType:TextInputType.phone,
                  inputFormatters:[FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9\- ]'))],
                  decoration:const InputDecoration(labelText:'Telefon')),
                const SizedBox(height:10),
                DropdownButtonFormField<String>(
                  initialValue:_method,
                  decoration:const InputDecoration(
                    labelText:'Yetkazib berish usuli'),
                  items:const [
                    DropdownMenuItem(value:'택배',
                      child:Text('Pochta bilan jo‘natish')),
                    DropdownMenuItem(value:'경산 직접수령',
                      child:Text('Gyongsanda olib ketish')),
                    DropdownMenuItem(value:'경산 무료배송',
                      child:Text('Gyongsan bepul yetkazish')),
                  ],
                  onChanged:_saving?null:(v)=>
                    setState(()=>_method=v??'택배'),
                ),
                if(_method!='경산 직접수령')
                  TextField(controller:_address,
                    maxLines:2,
                    decoration:const InputDecoration(
                      labelText:'Manzil')),
                const SizedBox(height:12),
                FilledButton.icon(
                  key:const Key('partial_all_advance_confirm'),
                  onPressed:_saving?null:_chooseAll,
                  icon:const Icon(Icons.receipt_long_outlined),
                  label:const Text('Barcha avansni ayirib hisoblash')),
              ],
              if(b!=null && b['status']=='awaiting_payment') ...[
                const SizedBox(height:12),
                if(amount>0)FilledButton.icon(
                  key:const Key('partial_balance_proof'),
                  onPressed:_saving?null:_proof,
                  icon:const Icon(Icons.add_photo_alternate_outlined),
                  label:const Text('Qolgan to‘lov chekini yuborish'))
                else const Text('Qo‘shimcha to‘lov kerak emas. '
                  'Do‘kon tasdiqlashini kuting.'),
              ],
              if(b!=null && b['status']=='proof_submitted')
                const Padding(padding:EdgeInsets.only(top:14),
                  child:Text('To‘lov cheki yuborilgan. '
                    'Admin tasdiqlashini kuting.')),
              if(b!=null && b['status']=='completed')
                const Padding(padding:EdgeInsets.only(top:14),
                  child:Text('Topilgan kitoblar jo‘natma '
                    'buyurtmasiga o‘tkazildi.')),
              if(_saving)const LinearProgressIndicator(),
            ],
          ),
    );
  }
}
