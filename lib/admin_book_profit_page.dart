import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design_system.dart';
import 'admin_profit_charts.dart';

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
  DateTimeRange? selectedRange;

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
      params: {'p_secret':widget.secret,'p_period':period,
        'p_from': selectedRange==null?null:DateFormat('yyyy-MM-dd').format(selectedRange!.start),
        'p_to': selectedRange==null?null:DateFormat('yyyy-MM-dd').format(selectedRange!.end)},
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

  Widget _dashboardMetric(String caption,String value,IconData icon,
      Color color,Color soft,{String? note}) => Container(
    constraints:const BoxConstraints(minHeight:100),
    padding:const EdgeInsets.symmetric(horizontal:14,vertical:15),
    decoration:BoxDecoration(
      color:Colors.white,
      borderRadius:BorderRadius.circular(15),
      border:Border.all(color:edge),
      boxShadow:const [BoxShadow(color:Color(0x070E2846),
        blurRadius:15,offset:Offset(0,3))],
    ),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:43,height:43,decoration:BoxDecoration(
        color:soft,borderRadius:BorderRadius.circular(12)),
        child:Icon(icon,color:color,size:23)),
      const SizedBox(width:11),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(caption,maxLines:2,style:const TextStyle(
          color:Color(0xFF58667B),fontSize:12,fontWeight:FontWeight.w600)),
        const SizedBox(height:6),
        FittedBox(alignment:Alignment.centerLeft,fit:BoxFit.scaleDown,
          child:Text(value,style:const TextStyle(color:navy,
            fontSize:20,fontWeight:FontWeight.w900))),
        if(note!=null) ...[
          const SizedBox(height:5),
          Text(note,maxLines:2,style:const TextStyle(color:gray,fontSize:10.5)),
        ],
      ])),
    ]),
  );

  List<DataColumn> _tableHeader() => const [
    DataColumn(label:Text('#')),
    DataColumn(label:Text('Kitob')),
    DataColumn(label:Text('Kategoriya')),
    DataColumn(numeric:true,label:Text('Sotuv narxi')),
    DataColumn(numeric:true,label:Text('Joriy tan narxi')),
    DataColumn(numeric:true,label:Text('Sotilgan')),
    DataColumn(numeric:true,label:Text('Jami tushum')),
    DataColumn(numeric:true,label:Text('Jami foyda')),
    DataColumn(numeric:true,label:Text('Foyda %')),
    DataColumn(label:Text('Amallar')),
  ];

  Widget _tableValue(String value,{bool highlight=false}) => Text(
    value,style:TextStyle(fontWeight:FontWeight.w800,fontSize:12,
      color:highlight?green:navy));

  Widget _bookTable(List<Map<String,dynamic>> books,
      List<Map<String,dynamic>> sales) => _pane(SingleChildScrollView(
    scrollDirection:Axis.horizontal,
    child:DataTable(
      headingRowColor:WidgetStateProperty.all(const Color(0xFFF1F5FA)),
      dataRowMinHeight:56,dataRowMaxHeight:68,
      columnSpacing:21,
      horizontalMargin:12,
      dividerThickness:.6,
      headingTextStyle:const TextStyle(color:Color(0xFF435269),
        fontWeight:FontWeight.w800,fontSize:12),
      columns:_tableHeader(),
      rows:List<DataRow>.generate(books.length,(i){
        final b=books[i],revenue=_n(b,'revenue'),
          cost=_n(b,'cost_price');
        final pct=revenue>0
          ? (100*_n(b,'profit')/revenue).toStringAsFixed(1)+'%'
          : '—';
        return DataRow(cells:[
          DataCell(Text((i+1).toString())),
          DataCell(SizedBox(width:215,child:InkWell(
            onTap:()=>_openBook(b,sales),
            child:Row(children:[
              _cover(b),
              const SizedBox(width:10),
              Expanded(child:Column(
                mainAxisAlignment:MainAxisAlignment.center,
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text((b['title']??'Kitob').toString(),
                    maxLines:2,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(fontWeight:FontWeight.w800,
                      color:navy,fontSize:12.5)),
                  if((b['author']??'').toString().isNotEmpty)
                    Text((b['author']??'').toString(),maxLines:1,
                      overflow:TextOverflow.ellipsis,
                      style:const TextStyle(color:gray,fontSize:11)),
                ]),
              ),
            ]),
          ))),
          DataCell(SizedBox(width:133,child:Text(
            (b['category']??'').toString(),
            maxLines:2,overflow:TextOverflow.ellipsis,
            style:const TextStyle(color:Color(0xFF536177),fontSize:12)))),
          DataCell(_tableValue(_w(_n(b,'sale_price')))),
          DataCell(_tableValue(cost>0?_w(cost):'Noma’lum')),
          DataCell(_tableValue(_n(b,'sold').toString())),
          DataCell(_tableValue(_w(revenue))),
          DataCell(_tableValue(_w(_n(b,'profit')),highlight:true)),
          DataCell(_tableValue(pct)),
          DataCell(IconButton(
            tooltip:'Kitob foydasini ko‘rish',
            icon:const Icon(Icons.more_horiz_rounded,color:navy),
            onPressed:()=>_openBook(b,sales),
          )),
        ]);
      }),
    ),
  ));

  Future<void> _selectRange() async {
    final now=DateTime.now();
    final chosen=await showDateRangePicker(
      context:context,
      firstDate:DateTime(2024),
      lastDate:DateTime(now.year,now.month,now.day),
      initialDateRange:selectedRange,
      helpText:'Hisobot sanalarini tanlang',
      saveText:'Ko‘rsatish',
      cancelText:'Bekor qilish',
    );
    if(chosen==null || !mounted)return;
    setState((){
      selectedRange=chosen;
      period='custom';
      report=_fetch();
    });
  }

  String _periodLabel() {
    if(period=='custom' && selectedRange!=null) {
      return DateFormat('dd.MM.yy').format(selectedRange!.start)+' — '+
        DateFormat('dd.MM.yy').format(selectedRange!.end);
    }
    switch(period){
      case 'today':return 'Bugun';
      case 'yesterday':return 'Kecha';
      case 'week':return '7 kun';
      case 'month':return 'Shu oy';
      case 'previous_month':return 'O‘tgan oy';
      default:return 'Barcha davr';
    }
  }

  Widget _content(Map<String,dynamic> data) {
    final books=_list(data['books']);
    final sales=_list(data['recent_sales']);
    final daily=_list(data['daily']);
    final info=Map<String,dynamic>.from(data['summary'] as Map? ?? {});
    final categories=books.map((b)=>(b['category']??'').toString())
      .where((v)=>v.isNotEmpty).toSet().toList()..sort();
    final q=search.text.trim().toLowerCase();
    final visible=books.where((b)=>
      (category=='all'||b['category']==category) &&
      (q.isEmpty ||
        (b['title']??'').toString().toLowerCase().contains(q) ||
        (b['author']??'').toString().toLowerCase().contains(q))
      ).toList();
    int potential(Map<String,dynamic> b) =>
      _n(b,'cost_price')<=0?0:
      BookProfitMath.potential(_n(b,'sale_price'),
        _n(b,'cost_price'),_n(b,'stock'));
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
    final categoryProfits=<String,int>{};
    for(final b in books){
      final key=(b['category']??'Boshqa').toString();
      categoryProfits[key]=(categoryProfits[key]??0)+_n(b,'profit');
    }
    final missing=books.where((b)=>
      _n(b,'stock')>0 && _n(b,'cost_price')<=0).length;
    final salesCost=_n(info,'cost_of_goods');
    final stockProjection=books.fold<int>(0,(v,b)=>v+potential(b));
    final unlinked=Map<String,dynamic>.from(data['unlinked'] as Map? ?? {});

    return RefreshIndicator(onRefresh:_reload,
      child:LayoutBuilder(builder:(context,viewport){
        final available=(viewport.maxWidth-36).clamp(200.0,99999.0);
        final desktop=available>=970, tablet=available>=760;
        final metricsPerRow=available>=1280?5:
          available>=790?3:available>=440?2:1;
        final metricWidth=(available-(metricsPerRow-1)*10)/metricsPerRow;
        return ListView(
          physics:const AlwaysScrollableScrollPhysics(),
          padding:const EdgeInsets.fromLTRB(18,16,18,30),children:[
            Wrap(
              alignment:WrapAlignment.spaceBetween,
              crossAxisAlignment:WrapCrossAlignment.center,
              spacing:12,runSpacing:10,
              children:[
                const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('Kitoblar foydasi',style:TextStyle(
                    color:navy,fontWeight:FontWeight.w900,fontSize:25)),
                  SizedBox(height:5),
                  Text('Katalogdagi kitoblar va sotuvlardan olingan foyda',
                    style:TextStyle(color:gray,fontSize:12)),
                ]),
                OutlinedButton.icon(
                  onPressed:_selectRange,
                  icon:const Icon(Icons.calendar_today_outlined,size:18),
                  label:Text(_periodLabel()),
                ),
              ],
            ),
            const SizedBox(height:12),
            SingleChildScrollView(scrollDirection:Axis.horizontal,
              child:Row(children:[
                for(final item in const[
                  ('all','Barchasi'),('today','Bugun'),
                  ('yesterday','Kecha'),('week','7 kun'),
                  ('month','Shu oy'),('previous_month','O‘tgan oy'),
                ]) ...[
                  ChoiceChip(
                    label:Text(item.$2),selected:period==item.$1,
                    onSelected:(_)=>setState((){
                      period=item.$1;
                      selectedRange=null;
                      report=_fetch();
                    }),
                  ),
                  const SizedBox(width:7),
                ],
                IconButton.filledTonal(
                  tooltip:'Yangilash',onPressed:_reload,
                  icon:const Icon(Icons.refresh_rounded)),
              ]),
            ),
            const SizedBox(height:17),
            Wrap(spacing:10,runSpacing:10,children:[
              SizedBox(width:metricWidth,child:_dashboardMetric(
                'Jami kitoblar',books.length.toString(),
                Icons.menu_book_rounded,
                const Color(0xFF2878DF),const Color(0xFFE6F0FF),
                note:'Katalogdagi nomlar')),
              SizedBox(width:metricWidth,child:_dashboardMetric(
                'Sotilgan kitoblar',_n(info,'sold').toString(),
                Icons.shopping_cart_rounded,
                const Color(0xFF13A775),const Color(0xFFE0F7EB),
                note:'Tanlangan davrda')),
              SizedBox(width:metricWidth,child:_dashboardMetric(
                'Jami tushum',_w(_n(info,'revenue')),
                Icons.monetization_on_outlined,
                const Color(0xFFE49B18),const Color(0xFFFFF2D5),
                note:'Kitoblar sotilishidan')),
              SizedBox(width:metricWidth,child:_dashboardMetric(
                'Jami tan narxi',_w(salesCost),
                Icons.receipt_long_rounded,
                const Color(0xFFF39C32),const Color(0xFFFFEEDA),
                note:'Sotuv paytida saqlangan')),
              SizedBox(width:metricWidth,child:_dashboardMetric(
                'Kitoblar foydasi',_w(_n(info,'profit')),
                Icons.bar_chart_rounded,
                const Color(0xFF8759DF),const Color(0xFFF1E8FF),
                note:'Tushum − sotuvdagi tan narx')),
            ]),
            if(_n(info,'unknown_cost_sales')>0 || missing>0) ...[
              const SizedBox(height:12),
              _pane(Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Icon(Icons.info_outline_rounded,
                  color:Color(0xFFB97913)),
                const SizedBox(width:9),
                Expanded(child:Text('Tan narxi noma’lum sotuvlar: '+
                  _n(info,'unknown_cost_sales').toString()+
                  '; hozirgi tan narxi kiritilmagan kitoblar: '+
                  missing.toString()+'. Noma’lum foyda taxmin qilinmaydi.',
                  style:const TextStyle(color:Color(0xFF8B671F),
                    fontSize:12))),
              ])),
            ],
            const SizedBox(height:14),
            if(desktop)
              Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Expanded(flex:7,child:_pane(
                  ProfitDashboardTrend(daily:daily))),
                const SizedBox(width:12),
                Expanded(flex:4,child:_pane(
                  ProfitDashboardDonut(categoryProfit:categoryProfits))),
              ])
            else ...[
              _pane(ProfitDashboardTrend(daily:daily)),
              const SizedBox(height:12),
              _pane(ProfitDashboardDonut(categoryProfit:categoryProfits)),
            ],
            const SizedBox(height:12),
            if(tablet)
              Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Expanded(flex:6,child:_top(top,sales)),
                const SizedBox(width:12),
                Expanded(flex:4,child:_pane(
                  Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    _title('Ombordan kutilayotgan foyda'),
                    Text(_w(stockProjection),style:const TextStyle(
                      color:green,fontSize:22,fontWeight:FontWeight.w900)),
                    const SizedBox(height:9),
                    const Text('Qolgan kitoblarning hozirgi tan narxi '
                      'va joriy sotuv narxiga qarab hisoblanadi.',
                      style:TextStyle(fontSize:12,color:gray,height:1.45)),
                  ])),
                )),
              ])
            else ...[
              _top(top,sales),
              const SizedBox(height:12),
              _pane(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                _title('Ombordan kutilayotgan foyda'),
                Text(_w(stockProjection),style:const TextStyle(
                  color:green,fontSize:23,fontWeight:FontWeight.w900)),
                const Text('Joriy tan narxi asosida, hali olinmagan.',
                  style:TextStyle(color:gray,fontSize:12)),
              ])),
            ],
            const SizedBox(height:16),
            _pane(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                const Expanded(child:Text('Katalogdagi kitoblar va foyda',
                  style:TextStyle(color:navy,fontSize:17,
                    fontWeight:FontWeight.w900))),
                OutlinedButton.icon(onPressed:()=>_export(visible),
                  icon:const Icon(Icons.file_download_outlined,size:17),
                  label:const Text('Excel')),
              ]),
              const SizedBox(height:11),
              TextField(controller:search,
                onChanged:(_)=>setState((){}),
                decoration:const InputDecoration(
                  hintText:'Kitob nomi yoki muallif bo‘yicha qidirish...',
                  prefixIcon:Icon(Icons.search_rounded))),
              const SizedBox(height:9),
              Wrap(spacing:8,runSpacing:8,children:[
                SizedBox(width:185,child:DropdownButtonFormField<String>(
                  value:category,isExpanded:true,
                  decoration:const InputDecoration(labelText:'Kategoriya'),
                  items:[
                    const DropdownMenuItem(value:'all',
                      child:Text('Barchasi')),
                    for(final c in categories)
                      DropdownMenuItem(value:c,child:Text(c,
                        overflow:TextOverflow.ellipsis)),
                  ],
                  onChanged:(v)=>setState(()=>category=v??'all'))),
                SizedBox(width:185,child:DropdownButtonFormField<String>(
                  value:sort,isExpanded:true,
                  decoration:const InputDecoration(labelText:'Saralash'),
                  items:const[
                    DropdownMenuItem(value:'profit',
                      child:Text('Eng ko‘p foyda')),
                    DropdownMenuItem(value:'expected',
                      child:Text('Kutilayotgan foyda')),
                    DropdownMenuItem(value:'stock',
                      child:Text('Ko‘p qoldiq')),
                    DropdownMenuItem(value:'name',
                      child:Text('Nomi bo‘yicha')),
                  ],
                  onChanged:(v)=>setState(()=>sort=v??'profit'))),
              ]),
              const SizedBox(height:8),
              Text('Natija: '+visible.length.toString()+' ta kitob',
                style:const TextStyle(color:gray,fontSize:11)),
            ])),
            const SizedBox(height:8),
            if(visible.isEmpty)
              _pane(const Text('Qidiruvga mos kitob yo‘q.'))
            else if(tablet)
              _bookTable(visible,sales)
            else
              for(final b in visible) ...[
                _book(b,sales),const SizedBox(height:8),
              ],
            const SizedBox(height:9),
            if(_n(unlinked,'sold')>0)
              _pane(Text('Katalogga bog‘lanmagan tarixiy savdolar: '+
                _n(unlinked,'sold').toString()+' dona. Olingan foyda: '+
                _w(_n(unlinked,'profit'))+
                '. Bu umumiy foydaga qo‘shilgan.',
                style:const TextStyle(color:gray,fontSize:12))),
            const SizedBox(height:12),
            const Text('Muhim: “Kitoblar foydasi” — faqat sotuv tushumi '
              'bilan o‘sha sotuvda saqlangan tan narxi farqi. Pochta, '
              'reklama va boshqa do‘kon xarajatlari Moliya bo‘limida '
              'hisoblanadi. Oldingi savdolar keyingi narx o‘zgarishi bilan '
              'qayta hisoblanmaydi.',
              style:TextStyle(color:gray,fontSize:11.5,height:1.4)),
          ],
        );
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
