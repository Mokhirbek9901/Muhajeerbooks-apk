
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'uzbek_customer_style.dart';

/// One original batch line in newest-first order. This matches the
/// backend's quantity correction algorithm: adjust the latest line first.
class BatchCostLot {
  const BatchCostLot(this.quantity,this.unitCost);
  final int quantity;
  final int unitCost;
}

/// Calculate the selected books' actual procurement value, including when
/// a title was purchased at several distinct historical unit costs.
int batchBookCostValue({
  required int quantity,
  required int unitCost,
  int previousQuantity = 0,
  int? historicalLineValue,
  List<BatchCostLot> historicalLots = const [],
  bool changedUnitCost = false,
}) {
  if (quantity <= 0) return 0;
  if (changedUnitCost) return quantity*unitCost;
  if (historicalLineValue != null) {
    if (quantity == previousQuantity) return historicalLineValue;
    if (historicalLots.isNotEmpty) {
      if (quantity > previousQuantity) {
        return historicalLineValue +
          (quantity-previousQuantity)*historicalLots.first.unitCost;
      }
      var leftToRemove=previousQuantity-quantity;
      var value=historicalLineValue;
      for(final lot in historicalLots) {
        if(leftToRemove==0)break;
        final removed=leftToRemove<lot.quantity
          ?leftToRemove:lot.quantity;
        value-=removed*lot.unitCost;
        leftToRemove-=removed;
      }
      return value<0?0:value;
    }
    // Older server responses without cost_lots: retain a safe fallback.
    final adjusted=historicalLineValue +
      (quantity-previousQuantity)*unitCost;
    return adjusted<0?0:adjusted;
  }
  return quantity*unitCost;
}

/// Search handles Uzbek apostrophe/hyphen spellings and ranks already
/// selected titles first so the operator can re-find and adjust them quickly.
List<Map<String,dynamic>> searchBatchCatalogBooks(
  List<Map<String,dynamic>> books, String search, Set<String> selectedIds) {
  String normalize(String raw) => raw.toLowerCase()
    .replaceAll(RegExp(r"['ʻ‘’ʼ`´]"),'')
    .replaceAll(RegExp(r'[-_.,/]+'),' ')
    .replaceAll(RegExp(r'\s+'),' ')
    .trim();
  final words=normalize(search).split(' ')
    .where((w)=>w.isNotEmpty).toList();
  final results=books.where((book) {
    final title=normalize((book['title']??'').toString());
    return words.every(title.contains);
  }).toList();
  results.sort((a,b) {
    final x=selectedIds.contains(a['id'].toString())?0:1;
    final y=selectedIds.contains(b['id'].toString())?0:1;
    if(x!=y)return x.compareTo(y);
    return (a['title']??'').toString().compareTo(
      (b['title']??'').toString());
  });
  return results;
}

class _SelectedBatchBook {
  _SelectedBatchBook(Map<String,dynamic> raw,{
    int initialQuantity = 1, int? historicalUnitCost})
    : id = raw['id'].toString(),
      title = (raw['title'] ?? 'Kitob').toString(),
      catalogCost = (raw['cost_price'] as num?)?.toInt() ?? 0,
      originalUnitCost = historicalUnitCost ??
        ((raw['cost_price'] as num?)?.toInt() ?? 0),
      quantity = TextEditingController(text: '$initialQuantity'),
      cost = TextEditingController(
        text: (historicalUnitCost ??
          ((raw['cost_price'] as num?)?.toInt() ?? 0)).toString());
  final String id;
  final String title;
  final int catalogCost;
  final int originalUnitCost;
  final TextEditingController quantity;
  final TextEditingController cost;
  bool changedCost = false;
  void dispose() { quantity.dispose(); cost.dispose(); }
  int get qty => int.tryParse(quantity.text) ?? 0;
  int get unitCost => int.tryParse(cost.text) ?? -1;
}

class WebBatchMultiAddPage extends StatefulWidget {
  const WebBatchMultiAddPage({
    super.key, required this.secret, this.initialBatch,
  });
  final String secret;
  /// Directly open an old historical batch without navigating the dropdown.
  /// Examples: import:6, finance_group:<uuid>, group:<uuid>.
  final String? initialBatch;
  @override
  State<WebBatchMultiAddPage> createState() => _WebBatchMultiAddPageState();
}

class _WebBatchMultiAddPageState extends State<WebBatchMultiAddPage> {
  late final Future<Map<String,dynamic>> _data;
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final Map<String,_SelectedBatchBook> _selected = {};
  final Set<String> _selectedTransportIds = <String>{};
  DateTime _date = DateTime.now();
  String _mode = 'new';
  String? _existing;
  String? _existingRevision;
  Map<String,dynamic>? _existingSnapshot;
  final Map<String,int> _previousQty = {};
  final Set<String> _originalTransportIds = <String>{};
  int _loadGeneration = 0;
  bool _existingLoading = false;
  bool _syncStock = false;
  bool _submitting = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _data = Supabase.instance.client.rpc('admin_web_batch_picker_data',
      params: {'p_secret': widget.secret})
      .then((value) => value is Map
        ? Map<String,dynamic>.from(value)
        : <String,dynamic>{});
    if(widget.initialBatch!=null) {
      _mode='old';
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final data=await _data;
          if(mounted) await _openOldBatch(widget.initialBatch,data);
        } catch (_) { /* FutureBuilder presents the loading error. */ }
      });
    }
  }

  @override
  void dispose() {
    for (final item in _selected.values) { item.dispose(); }
    _title.dispose(); _note.dispose(); _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Map<String,dynamic>> _list(dynamic raw) => raw is List
    ? raw.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList()
    : [];

  String _money(num v) => '₩${NumberFormat('#,###').format(v.round())}';

  void _resetDraft() {
    _loadGeneration++;
    _search.clear();
    for (final book in _selected.values) { book.dispose(); }
    _selected.clear();
    _selectedTransportIds.clear();
    _originalTransportIds.clear();
    _previousQty.clear();
    _existingSnapshot=null;
    _existingRevision=null;
    _existingLoading=false;
  }

  Future<void> _openOldBatch(
      String? selection, Map<String,dynamic> data) async {
    setState(() {
      _resetDraft();
      _existing=selection;
    });
    if(selection==null) return;
    final parts=selection.split(':');
    if(parts.length!=2 || parts.last.isEmpty) {
      _message('Partiya ID noto‘g‘ri');
      return;
    }
    final kind=parts.first=='import'?'old_import'
      :parts.first=='group'?'old_group'
      :parts.first=='finance_group'?'old_finance_group':'';
    if(kind.isEmpty) {
      _message('Partiya turi noto‘g‘ri');
      return;
    }
    final gen=++_loadGeneration;
    setState(() => _existingLoading=true);
    try {
      final raw=await Supabase.instance.client.rpc(
        'admin_web_batch_existing_data', params:{
          'p_secret':widget.secret,'p_scope':kind,'p_id':parts.last,
        });
      if(!mounted || gen!=_loadGeneration || _existing!=selection) return;
      final result=raw is Map ? Map<String,dynamic>.from(raw)
        : <String,dynamic>{};
      final catalog={
        for(final book in _list(data['books']))
          book['id'].toString():book,
      };
      final prefill=<String,_SelectedBatchBook>{};
      final baseline=<String,int>{};
      for(final line in _list(result['items'])) {
        final id=line['book_id'].toString();
        final book=catalog[id];
        if(book==null) continue; // Deleted books are never fabricated.
        final qty=(line['quantity'] as num?)?.toInt()??0;
        if(qty<=0) continue;
        final unit=(line['unit_cost'] as num?)?.toInt()??0;
        prefill[id]=_SelectedBatchBook(book,
          initialQuantity:qty,historicalUnitCost:unit);
        baseline[id]=qty;
      }
      final linked=((result['transport_ids'] as List?)??const [])
        .map((e)=>e.toString()).toSet();
      setState(() {
        _existingRevision=(result['revision']??'').toString();
        _existingSnapshot=result;
        _selected.addAll(prefill);
        _previousQty.addAll(baseline);
        _originalTransportIds.addAll(linked);
        _selectedTransportIds.addAll(linked);
        // Show the previously entered books first; searching still lets an
        // admin select any other book.
        _existingLoading=false;
      });
    } catch(error) {
      if(!mounted || gen!=_loadGeneration) return;
      setState(() { _existingLoading=false; _existingRevision=null; });
      _message('Partiya tarixini ochib bo‘lmadi: $error');
    }
  }

  void _pick(Map<String,dynamic> book, bool select) {
    final id = book['id'].toString();
    setState(() {
      if (select) {
        _selected.putIfAbsent(id, () {
          final historic=_list(_existingSnapshot?['items'])
            .where((r)=>r['book_id'].toString()==id).firstOrNull;
          return _SelectedBatchBook(book,
            initialQuantity:_previousQty[id]??1,
            historicalUnitCost:(historic?['unit_cost'] as num?)?.toInt());
        });
      } else {
        _selected.remove(id)?.dispose();
      }
    });
  }


  Future<void> _removeSelectedBook(String id) async {
    if(_submitting || _confirming)return;
    if(_mode=='old' && _previousQty.containsKey(id)) {
      final agreed=await showDialog<bool>(
        context:context,
        builder:(dialog)=>AlertDialog(
          title:const Text('Kitobni partiyadan olib tashlash'),
          content:const Text('Bu kitobning ushbu eski partiyadagi soni 0 '
            'bo‘ladi. Ombor va moliya o‘zgarmaydi. '
            'Saqlashda yana tasdiqlaysiz.'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialog,false),
              child:const Text('Qoldirish')),
            FilledButton(onPressed:()=>Navigator.pop(dialog,true),
              child:const Text('Olib tashlash')),
          ],
        ),
      );
      if(!mounted||agreed!=true)return;
    }
    setState(()=>_selected.remove(id)?.dispose());
  }

  Future<void> _openBookPicker(List<Map<String,dynamic>> books) async {
    if(_submitting||_confirming||_existingLoading)return;
    _search.clear();
    await showModalBottomSheet<void>(
      context:context,
      isScrollControlled:true,
      useSafeArea:true,
      showDragHandle:true,
      backgroundColor:UzbekCustomerColors.background,
      builder:(sheet)=>StatefulBuilder(builder:(sheet,refresh) {
        final q=_search.text.trim();
        final matching=searchBatchCatalogBooks(
          books,q,_selected.keys.toSet());
        return FractionallySizedBox(heightFactor:0.9,child:Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(16,5,16,10),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                const Text('Kitob tanlash',style:TextStyle(fontSize:22,
                  fontWeight:FontWeight.w900,color:UzbekCustomerColors.navy)),
                Text('${_selected.length} nom tanlangan',
                  style:const TextStyle(fontSize:12,
                    color:UzbekCustomerColors.textMuted)),
                const SizedBox(height:12),
                TextField(
                  controller:_search,focusNode:_searchFocus,autofocus:true,
                  onChanged:(_)=>refresh((){}),
                  decoration:InputDecoration(
                    hintText:'Kitob nomini qidiring...',
                    prefixIcon:const Icon(Icons.search_rounded),
                    suffixIcon:q.isEmpty?null:IconButton(
                      onPressed:(){_search.clear();refresh((){});},
                      icon:const Icon(Icons.close),
                      tooltip:'Qidiruvni tozalash'),
                    filled:true,fillColor:Colors.white,
                    border:OutlineInputBorder(
                      borderRadius:BorderRadius.circular(14))),
                ),
                const SizedBox(height:6),
                Text('${matching.length} ta natija',
                  style:const TextStyle(fontSize:12,
                    color:UzbekCustomerColors.textMuted)),
              ])),
          Expanded(child:matching.isEmpty
            ?const Center(child:Text('Bunday kitob topilmadi.'))
            :ListView.builder(
              keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount:matching.length,
              itemBuilder:(ctx,i) {
                final book=matching[i];
                final id=book['id'].toString();
                final chosen=_selected[id];
                return Padding(
                  padding:const EdgeInsets.symmetric(horizontal:12,vertical:3),
                  child:Material(color:Colors.white,
                    borderRadius:BorderRadius.circular(12),
                    child:ListTile(
                      contentPadding:const EdgeInsets.symmetric(
                        horizontal:12,vertical:4),
                      title:Text((book['title']??'Kitob').toString(),
                        maxLines:2,overflow:TextOverflow.ellipsis,
                        style:const TextStyle(fontWeight:FontWeight.w800)),
                      subtitle:Text(chosen!=null
                        ?'Tanlangan: ${chosen.qty} dona'
                        :'Tannarx: ${_money((book['cost_price'] as num?)?.toInt()??0)}'
                         ' • Qoldiq: ${book['stock']??0}',
                        style:const TextStyle(fontSize:11.5)),
                      trailing:chosen!=null
                        ?const Tooltip(
                          message:'Tanlangan — sonini asosiy sahifada tahrirlang',
                          child:Icon(Icons.check_circle_rounded,
                            color:UzbekCustomerColors.navy,size:29))
                        :IconButton.filled(
                          tooltip:'Partiyaga qo‘shish',
                          icon:const Icon(Icons.add),
                          onPressed:(){_pick(book,true);refresh((){});}),
                    )));},
            )),
          SafeArea(top:false,child:Padding(
            padding:const EdgeInsets.fromLTRB(16,8,16,14),
            child:SizedBox(width:double.infinity,
              child:FilledButton.icon(
                onPressed:()=>Navigator.pop(sheet),
                icon:const Icon(Icons.check_circle_outline),
                label:Text('${_selected.length} ta tanlandi • Tayyor'))))),
        ]));
      }),
    );
    if(mounted)setState((){});
  }

  int _bookValue() {
    final prior={
      for (final item in _list(_existingSnapshot?['items']))
        item['book_id'].toString():item,
    };
    return _selected.values.fold<int>(0,(sum,line) {
      final original=prior[line.id];
      return sum+batchBookCostValue(
        quantity:line.qty,
        unitCost:line.unitCost<0?0:line.unitCost,
        previousQuantity:_previousQty[line.id]??0,
        historicalLineValue:(original?['line_value'] as num?)?.toInt(),
        historicalLots:_list(original?['cost_lots']).map((entry)=>
          BatchCostLot(
            (entry['quantity'] as num?)?.toInt()??0,
            (entry['unit_cost'] as num?)?.toInt()??0,
          )).toList(),
        changedUnitCost:line.changedCost,
      );
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDate: _date);
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (_submitting || _existingLoading || _confirming) return;
    if (_mode == 'old' && (_existing==null || _existingRevision==null)) {
      _message('Avval eski partiyani tanlab, undagi kitoblar yuklanishini kuting.');
      return;
    }
    if (_selected.isEmpty && _selectedTransportIds.isEmpty &&
        !(_mode=='old' && _previousQty.isNotEmpty)) {
      _message('Kamida bitta kitob yoki transport xarajatini belgilang.');
      return;
    }
    if (_mode == 'new' && _selected.isEmpty) {
      _message('Yangi partiyaga kamida bitta kitob belgilang.');
      return;
    }
    if (_mode == 'new' && _title.text.trim().isEmpty) {
      _message('Yangi partiyaga nom yozing.');
      return;
    }
    if (_mode == 'old' && _existing == null) {
      _message('Eski partiyani tanlang.');
      return;
    }
    final list = <Map<String,dynamic>>[];
    for (final row in _selected.values) {
      if (row.qty < (_mode=='old'?0:1) || row.qty > 10000 ||
          row.unitCost < 0 || row.unitCost > 100000000) {
        _message('${row.title}: dona soni yoki tannarx noto‘g‘ri.');
        return;
      }
      final original=_previousQty[row.id]??0;
      if(_mode=='old' && row.qty==original && !row.changedCost) continue;
      list.add({
        'book_id': row.id,
        'quantity': row.qty,
        if(_mode=='old' || row.changedCost) 'unit_cost': row.unitCost,
        'edited_cost': row.changedCost,
      });
    }
    if(_mode=='old') {
      for(final old in _previousQty.entries) {
        if(!_selected.containsKey(old.key)) {
          final previous=_list(_existingSnapshot?['items'])
            .where((x)=>x['book_id'].toString()==old.key).firstOrNull;
          list.add({
            'book_id':old.key,'quantity':0,
            'unit_cost':(previous?['unit_cost'] as num?)?.toInt()??0,
            'edited_cost':false,
          });
        }
      }
    }
    final newTransportIds=_selectedTransportIds
      .difference(_originalTransportIds).toList();
    if(_mode=='old' && list.isEmpty && newTransportIds.isEmpty) {
      _message('Hozircha hech narsa o‘zgarmagan.');
      return;
    }
    final nBooks = list.length;
    final nQty = _selected.values.fold<int>(0, (s, x) => s + x.qty);
    final isOld = _mode == 'old';
    final data = await _data;
    final transportRows = _list(data['transports']);
    final transportSum = transportRows
        .where((t) => _selectedTransportIds.contains(t['id'].toString()))
        .fold<int>(0, (sum, t) => sum + ((t['amount'] as num?)?.toInt() ?? 0));
    final transportNote = '${_selectedTransportIds.length} ta transport: '
        '${_money(transportSum)}. Bu xarajatlar moliyada avval hisoblangan, '
        'ikkinchi marta xarajat yozilmaydi.';
    final corrections=list.map((row) {
      final id=row['book_id'].toString();
      final prev=_previousQty[id]??0;
      final next=(row['quantity'] as num?)?.toInt()??0;
      final difference=next-prev;
      return '$prev → $next ($difference dona)';
    }).take(8).join('; ');
    final oldExpense=(_existingSnapshot?['finance_purchase_total'] as num?)?.toInt();
    final expenseLinked=_existingSnapshot?['finance_linked']==true &&
      oldExpense!=null;
    final costAfterEdit=_bookValue();
    final summary=expenseLinked
      ? 'Moliyadagi xarajat: ${_money(oldExpense ?? 0)}. '
        'Kitoblar tannarxi: ${_money(costAfterEdit)}. '
        'Farq: ${_money(((oldExpense ?? 0)-costAfterEdit).abs())}. '
      : 'Moliyaga bog‘langan xarajat topilmadi. ';
    final text = isOld
      ? 'Eski partiyada $nBooks nomdagi kitob tahrirlanadi. '
        '$corrections. $summary'
        'Ombor qoldig‘i va moliya qayta hisoblanmaydi. '
        'Eski yozuvlar tahrirdan oldin audit tarixida saqlanadi. '
        'Yangi transport: ${newTransportIds.length} ta. '
        'Xarajat takrorlanmaydi.'
      : 'Yangi partiyaga $nBooks nomdagi, jami $nQty dona kitob qo‘shiladi. '
        '$transportNote '
        '${_syncStock ? 'OMBOR QOLDIG‘I HAM ORTADI VA JORIY TANNARX YANGILANADI.' : 'Ombor va moliyaga ta’sir qilmaydi.'} '
        'Moliya xarajati avtomatik yaratilmaydi.';
    setState(()=>_confirming=true);
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Partiyani tasdiqlash'),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
            child: const Text('Orqaga')),
          FilledButton(onPressed: () => Navigator.pop(c, true),
            child: const Text('Tasdiqlash')),
        ],
      ),
    );
    } finally {
      _confirming=false;
      if(mounted)setState((){});
    }
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      if(isOld) {
        final parts=(_existing??'').split(':');
        final oldKind=parts.first=='import'?'old_import'
          :parts.first=='group'?'old_group':'old_finance_group';
        await Supabase.instance.client.rpc('admin_web_batch_edit_existing',
          params:{
            'p_secret':widget.secret,
            'p_scope':oldKind,
            'p_id':parts.skip(1).join(':'),
            'p_expected_revision':_existingRevision,
            'p_items':list,
            'p_transport_ids':newTransportIds,
          });
      } else {
        await Supabase.instance.client.rpc('admin_web_bulk_batch_save',
          params: {
            'p_secret': widget.secret,
            'p_data': {
              'mode':'new',
              'title': _title.text.trim(),
              'date': DateFormat('yyyy-MM-dd').format(_date),
              'note': _note.text.trim(),
              'apply_to_inventory': _syncStock,
              'transport_ids': _selectedTransportIds.toList(),
              'items': list,
            },
          });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      _message('Saqlashda xato: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)));
  }

  Widget _sectionTitle(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
    child: Text(s, style: const TextStyle(
      fontSize: 16, fontWeight: FontWeight.w900,
      color: UzbekCustomerColors.navy)));

  Widget _bookCard(Map<String,dynamic> raw) {
    final id=raw['id'].toString();
    final item=_selected[id];
    if(item==null)return const SizedBox.shrink();
    final before=_previousQty[id];
    final changed=(before!=null && item.qty!=before) || item.changedCost;
    final historic=_list(_existingSnapshot?['items'])
      .where((r)=>r['book_id'].toString()==id).firstOrNull;
    final worth=batchBookCostValue(
      quantity:item.qty,
      unitCost:item.unitCost<0?0:item.unitCost,
      previousQuantity:before??0,
      historicalLineValue:(historic?['line_value'] as num?)?.toInt(),
      historicalLots:_list(historic?['cost_lots']).map((lot)=>BatchCostLot(
        (lot['quantity'] as num?)?.toInt()??0,
        (lot['unit_cost'] as num?)?.toInt()??0)).toList(),
      changedUnitCost:item.changedCost,
    );
    return Card(
      key:ValueKey('selected-book-$id'),
      margin:const EdgeInsets.only(bottom:9),
      color:Colors.white,
      shape:RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(16),
        side:BorderSide(
          color:changed?UzbekCustomerColors.navy:const Color(0xFFE2E8F0),
          width:changed?1.5:1)),
      child:Padding(padding:const EdgeInsets.all(13),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(item.title,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:15,
                    fontWeight:FontWeight.w900,
                    color:UzbekCustomerColors.navy)),
                const SizedBox(height:3),
                Text(before!=null
                  ?'Avval: $before dona  •  Hozir: ${item.qty} dona'
                  :'Yangi qo‘shilgan kitob',
                  style:const TextStyle(fontSize:12,
                    color:UzbekCustomerColors.textMuted)),
              ])),
            if(changed)
              const Padding(padding:EdgeInsets.only(right:6),
                child:Icon(Icons.edit_note_rounded,
                  color:UzbekCustomerColors.navy)),
            IconButton(
              icon:const Icon(Icons.close_rounded),
              tooltip:'Partiyadan olib tashlash',
              onPressed:_submitting?null:()=>_removeSelectedBook(id),
              color:UzbekCustomerColors.textMuted),
          ]),
          const SizedBox(height:12),
          Row(children:[
            const Text('Dona soni',style:TextStyle(
              fontWeight:FontWeight.w800,fontSize:13)),
            const Spacer(),
            IconButton.filledTonal(
              tooltip:'Bittaga kamaytirish',
              onPressed:_submitting || item.qty<=(_mode=='old'?0:1)
                ?null:()=>setState(()=>
                  item.quantity.text='${item.qty-1}'),
              icon:const Icon(Icons.remove,size:19)),
            const SizedBox(width:6),
            SizedBox(width:66,child:TextField(
              controller:item.quantity,
              enabled:!_submitting,
              textAlign:TextAlign.center,
              keyboardType:TextInputType.number,
              inputFormatters:[FilteringTextInputFormatter.digitsOnly],
              onChanged:(_)=>setState((){}),
              style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900),
              decoration:InputDecoration(
                isDense:true,contentPadding:const EdgeInsets.symmetric(
                  vertical:12,horizontal:6),
                border:OutlineInputBorder(
                  borderRadius:BorderRadius.circular(10))),
            )),
            const SizedBox(width:6),
            IconButton.filledTonal(
              tooltip:'Bittaga ko‘paytirish',
              onPressed:_submitting || item.qty>=10000
                ?null:()=>setState(()=>
                  item.quantity.text='${item.qty+1}'),
              icon:const Icon(Icons.add,size:19)),
          ]),
          if(before!=null && item.qty!=before)
            Padding(padding:const EdgeInsets.only(top:5),
              child:Text('Farq: ${item.qty-before>0?'+':''}${item.qty-before} dona',
                style:const TextStyle(fontSize:12,
                  fontWeight:FontWeight.w800,
                  color:UzbekCustomerColors.navy))),
          const SizedBox(height:10),
          Row(children:[
            Expanded(child:TextField(
              controller:item.cost,
              enabled:!_submitting,
              keyboardType:TextInputType.number,
              inputFormatters:[FilteringTextInputFormatter.digitsOnly],
              onChanged:(_)=>setState(()=>
                item.changedCost=item.unitCost!=item.originalUnitCost),
              decoration:InputDecoration(
                labelText:'1 dona tannarxi',
                prefixText:'₩ ',
                isDense:true,
                border:OutlineInputBorder(
                  borderRadius:BorderRadius.circular(10))),
            )),
            IconButton(
              tooltip:'Avvalgi tannarxni qaytarish',
              icon:const Icon(Icons.restore_rounded),
              onPressed:_submitting?null:(){
                item.cost.text=item.originalUnitCost.toString();
                setState(()=>item.changedCost=false);
              }),
          ]),
          const SizedBox(height:11),
          Row(children:[
            const Text('Shu kitoblarning jami tannarxi',
              style:TextStyle(fontSize:11,
                color:UzbekCustomerColors.textMuted)),
            const Spacer(),
            Text(_money(worth),style:const TextStyle(
              fontSize:14,fontWeight:FontWeight.w900,
              color:UzbekCustomerColors.navy)),
          ]),
        ])),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(
      title: const Text('Partiyaga kitob qo‘shish'),
      backgroundColor: UzbekCustomerColors.background),
    body: FutureBuilder<Map<String,dynamic>>(
      future: _data,
      builder: (ctx, snap) {
        if (snap.hasError) return Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Katalogni yuklab bo‘lmadi: ${snap.error}')));
        if (!snap.hasData) return const Center(
          child: CircularProgressIndicator());
        final data = snap.data!;
        final books = _list(data['books']);
        final imported = _list(data['historical']);
        final groups = _list(data['groups']);
        final transports = _list(data['transports']);
        final transportTotal = transports
          .where((t) => _selectedTransportIds.contains(t['id'].toString()))
          .fold<int>(0, (sum, t) => sum + ((t['amount'] as num?)?.toInt() ?? 0));
        final listOfExisting = <DropdownMenuItem<String>>[
          for (final row in imported) DropdownMenuItem(
            value: (row['source']=='finance_group'?'finance_group':'import')+
              ':${row['id']}',
            child: Text(
              '${row['purchase_date']} • ${row['title']}',
              overflow: TextOverflow.ellipsis)),
          for (final row in groups) DropdownMenuItem(
            value: 'group:${row['id']}',
            child: Text(
              '${row['batch_date']} • ${row['title']}',
              overflow: TextOverflow.ellipsis)),
        ];
        final selectedBooks=books
          .where((b)=>_selected.containsKey(b['id'].toString())).toList();
        final totalQuantity=_selected.values.fold<int>(0,
          (count,item)=>count+item.qty);
        final sum = _bookValue();
        final financeAmount =
          (_existingSnapshot?['finance_purchase_total'] as num?)?.toInt();
        final financeLinked =
          _existingSnapshot?['finance_linked']==true &&
          financeAmount!=null;
        final difference=financeLinked?financeAmount-sum:null;
        final selectedCount=_selected.values.fold<int>(0,
          (total,item)=>total+item.qty);
        final mixedAdjusted=_list(_existingSnapshot?['items']).any((line) {
          final id=line['book_id'].toString();
          final chosen=_selected[id];
          return (line['multiple_lines'] as num? ?? 0)>1 &&
            _list(line['cost_lots']).isEmpty &&
            chosen!=null && chosen.qty!=(_previousQty[id]??0);
        });
        return Column(children: [
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              children: [
                _sectionTitle('1. Partiya turi'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'new', label: Text('Yangi partiya'),
                      icon: Icon(Icons.add_box_outlined)),
                    ButtonSegment(value: 'old', label: Text('Eski partiya'),
                      icon: Icon(Icons.history_rounded)),
                  ],
                  selected: {_mode}, onSelectionChanged: _submitting
                    ? null : (x) => setState(() {
                      _resetDraft();
                      _existing=null;
                      _mode = x.first;
                      _syncStock = false;
                    })),
                const SizedBox(height: 12),
                if (_mode == 'new') ...[
                  TextField(controller: _title, enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: 'Partiya nomi',
                      hintText: 'Masalan: 2026 oktabr — Toshkent',
                      border: OutlineInputBorder())),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Kelgan sana: ${DateFormat('dd.MM.yyyy').format(_date)}')),
                  const SizedBox(height: 9),
                  TextField(controller: _note, enabled: !_submitting,
                    decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)',
                      border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _syncStock,
                    onChanged: _submitting ? null : (v) => setState(() => _syncStock=v),
                    title: const Text('Omborga ham qo‘shish'),
                    subtitle: const Text(
                      'O‘chiq holatda faqat partiya tarixi yoziladi. '
                      'Yoqilganda yangi dona soni omborga qo‘shilib, '
                      'joriy tannarx yangilanadi.'),
                  ),
                ] else ...[
                  if (listOfExisting.isEmpty)
                    const Text('Avvalgi partiyalar topilmadi.')
                  else DropdownButtonFormField<String>(
                    value: _existing,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Eski partiyani tanlang',
                      border: OutlineInputBorder()),
                    items: listOfExisting,
                    onChanged: _submitting ? null : (v) => _openOldBatch(v,data)),
                  if(_existingLoading)
                    const Padding(padding:EdgeInsets.symmetric(vertical:12),
                      child:Row(children:[
                        SizedBox(width:20,height:20,
                          child:CircularProgressIndicator(strokeWidth:2)),
                        SizedBox(width:12),
                        Expanded(child:Text('Eski partiyadagi kitoblar yuklanmoqda...')),
                      ]))
                  else if(_existingRevision!=null)
                    Padding(padding:const EdgeInsets.symmetric(vertical:9),
                      child:Text(
                        'Avvalgi partiyadagi ${_previousQty.length} nomdagi '
                        'kitob va ularning dona soni yuklandi. '
                        'Sonni ustiga bosib to‘g‘rilang. 2 → 3 degani '
                        'yangi 3 ta qo‘shish emas, jami 3 ta bo‘ladi.',
                        style:const TextStyle(
                          fontWeight:FontWeight.w800,
                          color:UzbekCustomerColors.navy))),
                  if(_existingRevision!=null)...[
                    const SizedBox(height:12),
                    Card(
                      child:Padding(
                        padding:const EdgeInsets.all(16),
                        child:Column(
                          crossAxisAlignment:CrossAxisAlignment.start,
                          children:[
                            const Row(children:[
                              Icon(Icons.account_balance_wallet_outlined,size:20),
                              SizedBox(width:8),
                              Expanded(child:Text('Partiya xarajati va kitoblar hisobi',
                                style:TextStyle(fontSize:15,fontWeight:FontWeight.w900))),
                            ]),
                            const SizedBox(height:12),
                            if(financeLinked)...[
                              const Text('Moliyada qayd etilgan partiya xarajati',
                                style:TextStyle(fontSize:12,
                                  color:UzbekCustomerColors.textMuted)),
                              Text(_money(financeAmount ?? 0),
                                style:const TextStyle(fontSize:25,
                                  fontWeight:FontWeight.w900,
                                  color:UzbekCustomerColors.navy)),
                            ] else ...[
                              const Text('Moliyada bu partiyaga bog‘langan '
                                'kitob xarajati topilmadi.',
                                style:TextStyle(fontSize:13,
                                  fontWeight:FontWeight.w700)),
                              const Text('Bu partiya uchun moliya xarajatini '
                                'o‘zimizcha taxmin qilib qo‘shmaymiz.',
                                style:TextStyle(fontSize:12,
                                  color:UzbekCustomerColors.textMuted)),
                            ],
                            const Divider(height:24),
                            const Text('Shu partiyada belgilangan '
                              'kitoblarning jami tannarxi',
                              style:TextStyle(fontSize:12,
                                color:UzbekCustomerColors.textMuted)),
                            Text(_money(sum),
                              style:const TextStyle(fontSize:17,
                                fontWeight:FontWeight.w800)),
                            Text('${_selected.length} nom • $selectedCount dona',
                              style:const TextStyle(fontSize:11,
                                color:UzbekCustomerColors.textMuted)),
                            if(difference!=null)...[
                              const SizedBox(height:10),
                              Text(
                                'Farq: ${_money(difference.abs())}'
                                '${difference>0?" • Moliyada ko‘proq":difference<0?" • Kitoblar ko‘proq":" • Hisob teng"}',
                                style:const TextStyle(
                                  fontSize:14,fontWeight:FontWeight.w800)),
                              Text(difference>0
                                ? 'Xarajat kitoblar yig‘indisidan ko‘p. '
                                  'Kitob yoki tannarx qolib ketganini tekshiring.'
                                : difference<0
                                ? 'Kitoblar yig‘indisi xarajatdan oshgan. '
                                  'Dona soni yoki tannarx ortiqcha emasligini tekshiring.'
                                : 'Partiyadagi kitoblar tannarxi moliya '
                                  'xarajatiga teng.',
                                style:const TextStyle(fontSize:12,
                                  color:UzbekCustomerColors.textMuted)),
                            ],
                            if(mixedAdjusted)
                              const Padding(
                                padding:EdgeInsets.only(top:6),
                                child:Text('Bir xil kitob turli tannarxlarda '
                                  'bir necha marta yozilgan: son o‘zgarsa '
                                  'farq taxminiy bo‘lishi mumkin.',
                                  style:TextStyle(fontSize:11,
                                    color:UzbekCustomerColors.textMuted))),
                            const SizedBox(height:9),
                            const Text('Transport xarajatlari alohida '
                              'hisoblanadi va kitoblarning shu tannarx '
                              'jami summasiga qayta qo‘shilmaydi.',
                              style:TextStyle(fontSize:11,
                                color:UzbekCustomerColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Eski partiyaga kitoblar faqat tarixiy qayd sifatida bog‘lanadi. '
                    'Ombor ko‘paymaydi va moliyaga qayta xarajat yozilmaydi. '
                    'Oldingi yozuvlar partiyadagi o‘z tannarxi va soni '
                    'bilan yuklanadi. Tahrir tarixga yoziladi.',
                    style: TextStyle(fontSize: 12,
                      color: UzbekCustomerColors.textMuted)),
                ],
                _sectionTitle('2. Partiyadagi kitoblar'),
                Card(color:Colors.white,child:Padding(
                  padding:const EdgeInsets.all(14),
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(
                        '${_selected.length} nomdagi kitob • $totalQuantity dona',
                        style:const TextStyle(fontWeight:FontWeight.w900,
                          fontSize:16,color:UzbekCustomerColors.navy)),
                      const SizedBox(height:4),
                      const Text('Pastda tanlangan kitoblarning soni '
                        'va tannarxini alohida tahrirlang.',
                        style:TextStyle(fontSize:12,
                          color:UzbekCustomerColors.textMuted)),
                      const SizedBox(height:12),
                      SizedBox(width:double.infinity,
                        child:FilledButton.icon(
                          onPressed:_submitting || _existingLoading
                            ?null:()=>_openBookPicker(books),
                          icon:const Icon(Icons.library_add_outlined),
                          label:Text(_selected.isEmpty
                            ?'Kitoblarni tanlash'
                            :'Yana kitob qo‘shish'),
                        )),
                    ],
                  ),
                )),
                const SizedBox(height:10),
                if(selectedBooks.isEmpty)
                  const Card(child:Padding(
                    padding:EdgeInsets.all(20),
                    child:Column(children:[
                      Icon(Icons.menu_book_outlined,size:32,
                        color:UzbekCustomerColors.textMuted),
                      SizedBox(height:8),
                      Text('Hali kitob belgilanmagan',
                        style:TextStyle(fontWeight:FontWeight.w800)),
                      SizedBox(height:5),
                      Text('Yuqoridagi tugma orqali kitob nomini '
                        'qidirib qo‘shing.'),
                    ])))
                else
                  for(final book in selectedBooks) _bookCard(book),
                const SizedBox(height:14),
                Card(color:Colors.white,child:ExpansionTile(
                  key:const ValueKey('batch-transport'),
                  initiallyExpanded:false,
                  leading:const Icon(Icons.local_shipping_outlined,
                    color:UzbekCustomerColors.navy),
                  title:const Text('3. Transport xarajatlari',
                    style:TextStyle(fontWeight:FontWeight.w900)),
                  subtitle:Text('${_selectedTransportIds.length} ta tanlangan'
                    ' • ${_money(transportTotal)}',
                    style:const TextStyle(fontSize:12)),
                  children:[
                    const Padding(
                      padding:EdgeInsets.fromLTRB(14,4,14,10),
                      child:Text('Moliyada avval yozilgan transport '
                        'xarajatlarini bog‘lash mumkin. '
                        'Bu yerda qayta xarajat yaratilmaydi.',
                        style:TextStyle(fontSize:12,
                          color:UzbekCustomerColors.textMuted))),
                    if(transports.isEmpty)
                      const Padding(
                        padding:EdgeInsets.all(14),
                        child:Text('Transport xarajati topilmadi.'))
                    else
                      for(final transport in transports)
                        Builder(builder:(ctx) {
                          final id=(transport['id']??'').toString();
                          final linked=transport['linked_to']!=null;
                          final amount=(transport['amount'] as num?)?.toInt()??0;
                          return CheckboxListTile(
                            dense:true,
                            value:_selectedTransportIds.contains(id),
                            onChanged:_submitting || linked?null:(v)=>setState((){
                              if(v??false){_selectedTransportIds.add(id);}
                              else{_selectedTransportIds.remove(id);}
                            }),
                            controlAffinity:ListTileControlAffinity.leading,
                            title:Text('${_money(amount)} • '
                              '${transport['note']??'Transport'}',
                              style:const TextStyle(
                                fontWeight:FontWeight.w800)),
                            subtitle:Text(linked
                              ?'Biriktirilgan: ${transport['linked_to']}'
                              :'Mavjud, biriktirilmagan',
                              style:const TextStyle(fontSize:11)),
                          );
                        }),
                    const SizedBox(height:8),
                  ],
                )),
                const SizedBox(height:18),
              ]),
          ))),
          SafeArea(top: false, child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE4E9E5)))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child:LayoutBuilder(builder:(context,size) {
                final narrow=size.maxWidth<520;
                final summary=Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  mainAxisSize:MainAxisSize.min,
                  children:[
                    Text('${_selected.length} nom • $totalQuantity dona',
                      style:const TextStyle(
                        fontWeight:FontWeight.w900,fontSize:13,
                        color:UzbekCustomerColors.navy)),
                    if(_mode=='old' && _existingRevision!=null)...[
                      Text(financeLinked
                        ?'Moliyadagi xarajat: ${_money(financeAmount??0)}'
                        :'Moliyada xarajat bog‘lanmagan',
                        style:const TextStyle(fontSize:12,
                          fontWeight:FontWeight.w800)),
                      Text('Kitoblar tannarxi: ${_money(sum)}',
                        style:const TextStyle(fontSize:12)),
                      if(difference!=null)
                        Text('Farq: ${_money(difference.abs())}',
                          style:const TextStyle(fontWeight:FontWeight.w800,
                            fontSize:12)),
                    ] else
                      Text('Kitoblar: ${_money(sum)}'
                        ' • Transport: ${_money(transportTotal)}',
                        style:const TextStyle(fontSize:12)),
                  ],
                );
                final action=FilledButton.icon(
                  onPressed:_submitting || _existingLoading ||
                    _confirming?null:_save,
                  icon:_submitting
                    ?const SizedBox(width:16,height:16,
                      child:CircularProgressIndicator(strokeWidth:2))
                    :const Icon(Icons.save_outlined),
                  label:const Text('Partiyani saqlash'),
                );
                return narrow
                  ?Column(crossAxisAlignment:CrossAxisAlignment.stretch,
                    children:[summary,const SizedBox(height:8),action])
                  :Row(children:[
                    Expanded(child:summary),
                    const SizedBox(width:16),
                    action,
                  ]);
              }),
            ))),
          ),
        ]);
      },
    ),
  );
}
