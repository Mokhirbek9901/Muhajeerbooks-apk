import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design_system.dart';

/// Read-only admin report. Completed sales have frozen unit cost and price.
class AdminBookProfitPage extends StatefulWidget {
  const AdminBookProfitPage({super.key, required this.secret});
  final String secret;
  @override
  State<AdminBookProfitPage> createState() => _AdminBookProfitPageState();
}

class BookProfitMath {
  static int amount(dynamic value) => value is num
      ? value.round() : int.tryParse(value?.toString() ?? '') ?? 0;
  static int profit(int sale, int cost) => sale - cost;
  static int potential(int sale, int cost, int stock) =>
      (sale - cost) * stock;
  static String won(int value) => (value < 0 ? '−' : '') + '₩' +
      NumberFormat('#,###', 'en_US').format(value.abs());
}

class _AdminBookProfitPageState extends State<AdminBookProfitPage> {
  static const navy = Color(0xFF192B44);
  static const green = Color(0xFF05966A);
  static const gray = Color(0xFF758296);
  static const edge = Color(0xFFE2E9F1);
  final search = TextEditingController();
  late Future<Map<String, dynamic>> report;
  String period = 'all', category = 'all', sort = 'profit';

  @override
  void initState() {
    super.initState();
    report = _fetch();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<Map<String,dynamic>> _fetch() async {
    final raw = await Supabase.instance.client.rpc(
      'admin_book_profit_report',
      params: {'p_secret':widget.secret,'p_period':period},
    );
    if (raw is! Map) throw StateError('Foyda hisoboti olinmadi.');
    return Map<String,dynamic>.from(raw);
  }

  Future<void> _reload() async {
    final next = _fetch();
    setState(() => report = next);
    try { await next; } catch (_) { /* Shown in the error view. */ }
  }

  List<Map<String,dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList()
      : <Map<String,dynamic>>[];

  int _n(Map<String,dynamic> r,String k) => BookProfitMath.amount(r[k]);
  String _w(int n) => BookProfitMath.won(n);

  Widget _pane(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:Colors.white,border:Border.all(color:edge),
      borderRadius:BorderRadius.circular(16)),
    child:child,
  );

  Widget _title(String name) => Padding(
    padding:const EdgeInsets.only(bottom:10),
    child:Text(name,style:const TextStyle(
      color:navy,fontSize:17,fontWeight:FontWeight.w900)),
  );

  Widget _metric(String label,String value,IconData icon,Color tint,
      [String? note]) => _pane(Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:tint,size:24),
      const SizedBox(height:8),
      Text(label,style:const TextStyle(color:gray,fontSize:12)),
      const SizedBox(height:4),
      FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
        child:Text(value,style:const TextStyle(
          color:navy,fontSize:21,fontWeight:FontWeight.w900))),
      if (note!=null) ...[
        const SizedBox(height:4),
        Text(note,style:const TextStyle(color:gray,fontSize:10)),
      ],
    ],
  ));

  Widget _entry(String name,String value) => Padding(
    padding:const EdgeInsets.symmetric(vertical:5),
    child:Row(children:[
      Expanded(child:Text(name,style:const TextStyle(
        color:gray,fontSize:12))),
      const SizedBox(width:6),
      Text(value,style:const TextStyle(
        color:navy,fontWeight:FontWeight.w800)),
    ]),
  );

  String _source(dynamic v) {
    if (v=='telegram') return 'Telegram';
    if (v=='instagram') return 'Instagram';
    return 'Ilova';
  }

  void _openBook(Map<String,dynamic> book,List<Map<String,dynamic>> sales) {
    final bookSales = sales.where((s) => s['book_id']==book['id']).toList();
    final cost = _n(book,'cost_price');
    final price = _n(book,'sale_price');
    showModalBottomSheet<void>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(ctx)=>SafeArea(child:FractionallySizedBox(
        heightFactor:.8,
        child:ListView(padding:const EdgeInsets.fromLTRB(18,6,18,26),children:[
          Text((book['title']??'Kitob').toString(),
            style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),
          const Text('Hozirgi katalog narxlari',
            style:TextStyle(color:gray)),
          _entry('Tan narxi',cost>0?_w(cost):'Kiritilmagan'),
          _entry('Sotuv narxi',_w(price)),
          _entry('Bir donadan foyda',cost>0?_w(price-cost):'Hisoblanmaydi'),
          _entry('Omborda',_n(book,'stock').toString()+' dona'),
          _entry('Olingan foyda',_w(_n(book,'profit'))),
          const SizedBox(height:16),
          _title('Sotilgan vaqtdagi narxlar'),
          const Text('Bu raqamlar sotuv vaqtida saqlangan. '
            'Keyingi narx yoki partiya o‘zgarishlari ta’sir qilmaydi.',
            style:TextStyle(color:gray,fontSize:12)),
          const SizedBox(height:8),
          if(bookSales.isEmpty)
            const Text('Oxirgi 250 ta sotuv ichida topilmadi.',
              style:TextStyle(color:gray))
          else for(final sale in bookSales) ...[
            const Divider(height:22),
            Text(_date(sale['sold_at'])+' • '+_source(sale['source']),
              style:const TextStyle(color:gray,fontSize:12)),
            _entry('Sotilgan narxi',_w(_n(sale,'unit_price'))),
            _entry('O‘sha paytdagi tan narxi',sale['cost_known']==true
              ? _w(_n(sale,'unit_cost')):'Noma’lum'),
            _entry('Saqlangan foyda',sale['cost_known']==true
              ? _w(_n(sale,'unit_price')-_n(sale,'unit_cost'))
              :'Hisoblanmaydi'),
          ],
        ]),
      )),
    );
  }

  String _date(dynamic value) {
    final dt=DateTime.tryParse((value??'').toString())?.toLocal();
    return dt==null?'Sana noma’lum':DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  Future<void> _export(List<Map<String,dynamic>> list) async {
    String q(dynamic v) => '"' + (v??'').toString().replaceAll('"','""')+'"';
    final lines=<List<dynamic>>[
      ['Kitob','Kategoriya','Tan narxi (KRW)','Sotuv narxi (KRW)',
       'Ombor','Sotilgan','Tushum (KRW)','Foyda (KRW)'],
      for(final b in list)
        [b['title'],b['category'],b['cost_price'],b['sale_price'],b['stock'],
         b['sold'],b['revenue'],b['profit']],
    ];
    await Clipboard.setData(ClipboardData(
      text:lines.map((row)=>row.map(q).join(',')).join('\n')));
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:Text('Jadval nusxalandi. Excel yoki Sheets’ga joylang.')));
  }

  Widget _cover(Map<String,dynamic> b) {
    final url=(b['image_url']??'').toString();
    return ClipRRect(borderRadius:BorderRadius.circular(7),
      child:SizedBox(width:38,height:51,child:
        url.startsWith('https://')
        ? Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>
            const Icon(Icons.menu_book_rounded,color:navy))
        : const Icon(Icons.menu_book_rounded,color:navy)));
  }

  Widget _book(Map<String,dynamic> b,List<Map<String,dynamic>> sales) {
    final cost=_n(b,'cost_price'), price=_n(b,'sale_price');
    final stock=_n(b,'stock');
    return _pane(InkWell(onTap:()=>_openBook(b,sales),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          _cover(b),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text((b['title']??'').toString(),
                style:const TextStyle(fontWeight:FontWeight.w900,color:navy),
                maxLines:2,overflow:TextOverflow.ellipsis),
              Text((b['category']??'').toString(),
                style:const TextStyle(color:gray,fontSize:11)),
            ])),
          const Icon(Icons.chevron_right_rounded,color:gray),
        ]),
        const SizedBox(height:10),
        Wrap(spacing:8,runSpacing:7,children:[
          _tag('Tan narxi: '+(cost>0?_w(cost):'yo‘q')),
          _tag('Sotuv: '+_w(price)),
          _tag('Sotilgan: '+_n(b,'sold').toString()),
          _tag('Qoldiq: '+stock.toString()),
        ]),
        const Divider(height:22),
        Row(children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              const Text('Olingan foyda',style:TextStyle(color:gray,fontSize:11)),
              Text(_w(_n(b,'profit')),style:const TextStyle(
                color:green,fontSize:17,fontWeight:FontWeight.w900)),
            ])),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,
            children:[
              const Text('Kutilayotgan foyda',style:
                TextStyle(color:gray,fontSize:11)),
              Text(cost>0?_w(BookProfitMath.potential(price,cost,stock)):'Noma’lum',
                style:const TextStyle(color:navy,fontWeight:FontWeight.w900)),
            ])),
        ]),
        if(_n(b,'unknown_cost_sales')>0) ...[
          const SizedBox(height:7),
          Text('Tan narxi noma’lum sotuvlar: '+
            _n(b,'unknown_cost_sales').toString(),
            style:const TextStyle(color:Color(0xFFB87519),fontSize:11)),
        ],
      ]),
    ));
  }

  Widget _tag(String text)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:7,vertical:5),
    decoration:BoxDecoration(color:const Color(0xFFEEF3FA),
      borderRadius:BorderRadius.circular(7)),
    child:Text(text,style:const TextStyle(fontSize:11,color:navy)),
  );

  Widget _chart(List<Map<String,dynamic>> daily)=>_pane(Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      _title('Foyda dinamikasi'),
      if(daily.isEmpty)
        const Text('Bu davrda sotuv yo‘q.',style:TextStyle(color:gray))
      else
        for(final d in (daily.length>12 ? daily.sublist(daily.length-12) : daily))
          Padding(padding:const EdgeInsets.only(bottom:7),child:Row(children:[
            SizedBox(width:84,child:Text((d['date']??'').toString(),
              style:const TextStyle(color:gray,fontSize:11))),
            Expanded(child:LinearProgressIndicator(
              value:(_n(d,'profit').clamp(0,999999999) /
                (daily.map((r)=>_n(r,'profit'))
                  .fold<int>(1,(a,b)=>b>a?b:a))).clamp(0.0,1.0).toDouble(),
              minHeight:8,borderRadius:BorderRadius.circular(4),
              color:green,backgroundColor:const Color(0xFFE6EAF2))),
            const SizedBox(width:7),
            SizedBox(width:95,child:Text(_w(_n(d,'profit')),
              textAlign:TextAlign.end,style:const TextStyle(fontSize:11,
                fontWeight:FontWeight.w700))),
          ])),
    ]));

  Widget _top(List<Map<String,dynamic>> top,List<Map<String,dynamic>> sales) =>
    _pane(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _title('Eng foydali kitoblar (Top 5)'),
      if(top.isEmpty) const Text('Hozircha sotuv yo‘q.',
        style:TextStyle(color:gray))
      else for(var i=0;i<top.length && i<5;i++)
        ListTile(dense:true,contentPadding:EdgeInsets.zero,
          leading:CircleAvatar(radius:15,child:Text((i+1).toString())),
          title:Text((top[i]['title']??'').toString(),
            maxLines:1,overflow:TextOverflow.ellipsis),
          subtitle:Text(_n(top[i],'sold').toString()+' dona sotilgan'),
          trailing:Text(_w(_n(top[i],'profit')),style:const TextStyle(
            color:green,fontWeight:FontWeight.w800,fontSize:12)),
          onTap:()=>_openBook(top[i],sales)),
    ]));

  Widget _content(Map<String,dynamic> data) {
    final books=_list(data['books']);
    final sales=_list(data['recent_sales']);
    final daily=_list(data['daily']);
    final info=Map<String,dynamic>.from(data['summary'] as Map? ?? {});
    final categories=books.map((b)=>(b['category']??'').toString())
      .where((s)=>s.isNotEmpty).toSet().toList()..sort();
    final q=search.text.trim().toLowerCase();
    final visible=books.where((b)=>(
      category=='all' || b['category']==category) &&
      (q.isEmpty || (b['title']??'').toString().toLowerCase().contains(q) ||
      (b['author']??'').toString().toLowerCase().contains(q))).toList();
    int potential(Map<String,dynamic> b) => _n(b,'cost_price')>0
      ? BookProfitMath.potential(_n(b,'sale_price'),_n(b,'cost_price'),
          _n(b,'stock')) : 0;
    switch(sort){
      case 'name':
        visible.sort((a,b)=>(a['title']??'').toString().compareTo(
          (b['title']??'').toString()));
      case 'stock':
        visible.sort((a,b)=>_n(b,'stock').compareTo(_n(a,'stock')));
      case 'expected':
        visible.sort((a,b)=>potential(b).compareTo(potential(a)));
      default:
        visible.sort((a,b)=>_n(b,'profit').compareTo(_n(a,'profit')));
    }
    final top=books.where((b)=>_n(b,'sold')>0).toList()
      ..sort((a,b)=>_n(b,'profit').compareTo(_n(a,'profit')));
    final expected=books.fold<int>(0,(total,b)=>total+potential(b));
    final missing=books.where((b)=>_n(b,'stock')>0 &&
      _n(b,'cost_price')<=0).length;
    final categoryTotals=<String,int>{};
    for(final b in books){
      final cat=(b['category']??'Boshqa').toString();
      categoryTotals[cat]=(categoryTotals[cat]??0)+_n(b,'profit');
    }
    final ranked=categoryTotals.entries.toList()
      ..sort((a,b)=>b.value.compareTo(a.value));
    final unlinked = Map<String,dynamic>.from(data['unlinked'] as Map? ?? {});
    return RefreshIndicator(onRefresh:_reload,
      child:LayoutBuilder(builder:(context,c){
        final wide=c.maxWidth>=750;
        final cardWidth=c.maxWidth>=900?(c.maxWidth-30)/4:
          c.maxWidth>=460?(c.maxWidth-10)/2:c.maxWidth;
        return ListView(physics:const AlwaysScrollableScrollPhysics(),
          padding:const EdgeInsets.fromLTRB(14,16,14,30),children:[
            Row(children:[
              const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text('Kitoblar foydasi',style:TextStyle(color:navy,
                    fontSize:23,fontWeight:FontWeight.w900)),
                  SizedBox(height:4),
                  Text('Har bir sotuvning tan narxi tarixda saqlanadi.',
                    style:TextStyle(color:gray,fontSize:12)),
                ])),
              IconButton.filledTonal(icon:const Icon(Icons.refresh_rounded),
                tooltip:'Yangilash',onPressed:_reload),
            ]),
            const SizedBox(height:12),
            SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(
              children:[for(final item in const [
                ('all','Barchasi'),('today','Bugun'),('yesterday','Kecha'),
                ('week','7 kun'),('month','Shu oy'),
                ('previous_month','O‘tgan oy'),
              ]) ...[
                ChoiceChip(label:Text(item.$2),selected:period==item.$1,
                  onSelected:(_)=>setState((){
                    period=item.$1;
                    report=_fetch();
                  })),
                const SizedBox(width:7),
              ]])),
            const SizedBox(height:12),
            Wrap(spacing:10,runSpacing:10,children:[
              SizedBox(width:cardWidth,child:_metric('Katalogdagi kitoblar',
                books.length.toString(),Icons.menu_book_rounded,Colors.blue)),
              SizedBox(width:cardWidth,child:_metric('Sotilgan nusxalar',
                _n(info,'sold').toString(),Icons.shopping_cart_rounded,green)),
              SizedBox(width:cardWidth,child:_metric('Olingan foyda',
                _w(_n(info,'profit')),Icons.payments_rounded,Colors.orange,
                'Sotuv narxi − sotuv vaqtidagi tan narxi')),
              SizedBox(width:cardWidth,child:_metric('Kutilayotgan foyda',
                _w(expected),Icons.trending_up_rounded,Colors.purple,
                'Hozirgi ombor va joriy narxlar')),
            ]),
            if(_n(info,'unknown_cost_sales')>0 || missing>0) ...[
              const SizedBox(height:10),
              _pane(Text('Tan narxi noma’lum sotuvlar: '+
                _n(info,'unknown_cost_sales').toString()+
                '. Tan narxi kiritilmagan ombordagi kitoblar: '+
                missing.toString()+'. Foydasi taxmin qilinmadi.',
                style:const TextStyle(color:Color(0xFFB87519)))),
            ],
            if(_n(unlinked,'sold')>0) ...[
              const SizedBox(height:10),
              _pane(Text('Katalogga bog‘lanmagan avvalgi savdolar: '+
                _n(unlinked,'sold').toString()+' dona, foyda '+
                _w(_n(unlinked,'profit'))+'. Jami foydaga qo‘shilgan.',
                style:const TextStyle(color:navy,fontSize:12))),
            ],
            const SizedBox(height:14),
            if(wide) Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Expanded(child:_chart(daily)),
              const SizedBox(width:12),
              Expanded(child:_top(top,sales)),
            ]) else ...[
              _chart(daily),
              const SizedBox(height:12),
              _top(top,sales),
            ],
            const SizedBox(height:16),
            _title('Katalogdagi kitoblar va foyda'),
            TextField(controller:search,onChanged:(_)=>setState((){}),
              decoration:const InputDecoration(
                prefixIcon:Icon(Icons.search_rounded),
                hintText:'Kitob nomi yoki muallif bo‘yicha qidirish')),
            const SizedBox(height:8),
            Wrap(spacing:8,runSpacing:8,children:[
              SizedBox(width:170,child:DropdownButtonFormField<String>(
                value:category,isExpanded:true,
                decoration:const InputDecoration(labelText:'Kategoriya'),
                items:[
                  const DropdownMenuItem(value:'all',child:Text('Barchasi')),
                  for(final c in categories)
                    DropdownMenuItem(value:c,
                      child:Text(c,overflow:TextOverflow.ellipsis)),
                ],
                onChanged:(v)=>setState(()=>category=v??'all'))),
              SizedBox(width:170,child:DropdownButtonFormField<String>(
                value:sort,decoration:const InputDecoration(labelText:'Saralash'),
                items:const[
                  DropdownMenuItem(value:'profit',child:Text('Ko‘p foyda')),
                  DropdownMenuItem(value:'expected',child:Text('Kutilayotgan foyda')),
                  DropdownMenuItem(value:'stock',child:Text('Ko‘p qoldiq')),
                  DropdownMenuItem(value:'name',child:Text('Kitob nomi')),
                ],
                onChanged:(v)=>setState(()=>sort=v??'profit'))),
              OutlinedButton.icon(
                icon:const Icon(Icons.copy_all_rounded),
                label:const Text('Excel uchun nusxalash'),
                onPressed:()=>_export(visible)),
            ]),
            const SizedBox(height:12),
            if(visible.isEmpty)
              _pane(const Text('Mos kitob topilmadi.'))
            else for(final b in visible) ...[
              _book(b,sales),
              const SizedBox(height:8),
            ],
            const SizedBox(height:12),
            _title('Kategoriyalar bo‘yicha foyda'),
            _pane(Column(children:[
              for(final e in ranked) _entry(e.key,_w(e.value)),
            ])),
            const SizedBox(height:12),
            const Text('Bu sahifada kitob foydasi = sotuv narxi − sotuv '
              'vaqtidagi tan narxi. Pochta, reklama va umumiy xarajatlar '
              'Moliya bo‘limida alohida hisoblanadi. Oldingi sotuvlarning '
              'narxi keyingi partiya yoki katalogdagi o‘zgarishlardan '
              'qayta hisoblanmaydi.',
              style:TextStyle(color:gray,fontSize:11.5,height:1.45)),
          ]);
      }),
    );
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    appBar:AppBar(title:const Text('Kitoblar foydasi'),
      backgroundColor:Colors.white),
    body:FutureBuilder<Map<String,dynamic>>(
      future:report,
      builder:(context,s){
        if(s.connectionState==ConnectionState.waiting && s.data==null)
          return const Center(child:CircularProgressIndicator());
        if(s.hasError)
          return Center(child:Padding(padding:const EdgeInsets.all(24),
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              Text('Foyda hisobotida xatolik: '+s.error.toString(),
                textAlign:TextAlign.center),
              const SizedBox(height:12),
              FilledButton(onPressed:_reload,child:const Text('Qayta urinish')),
            ])));
        return _content(s.data??{});
      },
    ),
  );
}
