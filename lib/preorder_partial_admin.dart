part of 'admin_ui.dart';

class _PartialBookEntry {
  _PartialBookEntry(this.index, this.remaining)
      : quantity = remaining,
        price = 0;
  final int index;
  final int remaining;
  Book? book;
  bool selected = false;
  int quantity;
  int price;
}

/// The admin selects only actually arrived titles. Stock is reserved by
/// the server; no deposit moves until the customer chooses the allocation.
class _PartialPreorderAdminPage extends StatefulWidget {
  const _PartialPreorderAdminPage({required this.api, required this.preorderId});
  final _AdminApi api;
  final String preorderId;
  @override
  State<_PartialPreorderAdminPage> createState() => _PartialPreorderAdminPageState();
}

class _PartialPreorderAdminPageState extends State<_PartialPreorderAdminPage> {
  Map<String, dynamic>? detail;
  List<Book> catalog = const [];
  final entries = <int, _PartialBookEntry>{};
  bool busy = false;
  String? error;

  Future<Map<String, dynamic>> rpc(String action,
      [Map<String, dynamic> payload = const {}]) async {
    final result = await widget.api._rpc('admin_web_preorder_partial', params: {
      'p_secret': widget.api.secret,
      'p_id': widget.preorderId,
      'p_action': action,
      'p_payload': payload,
    });
    if (result is! Map) throw StateError('Qisman zakas javobi olinmadi');
    return Map<String, dynamic>.from(result);
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final results = await Future.wait<dynamic>([rpc('detail'), widget.api.books()]);
      if (!mounted) return;
      final response = Map<String, dynamic>.from(results[0] as Map);
      final all = (results[1] as List).whereType<Book>().toList();
      final remaining = ((response['items'] as List?) ?? const [])
        .whereType<Map>().where((x) => ((x['remaining_quantity'] as num?)?.toInt() ?? 0) > 0);
      entries.clear();
      for (final item in remaining) {
        final idx = (item['index'] as num).toInt();
        final qty = (item['remaining_quantity'] as num).toInt();
        entries[idx] = _PartialBookEntry(idx, qty);
      }
      setState(() { detail = response; catalog = all; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Book?> searchBook() async {
    var search = '';
    return showModalBottomSheet<Book>(
      context:context, isScrollControlled:true, showDragHandle:true,
      builder:(sheet) => StatefulBuilder(
        builder:(sheet, update) {
          final visible = catalog.where((b)=>b.title.toLowerCase()
             .contains(search.toLowerCase())).take(100).toList();
          return SafeArea(child:Padding(
            padding:EdgeInsets.fromLTRB(16,10,16,MediaQuery.viewInsetsOf(sheet).bottom+12),
            child:SizedBox(
              height:MediaQuery.sizeOf(sheet).height*.68,
              child:Column(children:[
                const Text('Kelgan kitobni katalogdan tanlang',
                  style:TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
                TextField(autofocus:true,
                  onChanged:(s)=>update(()=>search=s),
                  decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Kitob nomi')),
                const SizedBox(height:8),
                Expanded(child:ListView.builder(
                  itemCount:visible.length,
                  itemBuilder:(_,i) {
                    final b=visible[i];
                    return ListTile(
                      title:Text(b.title),
                      subtitle:Text('Omborda: ${b.stock} ta • ${_won(b.currentPrice)}'),
                      onTap:()=>Navigator.pop(sheet,b),
                    );
                  },
                )),
              ]),
            ),
          ));
        },
      ),
    );
  }

  Future<void> act(String action, [Map<String, dynamic> payload=const {}]) async {
    if (busy) return;
    setState(()=>busy=true);
    try {
      final next=await rpc(action,payload);
      if (!mounted) return;
      setState(()=>detail=next);
      if (action=='prepare' || action=='cancel_prepare' || action=='confirm') {
        final nextCatalog=await widget.api.books();
        if (mounted) setState(()=>catalog=nextCatalog);
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content:Text('Amal bajarilmadi: $e')));
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  Future<void> prepare() async {
    final chosen=entries.values.where((e)=>e.selected).toList();
    if(chosen.isEmpty || chosen.any((e)=>e.book==null ||
         e.quantity<1 || e.quantity>e.remaining || e.price<=0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Kelgan kitobni, miqdorini va narxini tekshiring')));
      return;
    }
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Faqat shu kitoblar keldimi?'),
      content:Text('${chosen.length} turdagi kitob ombordan band qilinadi. '
        'Mijozga avans tanlovi haqida xabar boradi. Kelmaganlari o‘z holicha qoladi.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Yo‘q')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Tasdiqlash')),
      ],
    ));
    if(ok!=true || !mounted)return;
    await act('prepare',{'items':[
      for(final e in chosen)
        {'index':e.index,'book_id':e.book!.id,
         'quantity':e.quantity,'unit_price':e.price},
    ]});
  }

  Future<void> cancelPrepare() async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Kelgan kitoblarni qaytarish?'),
      content:const Text('Hali mijoz tanlamagan. Omborga band qilingan nusxalar qaytariladi.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Yo‘q')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Qaytarish')),
      ],
    ));
    if(ok==true&&mounted)await act('cancel_prepare');
  }

  Future<void> confirm(Map<String,dynamic> wave) async {
    final amount=(wave['amount_due'] as num?)?.toInt()??0;
    if(amount>0 && wave['status']!='proof_submitted')return;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Bankdagi to‘lov tekshirildimi?'),
      content:Text('Qolgan to‘lov ${_won(amount)}. '
          'Haqiqiy bank tushumini tekshirgandan keyingina tasdiqlang. '
          'Tanlangan kitoblar alohida jo‘natish buyurtmasiga o‘tadi.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Tekshirmadim')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Tekshirdim')),
      ],
    ));
    if(ok==true&&mounted)await act('confirm');
  }

  Future<void> showReceipt(Map<String,dynamic> wave) async {
    final path='${wave['proof_path']??''}';
    if(path.isEmpty)return;
    try {
      final url=await widget.api.paymentProofUrl(path);
      if(!await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication))
        throw StateError('Chek ochilmadi');
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Chek: $e')));
    }
  }

  Widget currentWave(Map<String,dynamic> wave) {
    final status='${wave['status']}';
    final ready=status=='proof_submitted' ||
      (status=='awaiting_payment' && ((wave['amount_due'] as num?)?.toInt()??0)==0);
    return Card(child:Padding(
      padding:const EdgeInsets.all(16),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(status=='prepared'?'Mijozning avans tanlovi kutilmoqda'
          :status=='completed'?'Jo‘natish buyurtmasiga o‘tkazildi'
          :status=='proof_submitted'?'Chek yuborilgan — bankni tekshiring'
          :'Mijoz to‘lovi kutilmoqda',
          style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),
        for(final raw in (wave['items'] as List?)??const [])
          if(raw is Map) ListTile(
            contentPadding:EdgeInsets.zero,
            title:Text('${raw['title']??''}'),
            subtitle:Text('${raw['quantity']} × ${_won((raw['unit_price'] as num?)?.toInt()??0)}'),
          ),
        const Divider(),
        Text('Kitoblar: ${_won((wave['subtotal'] as num?)?.toInt()??0)}'),
        if(status!='prepared') ...[
          Text('Avans: −${_won((wave['deposit_applied'] as num?)?.toInt()??0)}'),
          Text('Pochta: ${_won((wave['shipping_fee'] as num?)?.toInt()??0)}'),
          Text('Qolgan to‘lov: ${_won((wave['amount_due'] as num?)?.toInt()??0)}',
              style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
          Text('Tanlov: ${wave['choice']=='all'?'Barcha qolgan avans':'Kelmaganlarga saqlansin'}'),
        ],
        const SizedBox(height:10),
        if(status=='prepared') OutlinedButton(
          onPressed:busy?null:cancelPrepare,child:const Text('Band qilishni bekor qilish')),
        if(status=='proof_submitted') OutlinedButton.icon(
          onPressed:busy?null:()=>showReceipt(wave),
          icon:const Icon(Icons.receipt_long),label:const Text('To‘lov chekini ko‘rish')),
        if(ready) FilledButton(
          onPressed:busy?null:()=>confirm(wave),
          child:const Text('Bankni tekshirdim • jo‘natishga o‘tkazish')),
        if(status=='completed' && wave['order_id']!=null)
          SelectableText('Buyurtma ID: ${wave['order_id']}'),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d=detail;
    final waves=((d?['batches'] as List?)??const []).whereType<Map>().toList();
    final current=waves.where((w)=>['prepared','awaiting_payment','proof_submitted']
         .contains(w['status'])).toList();
    final originals=((d?['items'] as List?)??const []).whereType<Map>().toList();
    return Scaffold(
      appBar:AppBar(title:const Text('Qisman kelgan kitoblar'),
        actions:[IconButton(onPressed:busy?null:refresh,icon:const Icon(Icons.refresh))]),
      body:d==null ? Center(child:error!=null?Text(error!):const CircularProgressIndicator())
      :ListView(padding:const EdgeInsets.all(16),children:[
        if(busy)const LinearProgressIndicator(),
        Text('Jami avans: ${_won((d['deposit_amount'] as num?)?.toInt()??0)}',
           style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
        Text('Hali ajratilmagan avans: ${_won((d['deposit_remaining'] as num?)?.toInt()??0)}'),
        const SizedBox(height:14),
        for(final w in waves.reversed)
          if(w['status']!='cancelled') currentWave(Map<String,dynamic>.from(w)),
        if(current.isEmpty && d['closed']!=true) ...[
          const Text('Kelgan kitoblarni tanlang',
            style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
          const SizedBox(height:8),
          for(final raw in originals) ...[
            if(((raw['remaining_quantity'] as num?)?.toInt()??0)>0)
              Builder(builder:(context) {
                final ix=(raw['index'] as num).toInt();
                final e=entries[ix]??_PartialBookEntry(ix, (raw['remaining_quantity'] as num).toInt());
                return Card(child:Padding(
                  padding:const EdgeInsets.all(10),
                  child:Column(children:[
                    CheckboxListTile(
                      contentPadding:EdgeInsets.zero,
                      value:e.selected,
                      title:Text('${raw['book_title']??''}'),
                      subtitle:Text('Kutilmoqda: ${e.remaining} dona'),
                      onChanged:busy?null:(v)=>setState(()=>e.selected=v??false),
                    ),
                    if(e.selected) ...[
                      ListTile(
                        title:Text(e.book?.title??'Katalogdagi kitobni tanlang'),
                        subtitle:e.book!=null?Text('Ombor: ${e.book!.stock} dona'):null,
                        trailing:const Icon(Icons.search),
                        onTap:()async {
                          final book=await searchBook();
                          if(book!=null&&mounted)setState((){
                            e.book=book;
                            e.price=book.currentPrice;
                          });
                        },
                      ),
                      Row(children:[
                        Expanded(child:TextFormField(
                          key:ValueKey('partial-qty-$ix'),
                          initialValue:'${e.quantity}',
                          keyboardType:TextInputType.number,
                          decoration:const InputDecoration(labelText:'Kelgan soni'),
                          onChanged:(v)=>e.quantity=int.tryParse(v)??0,
                        )),
                        const SizedBox(width:12),
                        Expanded(child:TextFormField(
                          key:ValueKey('partial-price-$ix-${e.book?.id}'),
                          initialValue:'${e.price}',
                          keyboardType:TextInputType.number,
                          decoration:const InputDecoration(labelText:'Bitta narxi ₩'),
                          onChanged:(v)=>e.price=int.tryParse(v)??0,
                        )),
                      ]),
                    ],
                  ]),
                ));
              }),
          ],
          const SizedBox(height:12),
          FilledButton(onPressed:busy?null:prepare,
            child:const Text('Kelgan kitoblarni belgilash • mijozga xabar')),
        ],
        if(d['closed']==true) const Text(
          'Buyurtma yopilgan. Kelmagan kitoblar uchun qayta zakas berilishi mumkin.'),
      ]),
    );
  }
}
