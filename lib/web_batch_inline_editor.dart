import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'uzbek_customer_style.dart';

/// An existing batch is always edited in-place; nothing is written before Save.
/// History stays readable with no stepper or removal controls outside edit mode.
class WebBatchInlineEditor extends StatefulWidget {
  const WebBatchInlineEditor({
    super.key,
    required this.secret,
    required this.kind,
    required this.batchKey,
    required this.lines,
    required this.onSaved,
  });
  final String secret;
  final String kind;
  final String batchKey;
  final List<Map<String,dynamic>> lines;
  final VoidCallback onSaved;

  @override
  State<WebBatchInlineEditor> createState()=>_WebBatchInlineEditorState();
}

class _WebBatchInlineEditorState extends State<WebBatchInlineEditor> {
  static const ink=Color(0xFF203A36);
  static const teal=Color(0xFF116858);
  static const edge=Color(0xFFE7D9BE);
  bool editing=false,saving=false,loadingBooks=false;
  Map<int,int> counts={};
  final Map<String,Map<String,dynamic>> added={};
  final TextEditingController _bookSearch=TextEditingController();

  // Search affects only visible rows. Counts and unsaved edits are retained
  // for all books, including those hidden by the current filter.
  String _normalizeTitle(String value)=>value.toLowerCase()
    .replaceAll(RegExp(r"[ʻʼ’‘`´]"), "'").trim();

  bool _matchesBook(Map<String,dynamic> book,String term)=>
    _normalizeTitle((book['title']??'').toString()).contains(term);

  @override
  void initState(){
    super.initState();
    _reset();
  }

  @override
  void dispose(){
    _bookSearch.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WebBatchInlineEditor old){
    super.didUpdateWidget(old);
    if(!editing && !saving) _reset();
  }

  int _n(dynamic value)=>value is num?value.round():int.tryParse(
    (value??'').toString())??0;
  String _won(int n)=>'₩'+NumberFormat('#,###','en_US').format(n);
  void _reset(){
    counts={
      for(final line in widget.lines) _n(line['id']):_n(line['quantity'])
    };
    added.clear();
  }

  bool get changed=>widget.lines.any((line)=>
    counts[_n(line['id'])]!=_n(line['quantity'])) || added.isNotEmpty;

  void _cancel(){
    setState((){
      editing=false;
      _reset();
    });
  }

  Widget _bookCover(Map<String,dynamic> book){
    final src=(book['image_url']??'').toString();
    return ClipRRect(borderRadius:BorderRadius.circular(9),
      child:SizedBox(width:46,height:64,
        child:src.startsWith('https://')
          ?Image.network(src,fit:BoxFit.cover,
            errorBuilder:(_,__,___)=>_fallbackCover())
          :_fallbackCover()));
  }
  Widget _fallbackCover()=>Container(
    alignment:Alignment.center,color:const Color(0xFFE7F2EE),
    child:const Icon(Icons.auto_stories_rounded,color:teal,size:23));

  Future<bool> _askRemove(String title) async{
    final answer=await showDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Partiyadan olib tashlash'),
        content:Text(title+' bu partiyaga kelmagan deb belgilansinmi? '
          'Bu amal faqat Saqlash bosilganda bajariladi.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Yo‘q')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Ha, olib tashlash')),
        ]));
    return answer??false;
  }

  Widget _numberControl(int value,VoidCallback decrease,VoidCallback increase,
      {bool removable=false}){
    return Row(mainAxisSize:MainAxisSize.min,children:[
      _circle(Icons.remove_rounded,decrease,
        inactive:value<=1 && !removable),
      const SizedBox(width:9),
      SizedBox(width:28,child:Text(value.toString(),textAlign:TextAlign.center,
        style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17,color:ink))),
      const SizedBox(width:9),
      _circle(Icons.add_rounded,increase,filled:true),
    ]);
  }
  Widget _circle(IconData icon,VoidCallback callback,
      {bool filled=false,bool inactive=false})=>InkWell(
    onTap:saving||inactive?null:callback,
    borderRadius:BorderRadius.circular(25),
    child:Container(width:36,height:36,
      decoration:BoxDecoration(
        color:filled?const Color(0xFFCDE8E3):Colors.white,
        shape:BoxShape.circle,
        border:filled?null:Border.all(color:edge)),
      child:Icon(icon,size:21,color:ink)),
  );

  Widget _recordedRow(Map<String,dynamic> line){
    final id=_n(line['id']);
    final value=counts[id]??_n(line['quantity']);
    final removed=value==0;
    return Padding(padding:const EdgeInsets.symmetric(vertical:5),
      child:Container(padding:const EdgeInsets.fromLTRB(9,8,7,8),
        decoration:BoxDecoration(
          color:editing?Colors.white:Colors.transparent,
          borderRadius:BorderRadius.circular(12),
          border:editing?Border.all(color:edge):null),
        child:Row(children:[
          _bookCover(line),
          const SizedBox(width:9),
          Expanded(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text((line['title']??'Kitob').toString(),
                maxLines:2,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:removed?Colors.red:ink,
                  fontWeight:FontWeight.w800,fontSize:13,
                  decoration:removed?TextDecoration.lineThrough:null)),
              const SizedBox(height:4),
              Text(removed?'Bu partiyadan olib tashlanadi':
                (editing?'1 dona '+_won(_n(line['unit_cost'])):
                value.toString()+' dona · 1 dona '+
                _won(_n(line['unit_cost']))),
                maxLines:2,style:TextStyle(
                  fontSize:11.5,color:removed?Colors.red:
                  const Color(0xFF657471))),
            ])),
          if(editing) ...[
            const SizedBox(width:5),
            if(removed) TextButton(onPressed:saving?null:()=>setState(()=>
                counts[id]=_n(line['quantity'])),
              child:const Text('Qaytarish',style:TextStyle(fontSize:11)))
            else _numberControl(value,
              ()=>setState(()=>counts[id]=(value-1).clamp(1,10000)),
              ()=>setState(()=>counts[id]=(value+1).clamp(1,10000))),
            PopupMenuButton<String>(
              tooltip:'Kitob amallari',
              icon:const Icon(Icons.more_horiz_rounded,color:ink),
              onSelected:(v)async{
                if(v!='remove')return;
                if(await _askRemove((line['title']??'Kitob').toString()) &&
                    mounted) setState(()=>counts[id]=0);
              },
              itemBuilder:(_)=>const [
                PopupMenuItem(value:'remove',child:Row(children:[
                  Icon(Icons.delete_outline_rounded,color:Colors.red),
                  SizedBox(width:6),
                  Text('Bu partiyadan olib tashlash',
                    style:TextStyle(color:Colors.red,fontSize:12)),
                ])),
              ]),
          ],
        ])));
  }

  Widget _addedRow(Map<String,dynamic> row){
    final id=row['id'].toString(),value=_n(row['quantity']);
    return Padding(padding:const EdgeInsets.symmetric(vertical:5),
      child:Container(padding:const EdgeInsets.all(8),
        decoration:BoxDecoration(color:const Color(0xFFE9F6EF),
          border:Border.all(color:const Color(0xFFB6E0CE)),
          borderRadius:BorderRadius.circular(12)),
        child:Row(children:[
          _bookCover(row),const SizedBox(width:9),
          Expanded(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text((row['title']??'Kitob').toString(),maxLines:2,
                overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:ink,
                  fontWeight:FontWeight.w800,fontSize:13)),
              Text('Yangi · 1 dona '+_won(_n(row['unit_cost'])),
                style:const TextStyle(fontSize:11.5,color:teal)),
            ])),
          _numberControl(value,
            ()=>setState(()=>row['quantity']=(value-1).clamp(1,10000)),
            ()=>setState(()=>row['quantity']=(value+1).clamp(1,10000))),
          PopupMenuButton<String>(
            tooltip:'Tanlangan kitob',
            onSelected:(_)=>setState(()=>added.remove(id)),
            itemBuilder:(_)=>const [
              PopupMenuItem(value:'remove',child:Text('Tanlovdan olib tashlash')),
            ]),
        ])));
  }

  Future<void> _pickBook() async{
    if(saving)return;
    if(!editing)setState(()=>editing=true);
    setState(()=>loadingBooks=true);
    List<Map<String,dynamic>> options=[];
    try{
      final data=await Supabase.instance.client.rpc('admin_web_batch_picker_data',
        params:{'p_secret':widget.secret});
      if(data is Map && data['books'] is List) {
        options=(data['books'] as List).whereType<Map>()
          .map((x)=>Map<String,dynamic>.from(x)).toList();
      }
    }catch(error){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Katalogni yuklashda xatolik: '+error.toString())));
      return;
    }finally{
      if(mounted)setState(()=>loadingBooks=false);
    }
    if(!mounted)return;
    final chosen=await showModalBottomSheet<Map<String,dynamic>>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(context)=>_BatchBookPicker(
        catalog:options,
        excluded:{
          ...widget.lines.map((line)=>line['book_id'].toString()),
          ...added.keys,
        },
      ),
    );
    if(!mounted || chosen==null)return;
    setState(()=>added[chosen['id'].toString()]={
      ...chosen,
      'quantity':1,
      'unit_cost':_n(chosen['cost_price']),
      'image_url':chosen['image_url']??chosen['thumbnail_url'],
    });
  }

  Future<void> _save() async{
    if(saving || !changed){
      if(!changed && editing)_cancel();
      return;
    }
    final removed=widget.lines.where((line)=>
      counts[_n(line['id'])]==0).length;
    if(removed>0){
      final allowed=await showDialog<bool>(context:context,
        builder:(ctx)=>AlertDialog(
          title:const Text('O‘zgarishlarni saqlash'),
          content:Text(removed.toString()+
            ' ta kitob partiya tarkibidan olib tashlanadi. Davom etilsinmi?'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),
              child:const Text('Orqaga')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),
              child:const Text('Saqlash')),
          ]),
      );
      if(allowed!=true || !mounted)return;
    }
    setState(()=>saving=true);
    try{
      final changes=<Map<String,dynamic>>[
        for(final line in widget.lines)
          if(counts[_n(line['id'])]!=_n(line['quantity']))
            {
              'id':_n(line['id']),
              'expected_quantity':_n(line['quantity']),
              'quantity':counts[_n(line['id'])],
            },
      ];
      final additions=<Map<String,dynamic>>[
        for(final b in added.values)
          {'book_id':b['id'],'quantity':b['quantity'],
           'unit_cost':b['unit_cost']},
      ];
      await Supabase.instance.client.rpc('admin_web_batch_apply_edits',
        params:{
          'p_secret':widget.secret,
          'p_kind':widget.kind,
          'p_key':widget.batchKey,
          'p_changes':changes,
          'p_additions':additions,
        });
      if(!mounted)return;
      setState((){
        editing=false;
        // Server response will replace old quantities via onSaved().
      });
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Partiya saqlandi. Takroriy kirim qo‘shilmadi.')));
    }catch(error){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Saqlashda xatolik: '+error.toString())));
    }finally{
      if(mounted)setState(()=>saving=false);
    }
  }

  @override
  Widget build(BuildContext context){
    final count=widget.lines.fold<int>(0,(sum,line)=>sum+
      (editing?(counts[_n(line['id'])]??_n(line['quantity'])):
      _n(line['quantity'])))+
      (editing?added.values.fold<int>(0,(sum,b)=>sum+_n(b['quantity'])):0);
    final term=_normalizeTitle(_bookSearch.text);
    final filtered=widget.lines.where((book)=>_matchesBook(book,term)).toList();
    final filteredAdded=added.values.where(
      (book)=>_matchesBook(book,term)).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const Text('Partiyadagi kitoblar',style:TextStyle(
              color:ink,fontSize:16,fontWeight:FontWeight.w900)),
            Text(widget.lines.length.toString()+' xil · '+count.toString()+
                ' dona'+(editing?' (tahrir)':''),
              style:const TextStyle(fontSize:12,color:Color(0xFF617370))),
          ])),
        if(!editing)
          OutlinedButton.icon(
            onPressed:saving?null:()=>setState(()=>editing=true),
            icon:const Icon(Icons.edit_outlined,size:16),
            label:const Text('Tahrirlash'),
          )
        else const Text('Tahrirlash rejimi',
          style:TextStyle(color:teal,fontSize:11,fontWeight:FontWeight.w800)),
      ]),
      const SizedBox(height:10),
      TextField(
        key:const ValueKey('batch-book-search'),
        controller:_bookSearch,
        textInputAction:TextInputAction.search,
        onChanged:(_)=>setState((){}),
        decoration:InputDecoration(
          hintText:'Shu partiyadagi kitobni qidiring...',
          prefixIcon:const Icon(Icons.search_rounded),
          suffixIcon:term.isNotEmpty
            ?IconButton(
              tooltip:'Qidiruvni tozalash',
              icon:const Icon(Icons.close_rounded),
              onPressed:(){
                _bookSearch.clear();
                setState((){});
              })
            :null,
          isDense:true,
          border:OutlineInputBorder(
            borderRadius:BorderRadius.circular(12))),
      ),
      if(term.isNotEmpty)
        Padding(padding:const EdgeInsets.only(top:7),
          child:Text('Topildi: ${filtered.length+(editing?filteredAdded.length:0)} ta',
            style:const TextStyle(fontSize:11.5,
              color:Color(0xFF617370)))),
      const SizedBox(height:8),
      if(widget.lines.isEmpty && added.isEmpty)
        const Padding(padding:EdgeInsets.symmetric(vertical:10),
          child:Text('Bu partiyaga hozircha kitob kiritilmagan.'))
      else if(filtered.isEmpty && (!editing||filteredAdded.isEmpty))
        const Padding(padding:EdgeInsets.symmetric(vertical:12),
          child:Text('Bu partiyada qidiruvga mos kitob topilmadi.',
            style:TextStyle(color:Color(0xFF617370))))
      else ...[
        for(final line in filtered)_recordedRow(line),
        if(editing) for(final row in filteredAdded)_addedRow(row),
      ],
      const SizedBox(height:9),
      // Deliberately below the final book, not a separate new-batch action.
      OutlinedButton.icon(onPressed:saving||loadingBooks?null:_pickBook,
        icon:loadingBooks
          ?const SizedBox(width:16,height:16,
              child:CircularProgressIndicator(strokeWidth:2))
          :const Icon(Icons.add_circle_outline_rounded),
        label:const Text('Kitob qo‘shish')),
      if(editing) ...[
        const SizedBox(height:9),
        Row(children:[
          Expanded(child:OutlinedButton(onPressed:saving?_noop:_cancel,
            child:const Text('Bekor qilish'))),
          const SizedBox(width:9),
          Expanded(child:FilledButton.icon(
            onPressed:saving?null:_save,
            icon:saving
              ?const SizedBox(width:15,height:15,
                child:CircularProgressIndicator(strokeWidth:2))
              :const Icon(Icons.check_rounded),
            label:const Text('Saqlash'),
          )),
        ]),
      ],
    ]);
  }
  static void _noop(){}
}

class _BatchBookPicker extends StatefulWidget{
  const _BatchBookPicker({required this.catalog,required this.excluded});
  final List<Map<String,dynamic>> catalog;
  final Set<String> excluded;
  @override State<_BatchBookPicker> createState()=>_BatchBookPickerState();
}
class _BatchBookPickerState extends State<_BatchBookPicker>{
  String query='';
  @override Widget build(BuildContext context){
    final visible=widget.catalog.where((book)=>
      (book['title']??'').toString().toLowerCase().contains(query.toLowerCase())
      && !widget.excluded.contains(book['id'].toString())).toList();
    return SafeArea(child:FractionallySizedBox(heightFactor:.85,
      child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(17,7,17,9),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Partiyaga kitob qo‘shish',
              style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
            const SizedBox(height:6),
            TextField(autofocus:true,
              decoration:const InputDecoration(
                hintText:'Kitob nomini qidiring...',
                prefixIcon:Icon(Icons.search_rounded)),
              onChanged:(s)=>setState(()=>query=s)),
          ])),
        Expanded(child:ListView.builder(
          itemCount:visible.length,
          itemBuilder:(context,i){
            final b=visible[i];
            return ListTile(
              leading:const Icon(Icons.auto_stories_rounded,color:Colors.teal),
              title:Text((b['title']??'Kitob').toString(),maxLines:2),
              subtitle:Text('Tan narxi: ₩'+
                NumberFormat('#,###').format(b['cost_price']??0)),
              trailing:const Icon(Icons.add_circle_outline_rounded),
              onTap:()=>Navigator.pop(context,b),
            );
          },
        )),
      ]),
    ));
  }
}
