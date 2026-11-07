import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Only a new, admin-secret protected screen. Existing admin pages are unchanged.
class AdminSalesInventoryAnalyticsPage extends StatefulWidget {
  const AdminSalesInventoryAnalyticsPage({super.key, required this.secret});
  final String secret;
  @override
  State<AdminSalesInventoryAnalyticsPage> createState() =>
      _AdminSalesInventoryAnalyticsPageState();
}
class _AdminSalesInventoryAnalyticsPageState extends State<AdminSalesInventoryAnalyticsPage> {
  static const navy = Color(0xFF26384D), brown = Color(0xFF926B49);
  final money = NumberFormat.decimalPattern('en_US');
  int days = 30;
  String channel = 'all';
  bool loading = true;
  String? error;
  Map<String,dynamic> report = {};
  static const sources = {'all':'Barchasi','app':'Ilova','instagram':'Instagram',
    'telegram':'Telegram','sms':'SMS','phone':'Telefon','in_person':'Shaxsan'};
  Map<String,dynamic> obj(dynamic x) =>
    x is Map ? Map<String,dynamic>.from(x) : <String,dynamic>{};
  List<Map<String,dynamic>> rows(dynamic x) =>
    x is List ? x.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList() : [];
  num number(dynamic x) => x is num ? x : num.tryParse(x.toString()) ?? 0;
  String count(dynamic x)=>money.format(number(x).round());
  String won(dynamic x)=>'₩'+count(x);
  @override
  void initState(){super.initState(); load();}
  Future<void> load() async {
    setState((){loading=true;error=null;});
    try {
      final response=await Supabase.instance.client.rpc('admin_sales_inventory_analytics',
        params:{'p_secret':widget.secret,'p_days':days,'p_source':channel});
      if(mounted)setState(()=>report=obj(response));
    } catch(e) {
      if(mounted)setState(()=>error='Hisobot yuklanmadi: '+e.toString());
    } finally {if(mounted)setState(()=>loading=false);}
  }
  Widget card(String title,Widget body,{IconData icon=Icons.insights})=>Card(
    elevation:0,color:Colors.white,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
      side:const BorderSide(color:Color(0xFFE8E1D7))),
    child:Padding(padding:const EdgeInsets.all(16),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Icon(icon,color:brown,size:20),const SizedBox(width:8),
          Expanded(child:Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)))]),
        const SizedBox(height:14),body,
      ])));
  Widget metric(String label,String value,IconData icon)=>Container(
    width:176,padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
      border:Border.all(color:const Color(0xFFE8E1D7))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(icon,size:18,color:brown),const SizedBox(width:8),
        Expanded(child:Text(label,style:const TextStyle(fontSize:12)))]),
      const SizedBox(height:10),
      FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
        child:Text(value,style:const TextStyle(fontSize:22,color:navy,
          fontWeight:FontWeight.w900))),
    ]));
  Widget bars(String field,String label,{bool currency=false}) {
    final data=rows(report[field]);
    if(data.isEmpty)return const Text('Bu davrda sotuv topilmadi');
    final maxValue=data.fold<num>(0,(a,b)=>math.max(a,number(b[currency?'revenue':'sold'])));
    return Column(children:[
      for(final row in data.take(12))
        Padding(padding:const EdgeInsets.only(bottom:13),child:Column(children:[
          Row(children:[Expanded(child:Text(field=='genres'
            ? (row['category']??'Boshqalar').toString()
            : (sources[row['source']]??row['source']??'').toString(),
            overflow:TextOverflow.ellipsis)),
            Text(currency?won(row['revenue']):count(row['sold'])+' dona',
              style:const TextStyle(fontWeight:FontWeight.w700))]),
          const SizedBox(height:6),
          ClipRRect(borderRadius:BorderRadius.circular(8),
            child:LinearProgressIndicator(minHeight:10,
              backgroundColor:const Color(0xFFF2EBE5),
              value:maxValue<=0?0:(number(row[currency?'revenue':'sold'])/maxValue).clamp(0,1).toDouble(),
              valueColor:AlwaysStoppedAnimation<Color>(currency?navy:brown))),
        ])),
    ]);
  }
  Widget trend() {
    final data=rows(report['daily']);
    if(data.isEmpty)return const Text('Ma’lumot yo‘q');
    final revenue=data.map((r)=>number(r['revenue'])).toList();
    final values=days==365?List<num>.generate(12,(i){
      final start=i*revenue.length~/12,end=(i+1)*revenue.length~/12;
      return revenue.sublist(start,end).fold<num>(0,(a,b)=>a+b);
    }):revenue;
    return Column(children:[
      SizedBox(height:150,child:CustomPaint(painter:_SalesTrendPainter(values),
        child:const SizedBox.expand())),
      const SizedBox(height:8),
      Text(days==30?'30 kunlik tushum':'12 davr bo‘yicha tushum',
        style:const TextStyle(fontSize:12,color:Colors.black54)),
    ]);
  }
  Widget turnover() {
    final all=rows(report['books']);
    final ready=all.where((b)=>b['turnover']!=null).toList()
      ..sort((a,b)=>number(b['turnover']).compareTo(number(a['turnover'])));
    final unknown=all.length-ready.length;
    return card('Aylanma hisobi',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Aylanma = sotilgan dona ÷ o‘rtacha ombor qoldig‘i',
        style:TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:7),
      Text('Qoldiq tarixi yangi yig‘ila boshlandi. '+count(unknown)+
        ' xil kitobda tanlangan davr uchun to‘liq tarix yo‘q. '
        'Ularning aylanmasi taxmin qilinmaydi.',
        style:const TextStyle(fontSize:12,color:Colors.black54)),
      const SizedBox(height:12),
      if(ready.isEmpty)
        const Padding(padding:EdgeInsets.all(12),
          child:Text('30 kunlik / 1 yillik qoldiq tarixi to‘lganda aniq × ko‘rsatkich chiqadi.')),
      if(ready.isNotEmpty)SingleChildScrollView(scrollDirection:Axis.horizontal,
        child:DataTable(columns:const [
          DataColumn(label:Text('Kitob')),DataColumn(label:Text('Sotuv')),
          DataColumn(label:Text('Qoldiq (o‘rtacha)')),
          DataColumn(label:Text('Aylanma')),DataColumn(label:Text('Tavsiya')),
        ],rows:ready.map((b){
          final t=number(b['turnover']);
          final recommendation=t>=2?'Qayta keltirish':t<.5?'Chegirmani ko‘rib chiqing':'Kuzatish';
          return DataRow(cells:[
            DataCell(SizedBox(width:190,child:Text(b['title'].toString(),
              maxLines:2,overflow:TextOverflow.ellipsis))),
            DataCell(Text(count(b['sold']))),
            DataCell(Text(b['avg_stock'].toString())),
            DataCell(Text('×'+t.toStringAsFixed(2))),
            DataCell(Text(recommendation)),
          ]);
        }).toList())),
    ]),icon:Icons.autorenew);
  }
  Widget inventory() {
    final b=rows(report['books'])..sort((a,b)=>number(a['stock']).compareTo(number(b['stock'])));
    return card('Ombor va kam qolgan kitoblar',Column(children:[
      for(final x in b.take(15))
        Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[
          Expanded(child:Text(x['title'].toString(),overflow:TextOverflow.ellipsis)),
          Text(count(x['stock'])+' dona',style:TextStyle(fontWeight:FontWeight.bold,
            color:number(x['stock'])<=2?Colors.red:navy)),
        ])),
    ]),icon:Icons.inventory_2_outlined);
  }
  Widget supplier() => card('Yetkazib beruvchilar va partiyalar',Column(children:[
    for(final x in rows(report['suppliers']))
      Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[
        Expanded(child:Text(x['name'].toString())),
        Text(count(x['units'])+' dona'),
      ])),
    const SizedBox(height:8),
    OutlinedButton.icon(
      onPressed:manageSuppliers,
      icon:const Icon(Icons.edit_outlined),
      label:const Text('Yetkazib beruvchilarni boshqarish')),
    const SizedBox(height:8),
    const Text('Eski partiyalarning yetkazib beruvchisi ko‘rsatilmagan bo‘lsa, '
      'taxminiy nom yozilmaydi.',
      style:TextStyle(fontSize:12,color:Colors.black54)),
  ]),icon:Icons.local_shipping_outlined);
  Future<void> manageSuppliers() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder:(_)=>_InventorySupplierPage(secret:widget.secret)));
    if(mounted)await load();
  }
  Widget categoryInvestments() {
    final genres=rows(report['genres']);
    return card('Kategoriya menejmenti',
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Janrlar bo‘yicha sotuv, foyda va omborga bog‘langan '
          'tannarx. Eski katalogga bog‘lanmagan sotuvlar alohida.',
          style:TextStyle(fontSize:12,color:Colors.black54)),
        const SizedBox(height:10),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
          columns:const [
            DataColumn(label:Text('Kategoriya')),
            DataColumn(label:Text('Sotilgan')),
            DataColumn(label:Text('Tushum')),
            DataColumn(label:Text('Yalpi foyda')),
            DataColumn(label:Text('Ombor kapitali')),
          ],
          rows:genres.map((g)=>DataRow(cells:[
            DataCell(SizedBox(width:160,child:Text(g['category'].toString(),
              maxLines:2,overflow:TextOverflow.ellipsis))),
            DataCell(Text(count(g['sold']))),
            DataCell(Text(won(g['revenue']))),
            DataCell(Text(won(g['profit']))),
            DataCell(Text(won(g['stock_value']))),
          ])).toList(),
        )),
      ]),icon:Icons.category_outlined);
  }
  Future<void> offline() async {
    final ok=await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder:(_)=>_OfflineSalePage(secret:widget.secret,books:rows(report['books']))));
    if(ok==true&&mounted)await load();
  }
  @override
  Widget build(BuildContext context) {
    final s=obj(report['summary']);
    return Scaffold(
      backgroundColor:const Color(0xFFFFFAF4),
      appBar:AppBar(backgroundColor:const Color(0xFFFFFAF4),
        title:const Text('Savdo va ombor tahlili'),
        actions:[IconButton(onPressed:loading?null:load,icon:const Icon(Icons.refresh))]),
      floatingActionButton:FloatingActionButton.extended(
        onPressed:loading?null:offline,backgroundColor:brown,foregroundColor:Colors.white,
        icon:const Icon(Icons.add_shopping_cart),label:const Text('Oflayn sotuv')),
      body:loading&&report.isEmpty?const Center(child:CircularProgressIndicator()):
        RefreshIndicator(onRefresh:load,child:ListView(
          padding:const EdgeInsets.fromLTRB(16,8,16,100),children:[
          Wrap(spacing:9,runSpacing:9,crossAxisAlignment:WrapCrossAlignment.center,children:[
            ChoiceChip(label:const Text('1 oy'),selected:days==30,
              onSelected:(_){setState(()=>days=30);load();}),
            ChoiceChip(label:const Text('1 yil'),selected:days==365,
              onSelected:(_){setState(()=>days=365);load();}),
            DropdownButton<String>(value:channel,
              items:sources.entries.map((e)=>DropdownMenuItem(
                value:e.key,child:Text(e.value))).toList(),
              onChanged:(v){if(v!=null){setState(()=>channel=v);load();}}),
          ]),
          if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
          const SizedBox(height:10),
          Wrap(spacing:9,runSpacing:9,children:[
            metric('Sotilgan kitob',count(s['sold_units'])+' dona',Icons.shopping_bag_outlined),
            metric('Tushum',won(s['revenue']),Icons.payments_outlined),
            metric('Kitob foydasi',won(s['profit']),Icons.trending_up),
            metric('Ombor',count(s['total_stock'])+' dona',Icons.inventory_2_outlined),
            metric('Kam qolgan',count(s['low_stock'])+' xil',Icons.warning_amber),
            metric('Tugagan',count(s['out_of_stock'])+' xil',Icons.remove_shopping_cart),
          ]),
          const SizedBox(height:14),
          if(number(s['unlinked_units'])>0)
            Text(count(s['unlinked_units'])+' sotuv katalogga bog‘lanmagan. '
              'Umumiy tushumda bor, ammo janr hisobida Boshqalar bo‘lib chiqadi.',
              style:const TextStyle(fontSize:12,color:Colors.deepOrange)),
          LayoutBuilder(builder:(context,c){
            final widgets=[
              card('Janrlar bo‘yicha sotuv',bars('genres','category'),icon:Icons.category),
              card('Kanallar bo‘yicha sotuv',bars('channels','source',currency:true),
                icon:Icons.pie_chart_outline),
              card('Savdo grafigi',trend(),icon:Icons.show_chart),
            ];
            return c.maxWidth>900?Row(crossAxisAlignment:CrossAxisAlignment.start,
              children:[for(final w in widgets)Expanded(child:w)]):
              Column(children:widgets);
          }),
          turnover(),
          categoryInvestments(),
          LayoutBuilder(builder:(context,c)=>c.maxWidth>750
            ?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Expanded(child:inventory()),Expanded(child:supplier()),
            ]):Column(children:[inventory(),supplier()])),
          const Padding(padding:EdgeInsets.all(12),
            child:Text('Chegirma va qayta buyurtma faqat admin qarori bilan. '
              'Foyda sotilgan paytdagi tannarxga asoslanadi.',
              style:TextStyle(fontSize:12,color:Colors.black54))),
        ])),
    );
  }
}
class _SalesTrendPainter extends CustomPainter {
  const _SalesTrendPainter(this.values);
  final List<num> values;
  @override
  void paint(Canvas canvas,Size size){
    if(values.isEmpty)return;
    final maximum=math.max<num>(1,values.reduce((a,b)=>math.max(a,b)));
    final grid=Paint()..color=const Color(0xFFE9E5DF)..strokeWidth=1;
    for(var i=1;i<=4;i++){final y=size.height*i/5;
      canvas.drawLine(Offset(0,y),Offset(size.width,y),grid);}
    final path=Path();
    for(var i=0;i<values.length;i++){
      final x=values.length==1?0.0:i*size.width/(values.length-1);
      final y=size.height-10-(values[i]/maximum)*(size.height-24);
      if(i==0){path.moveTo(x,y);}else{path.lineTo(x,y);}
    }
    canvas.drawPath(path,Paint()..color=const Color(0xFF26384D)
      ..strokeWidth=2.5..style=PaintingStyle.stroke);
  }
  @override
  bool shouldRepaint(_SalesTrendPainter old)=>true;
}
class _OfflineItem {
  _OfflineItem(this.book):price=TextEditingController(text:book['price'].toString());
  final Map<String,dynamic> book;
  int quantity=1;
  final TextEditingController price;
  void dispose()=>price.dispose();
}
class _OfflineSalePage extends StatefulWidget{
  const _OfflineSalePage({required this.secret,required this.books});
  final String secret;
  final List<Map<String,dynamic>> books;
  @override
  State<_OfflineSalePage> createState()=>_OfflineSalePageState();
}
class _OfflineSalePageState extends State<_OfflineSalePage>{
  final name=TextEditingController(),phone=TextEditingController(),note=TextEditingController();
  final items=<_OfflineItem>[];
  String channel='instagram';
  String? requestKey;
  bool saving=false;
  int toInt(dynamic v)=>int.tryParse(v.toString().replaceAll(',','').replaceAll(' ',''))??0;
  void edited(){requestKey=null;}
  @override
  void dispose(){
    for(final i in items){i.dispose();}
    name.dispose();phone.dispose();note.dispose();super.dispose();
  }
  Future<void> addBook() async {
    String query='';
    final book=await showDialog<Map<String,dynamic>>(context:context,
      builder:(dialog)=>StatefulBuilder(builder:(ctx,refresh)=>
        AlertDialog(title:const Text('Kitob tanlang'),
          content:SizedBox(width:420,height:400,child:Column(children:[
            TextField(onChanged:(v)=>refresh(()=>query=v.toLowerCase()),
              decoration:const InputDecoration(hintText:'Kitob qidirish...',
                prefixIcon:Icon(Icons.search))),
            Expanded(child:ListView(children:[
              for(final b in widget.books.where((b)=>toInt(b['stock'])>0&&
                b['title'].toString().toLowerCase().contains(query)).take(80))
                ListTile(title:Text(b['title'].toString()),
                  subtitle:Text('Qoldiq: '+b['stock'].toString()),
                  onTap:()=>Navigator.pop(dialog,b)),
            ])),
          ])),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialog),
            child:const Text('Yopish'))],
        )));
    if(!mounted||book==null)return;
    if(items.any((i)=>i.book['id']==book['id'])){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Bu kitob tanlangan')));return;
    }
    setState((){items.add(_OfflineItem(book));edited();});
  }
  Future<void> save() async {
    if(saving)return;
    if(items.isEmpty){ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content:Text('Kitob tanlang')));return;}
    for(final x in items){
      if(x.quantity<=0||x.quantity>toInt(x.book['stock'])||
         toInt(x.price.text)<0||toInt(x.price.text)>100000000){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:Text('Kitob miqdori yoki narx noto‘g‘ri: '+x.book['title'].toString())));
        return;
      }
    }
    requestKey??='offline-'+DateTime.now().microsecondsSinceEpoch.toString();
    setState(()=>saving=true);
    try{
      final response=await Supabase.instance.client.rpc('admin_record_offline_sale',
        params:{
          'p_secret':widget.secret,'p_channel':channel,
          'p_items':[for(final x in items)
            {'book_id':x.book['id'],'quantity':x.quantity,'unit_price':toInt(x.price.text)}],
          'p_customer_name':name.text.trim(),'p_phone':phone.text.trim(),
          'p_note':note.text.trim(),'p_request_key':requestKey,
        });
      if(!mounted)return;
      if(response is! Map || response['order_id']==null){
        throw StateError('Buyurtma tasdiqlanmadi');}
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Sotuv saqlandi, ombor va foyda yangilandi')));
      Navigator.pop(context,true);
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Saqlash xatosi: '+e.toString())));
    }finally{if(mounted)setState(()=>saving=false);}
  }
  @override
  Widget build(BuildContext context){
    final total=items.fold<int>(0,(s,x)=>s+x.quantity*toInt(x.price.text));
    return Scaffold(
      appBar:AppBar(title:const Text('Yangi oflayn sotuv')),
      backgroundColor:const Color(0xFFFFFAF4),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        const Text('Instagram, Telegram, SMS va telefon savdolari. '
          'Ilovadagi buyurtmani bu yerda qayta yozmang.',
          style:TextStyle(color:Colors.black54)),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:channel,
          decoration:const InputDecoration(labelText:'Sotuv kanali',
            border:OutlineInputBorder()),
          items:const [
            DropdownMenuItem(value:'instagram',child:Text('Instagram')),
            DropdownMenuItem(value:'telegram',child:Text('Telegram')),
            DropdownMenuItem(value:'sms',child:Text('SMS')),
            DropdownMenuItem(value:'phone',child:Text('Telefon')),
            DropdownMenuItem(value:'in_person',child:Text('Shaxsan')),
          ],onChanged:(v)=>setState((){channel=v??'instagram';edited();})),
        const SizedBox(height:14),
        OutlinedButton.icon(onPressed:saving?null:addBook,
          icon:const Icon(Icons.add),label:const Text('Kitob qo‘shish')),
        for(final x in items)
          Card(child:Padding(padding:const EdgeInsets.all(12),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Expanded(child:Text(x.book['title'].toString(),
                  style:const TextStyle(fontWeight:FontWeight.bold))),
                IconButton(icon:const Icon(Icons.delete_outline),
                  onPressed:saving?null:()=>setState((){
                    items.remove(x);x.dispose();edited();
                  })),
              ]),
              Text('Omborda '+x.book['stock'].toString()+' dona',
                style:const TextStyle(color:Colors.black54,fontSize:12)),
              Row(children:[
                IconButton(icon:const Icon(Icons.remove_circle_outline),
                  onPressed:saving||x.quantity<=1?null:()=>setState((){
                    x.quantity--;edited();
                  })),
                Text(x.quantity.toString()),
                IconButton(icon:const Icon(Icons.add_circle_outline),
                  onPressed:saving||x.quantity>=toInt(x.book['stock'])?null:()=>setState((){
                    x.quantity++;edited();
                  })),
                Expanded(child:TextField(controller:x.price,
                  keyboardType:TextInputType.number,
                  onChanged:(_)=>setState(edited),
                  decoration:const InputDecoration(labelText:'Bir dona narxi (₩)'))),
              ]),
            ]))),
        const SizedBox(height:14),
        TextField(controller:name,onChanged:(_)=>edited(),
          decoration:const InputDecoration(labelText:'Mijoz ismi (ixtiyoriy)',
            border:OutlineInputBorder())),
        const SizedBox(height:12),
        TextField(controller:phone,onChanged:(_)=>edited(),
          keyboardType:TextInputType.phone,
          decoration:const InputDecoration(labelText:'Telefon (ixtiyoriy)',
            border:OutlineInputBorder())),
        const SizedBox(height:12),
        TextField(controller:note,onChanged:(_)=>edited(),
          maxLines:2,decoration:const InputDecoration(labelText:'Izoh',
            border:OutlineInputBorder())),
        const SizedBox(height:16),
        Text('Jami: ₩'+NumberFormat.decimalPattern('en_US').format(total),
          style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        const Text('Saqlanganda ombor bir marta kamayadi, sotuv va foyda '
          'hisoblanadi. Takroriy bosishdan himoya bor.',
          style:TextStyle(fontSize:12,color:Colors.black54)),
        const SizedBox(height:14),
        FilledButton.icon(onPressed:saving?null:save,
          icon:saving?const SizedBox(height:18,width:18,
            child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save),
          label:const Text('Saqlash')),
      ]),
    );
  }
}


/// Supplier metadata is administered separately from inventory quantities.
class _InventorySupplierPage extends StatefulWidget {
  const _InventorySupplierPage({required this.secret});
  final String secret;
  @override
  State<_InventorySupplierPage> createState()=>_InventorySupplierPageState();
}
class _InventorySupplierPageState extends State<_InventorySupplierPage> {
  List<Map<String,dynamic>> suppliers=[],batches=[];
  bool busy=true;
  String? error;
  Map<String,dynamic> asMap(dynamic v)=>
    v is Map ? Map<String,dynamic>.from(v):<String,dynamic>{};
  List<Map<String,dynamic>> asList(dynamic v)=>v is List
    ?v.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():[];
  @override
  void initState(){super.initState();load();}
  Future<void> load() async {
    setState((){busy=true;error=null;});
    try {
      final result=asMap(await Supabase.instance.client.rpc(
        'admin_sales_inventory_analytics',
        params:{'p_secret':widget.secret,'p_days':30,'p_source':'all'}));
      if(mounted)setState((){
        suppliers=asList(result['supplier_catalog']);
        batches=asList(result['batches']);
      });
    }catch(e){if(mounted)setState(()=>error='Xato: '+e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> editSupplier([Map<String,dynamic>? existing]) async {
    final name=TextEditingController(text:(existing?['name']??'').toString());
    final country=TextEditingController(text:(existing?['country']??'').toString());
    final contact=TextEditingController(text:(existing?['contact']??'').toString());
    final data=await showDialog<List<String>>(context:context,
      builder:(dialog)=>AlertDialog(
        title:Text(existing==null?'Yetkazib beruvchi qo‘shish':'Yetkazib beruvchini tahrirlash'),
        content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:name,decoration:const InputDecoration(
            labelText:'Do‘kon yoki nashriyot nomi')),
          TextField(controller:country,decoration:const InputDecoration(
            labelText:'Davlat (ixtiyoriy)')),
          TextField(controller:contact,decoration:const InputDecoration(
            labelText:'Aloqa (ixtiyoriy)')),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog),
            child:const Text('Bekor')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,
            [name.text.trim(),country.text.trim(),contact.text.trim()]),
            child:const Text('Saqlash')),
        ],
      ));
    name.dispose();country.dispose();contact.dispose();
    if(!mounted||data==null)return;
    if(data[0].length<2){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Yetkazib beruvchi nomini kiriting')));return;
    }
    try {
      await Supabase.instance.client.rpc('admin_manage_inventory_supplier',
        params:{
          'p_secret':widget.secret,'p_action':'save',
          'p_supplier_id':existing?['id'],'p_name':data[0],
          'p_country':data[1],'p_contact':data[2],
        });
      if(mounted)await load();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text('Saqlanmadi: '+e.toString())));}
  }
  Future<void> assign(Map<String,dynamic> batch,String? supplierId) async {
    try{
      await Supabase.instance.client.rpc('admin_manage_inventory_supplier',
        params:{
          'p_secret':widget.secret,'p_action':'assign',
          'p_supplier_id':supplierId,'p_batch_id':batch['id'],
        });
      if(mounted){
        setState(()=>batch['supplier_id']=supplierId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Partiya yetkazib beruvchiga bog‘landi')));
      }
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text('O‘zgartirib bo‘lmadi: '+e.toString())));}
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:const Text('Yetkazib beruvchilar'),
      actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
    floatingActionButton:FloatingActionButton.extended(
      onPressed:()=>editSupplier(),
      icon:const Icon(Icons.add),label:const Text('Yangi yetkazib beruvchi')),
    body:busy?const Center(child:CircularProgressIndicator()):
      ListView(padding:const EdgeInsets.fromLTRB(12,8,12,90),children:[
        if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
        const Padding(padding:EdgeInsets.all(8),child:Text('Yetkazib beruvchilar',
          style:TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
        for(final s in suppliers)
          ListTile(leading:const Icon(Icons.storefront_outlined),
            title:Text(s['name'].toString()),
            subtitle:Text((s['country']??'').toString()),
            trailing:IconButton(icon:const Icon(Icons.edit_outlined),
              onPressed:()=>editSupplier(s))),
        const Padding(padding:EdgeInsets.all(8),
          child:Text('Partiya qatorlariga bog‘lash',
            style:TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
        const Padding(padding:EdgeInsets.all(8),
          child:Text('Har bir kitobning xarid partiyasi uchun yetkazib beruvchini '
            'tanlang. Ombor soni, tannarx yoki eski foyda o‘zgarmaydi.',
            style:TextStyle(fontSize:12,color:Colors.black54))),
        for(final b in batches)
          Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(b['book_title'].toString(),
                style:const TextStyle(fontWeight:FontWeight.bold)),
              Text('Sana: '+b['purchased_at'].toString()+
                ' · '+b['quantity'].toString()+' dona',
                style:const TextStyle(fontSize:12)),
              DropdownButtonFormField<String>(
                value:b['supplier_id'] as String?,
                decoration:const InputDecoration(
                  labelText:'Yetkazib beruvchi',isDense:true),
                items:[
                  const DropdownMenuItem<String>(value:null,
                    child:Text('Ko‘rsatilmagan')),
                  for(final s in suppliers)
                    DropdownMenuItem<String>(value:s['id'].toString(),
                      child:Text(s['name'].toString(),
                        overflow:TextOverflow.ellipsis)),
                ],
                onChanged:(v)=>assign(b,v),
              ),
            ]))),
      ]),
  );
}
