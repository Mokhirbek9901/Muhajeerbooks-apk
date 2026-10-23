import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'design_system.dart';

/// Completes the original web preorder; never creates a duplicate order.
class WebPreorderCheckoutPage extends StatefulWidget {
  const WebPreorderCheckoutPage({super.key,required this.preorderId});
  final String preorderId;
  @override
  State<WebPreorderCheckoutPage> createState()=>_WebPreorderCheckoutPageState();
}
class _WebPreorderCheckoutPageState extends State<WebPreorderCheckoutPage> {
  Future<Map<String,dynamic>>? pending;
  final form = GlobalKey<FormState>();
  final recipientName = TextEditingController();
  final recipientPhone = TextEditingController();
  final recipientAddress = TextEditingController();
  String deliveryType = '택배';
  bool hydrated = false;
  bool busy=false;
  String won(int amount)=>'₩'+NumberFormat('#,##0','en_US').format(amount);
  @override
  void initState(){super.initState();reload();}
  @override
  void dispose() {
    recipientName.dispose();
    recipientPhone.dispose();
    recipientAddress.dispose();
    super.dispose();
  }
  Future<void> reload() async {
    final next=context.read<AppState>().webPreorderInvoice(widget.preorderId);
    if (mounted) setState(() { pending = next; });
    try {
      final d = await next;
      if (!mounted || hydrated) return;
      final saved = context.read<AppState>().savedCustomer;
      setState(() {
        final oldName = (d['recipient_name'] ?? '').toString().trim();
        final oldPhone = (d['recipient_phone'] ?? '').toString().trim();
        recipientName.text = oldName.isNotEmpty ? oldName : (saved['name'] ?? '');
        recipientPhone.text = oldPhone.isNotEmpty ? oldPhone : (saved['phone'] ?? '');
        deliveryType = d['delivery_type'] == '경산 직접수령' ? '경산 직접수령' : '택배';
        recipientAddress.text = d['delivery_saved'] == true
          ? (deliveryType == '택배' ? (d['delivery_address'] ?? '').toString() : '')
          : (saved['address'] ?? '');
        hydrated = true;
      });
    } catch (_) { /* FutureBuilder displays the server error. */ }
  }
  void notice(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text(text.replaceFirst('Bad state: ',''))));}
  Future<Map<String,dynamic>?> saveDelivery({bool notify = true}) async {
    if (busy || form.currentState?.validate() != true) return null;
    setState(() => busy = true);
    try {
      final result = await context.read<AppState>().saveWebPreorderDelivery(
        widget.preorderId,
        recipientName: recipientName.text.trim(),
        recipientPhone: recipientPhone.text.trim(),
        address: recipientAddress.text.trim(),
        deliveryType: deliveryType,
      );
      if (!mounted) return null;
      setState(() => pending = Future.value(result));
      if (notify) notice('Qabul qiluvchi va manzil saqlandi ✅');
      return result;
    } catch (error) {
      notice('Yetkazish ma’lumotlari saqlanmadi: ' + error.toString());
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change(String id,int delta) async {
    if(busy)return;
    setState(()=>busy=true);
    try{
      await context.read<AppState>().changeWebPreorderExtra(widget.preorderId,id,delta);
      if(mounted)await reload();
    }catch(e){notice(e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> pickBook(String original) async {
    final books=context.read<AppState>().books.where((b)=>
      b.isActive && b.stock>0 && b.price>0 && b.id!=original).toList();
    String q='';
    final selected=await showModalBottomSheet<Book>(context:context,
      isScrollControlled:true,showDragHandle:true,
      builder:(sheet)=>StatefulBuilder(builder:(sheet,update){
        final visible=books.where((b)=>b.title.toLowerCase().contains(q.toLowerCase())).toList();
        return SafeArea(child:Padding(
          padding:EdgeInsets.fromLTRB(16,8,16,MediaQuery.viewInsetsOf(sheet).bottom+12),
          child:SizedBox(height:MediaQuery.sizeOf(sheet).height*.65,child:Column(children:[
            const Text('Yana kitob qo‘shish',style:TextStyle(fontWeight:FontWeight.w900,fontSize:20)),
            TextField(onChanged:(v)=>update(()=>q=v),
              decoration:const InputDecoration(labelText:'Kitob qidirish',prefixIcon:Icon(Icons.search))),
            Expanded(child:ListView.builder(itemCount:visible.length,itemBuilder:(_,i){
              final book=visible[i];
              return ListTile(title:Text(book.title),
                subtitle:Text(won(book.price)+' • '+book.stock.toString()+' ta'),
                trailing:const Icon(Icons.add_circle_outline),
                onTap:()=>Navigator.pop(sheet,book));
            })),
          ])),
        ));
      }));
    if(selected!=null&&mounted)await change(selected.id,1);
  }
  Future<void> sendProof(int previousDue) async {
    final saved = await saveDelivery(notify: false);
    if (saved == null || !mounted) return;
    final due = (saved['amount_due'] as num?)?.toInt() ?? 0;
    if (saved['payment_state'] != 'requested') {
      notice('Bu zakazning cheki oldin yuborilgan.');
      return;
    }
    if (due <= 0) {
      notice('Qolgan to‘lov ₩0. Manzil saqlandi, admin tekshiradi.');
      return;
    }
    final photo=await ImagePicker().pickImage(source:ImageSource.gallery,
      imageQuality:78,maxWidth:1600,maxHeight:2400);
    if(photo==null||!mounted)return;
    final approved=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
      title:const Text('Qolgan to‘lov'),
      content:Text(won(due)+' o‘tkazilganini tekshiring. Avans chegirilgan. '
        'Chek yuborilgach savatni o‘zgartirib bo‘lmaydi.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Qaytish')),
        FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Chekni yuborish'))]));
    if(approved!=true||!mounted)return;
    setState(()=>busy=true);
    try{
      await context.read<AppState>().submitWebPreorderRemainingPayment(widget.preorderId,photo);
      if(mounted)await reload();
      notice('Qolgan to‘lov cheki yuborildi. Admin tekshiradi ✅');
    }catch(e){notice(e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Widget item(String label,int value,{bool big=false})=>Padding(
    padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[
      Expanded(child:Text(label,style:TextStyle(fontWeight:big?FontWeight.w900:FontWeight.w600))),
      Text((value<0?'−':'')+won(value.abs()),style:TextStyle(
        fontSize:big?22:15,fontWeight:FontWeight.w900)),
    ]));
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Buyurtmani rasmiylashtirish'),actions:[
      IconButton(tooltip:'Yangilash',onPressed:busy?null:reload,icon:const Icon(Icons.refresh))]),
    body:FutureBuilder<Map<String,dynamic>>(future:pending,builder:(ctx,snapshot){
      if(snapshot.hasError)return Center(child:Padding(padding:const EdgeInsets.all(20),
        child:Text('Buyurtmani ochib bo‘lmadi: '+snapshot.error.toString())));
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
      final d=snapshot.data!;
      final qty=(d['quantity'] as num?)?.toInt()??1;
      final price=(d['unit_price'] as num?)?.toInt()??0;
      final base=(d['base_total'] as num?)?.toInt()??0;
      final extra=(d['extra_total'] as num?)?.toInt()??0;
      final deposit=(d['deposit_credit'] as num?)?.toInt()??0;
      final due=(d['amount_due'] as num?)?.toInt()??0;
      final shipping=(d['shipping_fee'] as num?)?.toInt()??0;
      final ready=d['price_ready']==true;
      final cancelled=d['status']=='cancelled';
      final canEdit=d['can_edit']==true;
      final details=((d['extras'] as List?)??const []).whereType<Map>()
        .map((e)=>Map<String,dynamic>.from(e)).toList();
      final extraCount=details.fold<int>(0,(sum,line)=>
        sum+((line['quantity'] as num?)?.toInt()??0));
      final chosenShipping=deliveryType=='경산 직접수령'?0:
        (qty+extraCount>=4&&!context.watch<AppState>().discountBlocksFourPlusFreeDelivery?0:4000);
      final shownShipping=canEdit?chosenShipping:shipping;
      final shownTotal=qty*price+extra+shownShipping;
      final shownDue=(shownTotal-deposit).clamp(0,100000000).toInt();
      return Form(key:form,child:ListView(
        padding:const EdgeInsets.all(16),children:[
        if(busy)const LinearProgressIndicator(),
        AppSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Oldindan zakaz qilingan kitob'),
          const SizedBox(height:8),
          Text((d['title']??'Kitob').toString(),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
          Text('Miqdor: '+qty.toString()+' ta • Holat: '+
            (d['status']=='arrived'?'Kitob keldi':(d['status']??'Kutilmoqda').toString())),
          if(ready)Text('Kitob narxi: '+won(price)+' × '+qty.toString()),
        ])),
        const SizedBox(height:12),
        if(cancelled)const AppSurface(child:Text(
          'Bu oldindan zakaz admin tomonidan bekor qilingan. '
          'Ushbu zakaz bo‘yicha yangi to‘lov yubormang. '
          'Agar kitob uchun oldindan sotuv ochiq bo‘lsa, katalogdan '
          'yangi zakaz berishingiz mumkin. Eski avans avtomatik '
          'ko‘chirilmaydi; avans qaytarilmagan bo‘lsa, qayta to‘lashdan '
          'oldin do‘kon bilan hisobni aniqlashtiring.')),
        if(!cancelled&&!ready)AppSurface(child:Text((d['note']??'Narx tasdiqlanmagan').toString()+
          '. Avans qayta olinmaydi. Hozir to‘lov yubormang.')),
        if(!cancelled&&ready)...[
          const Text('1. Qabul qiluvchi',style:TextStyle(
            fontSize:20,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          AppSurface(child:Column(children:[
            TextFormField(controller:recipientName,
              decoration:const InputDecoration(labelText:'Ism',
                prefixIcon:Icon(Icons.person_outline)),
              validator:(v)=>(v??'').trim().length<2?'Ismingizni kiriting':null),
            const SizedBox(height:10),
            TextFormField(controller:recipientPhone,
              keyboardType:TextInputType.phone,
              inputFormatters:[FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11)],
              decoration:const InputDecoration(labelText:'Telefon raqami',
                hintText:'01012345678',prefixIcon:Icon(Icons.phone_outlined)),
              validator:(v)=>RegExp(r'^010\d{8}$').hasMatch((v??'').trim())
                ?null:'010 bilan boshlanuvchi 11 raqamni kiriting'),
            const SizedBox(height:10),
            TextFormField(controller:recipientAddress,
              maxLines:3,minLines:2,
              decoration:InputDecoration(
                labelText:deliveryType=='택배'?'To‘liq manzil':'Manzil (ixtiyoriy)',
                helperText:deliveryType=='택배'
                  ?'Bino, uy va xona raqamini yozing.'
                  :'Gyeongsandan o‘zingiz olib ketasiz',
                prefixIcon:const Icon(Icons.location_on_outlined)),
              validator:(v)=>deliveryType=='택배'&&(v??'').trim().length<8
                ?'To‘liq manzilni kiriting':null),
          ])),
          const SizedBox(height:16),
          const Text('2. Yetkazib berish',style:TextStyle(
            fontSize:20,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          AppSurface(child:Column(children:[
            Material(color:Colors.transparent,child:RadioListTile<String>(
              value:'택배',groupValue:deliveryType,
              onChanged:canEdit?(value)=>setState(()=>deliveryType=value!):null,
              title:const Text('Koreya bo‘ylab pochta (택배)'),
              subtitle:Text(canEdit
                ?(chosenShipping==0?'4+ kitob — BEPUL':'₩4,000 • 1–2 ish kuni')
                :'To‘lov cheki yuborilgan, narx o‘zgarmaydi'))),
            const Divider(height:1),
            Material(color:Colors.transparent,child:RadioListTile<String>(
              value:'경산 직접수령',groupValue:deliveryType,
              onChanged:canEdit?(value)=>setState(()=>deliveryType=value!):null,
              title:const Text('경산dan o‘zim olib ketaman'),
              subtitle:const Text('Gyeongsan • BEPUL'))),
          ])),
          const SizedBox(height:16),
          const Text('3. Kitoblar',style:TextStyle(
            fontSize:20,fontWeight:FontWeight.w900)),
          const SizedBox(height:12),
          AppSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Zakaz qilingan kitoblar',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
            ListTile(contentPadding:EdgeInsets.zero,
              title:Text((d['title']??'Kitob').toString()),
              subtitle:Text(won(price)+' × '+qty.toString())),
            for(final line in details)ListTile(
              contentPadding:EdgeInsets.zero,
              title:Text((line['title']??'Kitob').toString()),
              subtitle:Text(won((line['unit_price'] as num?)?.toInt()??0)+' × '+
                (line['quantity']??1).toString()),
              trailing:canEdit?IconButton(icon:const Icon(Icons.remove_circle_outline),
                tooltip:'Bitta olib tashlash',onPressed:busy?null:()=>
                  change((line['book_id']??'').toString(),-1)):null,
            ),
            if(canEdit)OutlinedButton.icon(onPressed:busy?null:()=>
              pickBook((d['book_id']??'').toString()),
              icon:const Icon(Icons.add_shopping_cart),label:const Text('Yana kitob qo‘shish')),
            if(!canEdit&&d['payment_state']=='proof_submitted')
              const Text('Chek yuborilgan. Kitob qo‘shish '
                'uchun admin bilan bog‘laning.',style:TextStyle(fontSize:12)),
          ])),
          const SizedBox(height:16),
          const Text('4. Buyurtma jami',style:TextStyle(
            fontSize:20,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          AppSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Buyurtma hisobi',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
            const Divider(),
            item('Zakaz qilingan kitob',qty*price),
            item('Yetkazib berish',shownShipping),
            item('Qo‘shimcha kitoblar',extra),
            const Divider(),
            item('Jami',shownTotal),
            item('Oldindan to‘langan avans',-deposit),
            const Divider(),
            item('Qolgan to‘lov',shownDue,big:true),
            Text((d['note']??'').toString(),style:const TextStyle(fontSize:12)),
          ])),
          const SizedBox(height:16),
          const Text('5. To‘lov va chek',style:TextStyle(
            fontSize:20,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          AppSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('To‘lov ma’lumotlari',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
            const SizedBox(height:10),
            const SelectableText(AppState.bankName+' • '+AppState.bankAccount+' • '+AppState.bankOwner),
            TextButton.icon(onPressed:() async{
              await Clipboard.setData(const ClipboardData(text:AppState.bankAccount));
              notice('Bank raqami nusxalandi');
            },icon:const Icon(Icons.copy),label:const Text('Bank raqamini nusxalash')),
            const SizedBox(height:10),
            OutlinedButton.icon(
              onPressed:busy?null:()=>saveDelivery(),
              icon:const Icon(Icons.save_outlined),
              label:const Text('Qabul qiluvchi va manzilni saqlash')),
            if(canEdit&&shownDue>0)...[
              const SizedBox(height:10),
              FilledButton.icon(onPressed:busy?null:()=>sendProof(shownDue),
                icon:const Icon(Icons.receipt_long),
                label:Text(won(shownDue)+' uchun chek yuborish')),
            ],
            if(canEdit&&shownDue==0)
              const Text('Avans barcha xarajatni qopladi. '
                'Manzilni saqlang, admin tasdiqlaydi.'),
            if(!canEdit)Text(d['payment_state']=='proof_submitted'
              ? 'Qolgan to‘lov cheki yuborilgan. Admin tekshiradi.'
              : d['payment_state']=='verified'?'To‘lov tasdiqlangan ✅'
              : 'To‘lov hozircha yopiq.'),
          ])),
        ],
      ]));
    }),
  );
}
