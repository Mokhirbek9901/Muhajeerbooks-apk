
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'uzbek_customer_style.dart';

/// Returns the value of the CURRENT batch selection. For unchanged
/// multi-line historical records, preserve the exact sum of original
/// quantity × cost rather than rounding a weighted-average unit cost.
int batchBookCostValue({
  required int quantity,
  required int unitCost,
  int previousQuantity = 0,
  int? historicalLineValue,
  bool changedUnitCost = false,
}) {
  if (quantity <= 0) return 0;
  if (!changedUnitCost && historicalLineValue != null) {
    if (quantity == previousQuantity) return historicalLineValue;
    // Delta pricing is an estimate for previously mixed-cost lines.
    final adjusted = historicalLineValue +
      (quantity - previousQuantity) * unitCost;
    return adjusted < 0 ? 0 : adjusted;
  }
  return quantity * unitCost;
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
  bool _onlySelected = false;
  bool _syncStock = false;
  bool _submitting = false;

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
    for (final book in _selected.values) { book.dispose(); }
    _selected.clear();
    _selectedTransportIds.clear();
    _originalTransportIds.clear();
    _previousQty.clear();
    _existingSnapshot=null;
    _existingRevision=null;
    _existingLoading=false;
    _onlySelected=false;
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
        _onlySelected=true;
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

  void _showAllBooksForAdding() {
    setState(() {
      _onlySelected=false;
      _search.clear();
    });
    _searchFocus.requestFocus();
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
    if (_submitting || _existingLoading) return;
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
    final text = isOld
      ? 'Eski partiyada $nBooks nomdagi kitob tahrirlanadi. '
        '$corrections. '
        'Ombor qoldig‘i va moliya qayta hisoblanmaydi. '
        'Eski yozuvlar tahrirdan oldin audit tarixida saqlanadi. '
        'Yangi transport: ${newTransportIds.length} ta. '
        'Xarajat takrorlanmaydi.'
      : 'Yangi partiyaga $nBooks nomdagi, jami $nQty dona kitob qo‘shiladi. '
        '$transportNote '
        '${_syncStock ? 'OMBOR QOLDIG‘I HAM ORTADI VA JORIY TANNARX YANGILANADI.' : 'Ombor va moliyaga ta’sir qilmaydi.'} '
        'Moliya xarajati avtomatik yaratilmaydi.';
    final confirmed = await showDialog<bool>(
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
    final id = raw['id'].toString();
    final chosen = _selected[id];
    final selected = chosen != null;
    final currentCost = (raw['cost_price'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: Column(children: [
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          value: selected,
          onChanged: _submitting ? null : (v) => _pick(raw, v ?? false),
          title: Text((raw['title'] ?? 'Kitob').toString(),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('Bazadagi tannarx: ${_money(currentCost)}'
            ' • Qoldiq: ${raw['stock'] ?? 0} dona',
            style: const TextStyle(fontSize: 11.5)),
        ),
        if (chosen != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(children: [
              Row(children: [
                Expanded(child: TextField(
                  controller: chosen.quantity,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _mode=='old'
                      ? 'Partiyada jami dona' : 'Kelgan dona',
                    isDense: true,
                    border: const OutlineInputBorder()),
                )),
                const SizedBox(width: 8),
                IconButton(
                  tooltip:'1 dona kamaytirish',
                  onPressed:_submitting || chosen.qty<=(_mode=='old'?0:1)
                    ?null:()=>setState(()=>
                      chosen.quantity.text='${chosen.qty-1}'),
                  icon:const Icon(Icons.remove_circle_outline)),
                IconButton(
                  tooltip:'1 dona ko‘paytirish',
                  onPressed:_submitting || chosen.qty>=10000
                    ?null:()=>setState(()=>
                      chosen.quantity.text='${chosen.qty+1}'),
                  icon:const Icon(Icons.add_circle_outline)),
              ]),
              const SizedBox(height:8),
              Row(children:[
                Expanded(child:TextField(
                  controller:chosen.cost,
                  enabled:!_submitting,
                  keyboardType:TextInputType.number,
                  inputFormatters:[FilteringTextInputFormatter.digitsOnly],
                  onChanged:(_)=>setState(() =>
                    chosen.changedCost=chosen.unitCost!=chosen.originalUnitCost),
                  decoration:const InputDecoration(
                    labelText:'Bir dona tannarx ₩',
                    isDense:true,border:OutlineInputBorder()),
                )),
                IconButton(
                  tooltip:_mode=='old'
                    ? 'Partiyada oldin yozilgan tannarxni qaytarish'
                    : 'Katalogdagi tannarxni qaytarish',
                  onPressed:_submitting ? null : (){
                    chosen.cost.text=chosen.originalUnitCost.toString();
                    setState(()=>chosen.changedCost=false);
                  },
                  icon:const Icon(Icons.restore_outlined)),
              ]),
              if(_mode=='old' && _previousQty.containsKey(id))
                Padding(padding:const EdgeInsets.only(top:8),
                  child:Align(alignment:Alignment.centerLeft,
                    child:Text(
                      'Avval: ${_previousQty[id]} ta  →  '
                      'Hozir: ${chosen.qty} ta  '
                      '(farq: ${chosen.qty-(_previousQty[id]??0)} ta)',
                      style:const TextStyle(
                        fontWeight:FontWeight.w800,fontSize:12)))),
              Align(alignment: Alignment.centerRight,
                child: Text('Partiya qiymati: ${_money(chosen.qty * (chosen.unitCost < 0 ? 0 : chosen.unitCost))}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12))),
            ]),
          ),
      ]),
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
        final search = _search.text.trim().toLowerCase();
        final visible = books.where((b) =>
          (b['title'] ?? '').toString().toLowerCase().contains(search)
          && (search.isNotEmpty || !_onlySelected ||
             _selected.containsKey(b['id'].toString())))
          .toList()
          ..sort((a,b) {
            final aChosen=_selected.containsKey(a['id'].toString())?0:1;
            final bChosen=_selected.containsKey(b['id'].toString())?0:1;
            if(aChosen!=bChosen)return aChosen.compareTo(bChosen);
            return (a['title']??'').toString().compareTo(
              (b['title']??'').toString());
          });
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
                _sectionTitle('2. Transport xarajatlarini tanlang'),
                const Text(
                  'Moliya bo‘limida saqlangan transport xarajatlari. '
                  'Tegishli xarajatlarni belgilang: boshqa partiyaga '
                  'biriktirilgan transport qayta tanlanmaydi.',
                  style: TextStyle(fontSize: 12,
                    color: UzbekCustomerColors.textMuted, height: 1.35),
                ),
                const SizedBox(height: 8),
                if (transports.isEmpty)
                  const Card(child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Text('Moliyada transport xarajatlari topilmadi.')))
                else
                  for (final transport in transports)
                    Builder(builder: (ctx) {
                      final expenseId = (transport['id'] ?? '').toString();
                      final alreadyLinked = transport['linked_to'] != null;
                      final transportAmount =
                        (transport['amount'] as num?)?.toInt() ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: _selectedTransportIds.contains(expenseId),
                          onChanged: _submitting || alreadyLinked ? null
                            : (value) => setState(() {
                              if (value ?? false) {
                                _selectedTransportIds.add(expenseId);
                              } else {
                                _selectedTransportIds.remove(expenseId);
                              }
                            }),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            '${_money(transportAmount)} • '
                            '${(transport['note'] ?? 'Transport').toString()}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${transport['expense_date'] ?? ''} • '
                            '${alreadyLinked
                                ? 'Biriktirilgan: ${transport['linked_to']}'
                                : 'Partiyaga biriktirilmagan'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    }),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Tanlangan transport: ${_money(transportTotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w900,
                        color: UzbekCustomerColors.navy),
                    ),
                  ),
                ),
                _sectionTitle('3. Katalogdan kitoblarni belgilang'),
                if(_mode=='old')...[
                  SwitchListTile.adaptive(
                    contentPadding:EdgeInsets.zero,
                    value:_onlySelected,
                    onChanged:(v)=>setState(()=>_onlySelected=v),
                    title:const Text('Faqat shu partiyadagi kitoblar'),
                    subtitle:const Text('Qidiruvda boshqa kitoblar ham chiqadi.')),
                  OutlinedButton.icon(
                    onPressed:_submitting || _existingLoading
                      ? null:_showAllBooksForAdding,
                    icon:const Icon(Icons.add_circle_outline),
                    label:const Text('Yana kitob qo‘shish / barcha kitoblar'),
                  ),
                ],
                const Text(
                  'Eski partiyaga faqat transport bog‘lash uchun '
                  'kitob tanlash shart emas.',
                  style: TextStyle(fontSize: 12,
                    color: UzbekCustomerColors.textMuted),
                ),
                TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Kitob nomini qidiring...',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder()),
                ),
                const SizedBox(height: 7),
                Text('${_selected.length} ta kitob belgilandi • '
                  '${visible.length} ta katalog natijasi',
                  style: const TextStyle(fontWeight: FontWeight.w700,
                    color: UzbekCustomerColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                for (final book in visible) _bookCard(book),
              ]),
          ))),
          SafeArea(top: false, child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE4E9E5)))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                    Text('${_selected.length} nomdagi kitob',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12)),
                    if(_mode=='old' && _existingRevision!=null)...[
                      Text(financeLinked
                        ? 'Moliyadagi xarajat: ${_money(financeAmount ?? 0)}'
                        : 'Moliyadagi xarajat biriktirilmagan',
                        style:const TextStyle(
                          fontWeight:FontWeight.w900,fontSize:13)),
                      Text('Kitoblarning jami tannarxi: ${_money(sum)}',
                        style:const TextStyle(
                          fontWeight:FontWeight.w600,fontSize:11.5)),
                      if(difference!=null)
                        Text('Farq: ${_money(difference.abs())}',
                          style:const TextStyle(
                            fontWeight:FontWeight.w800,fontSize:12)),
                    ] else ...[
                      Text('Kitoblar ${_money(sum)} + '
                          'transport ${_money(transportTotal)}',
                        style:const TextStyle(
                          fontWeight:FontWeight.w700,fontSize:11.5)),
                      Text('Jami ${_money(sum + transportTotal)}',
                        style:const TextStyle(
                          fontWeight:FontWeight.w900,fontSize:17,
                          color:UzbekCustomerColors.navy)),
                    ],
                  ],
                )),
                FilledButton.icon(
                  onPressed: _submitting || _existingLoading ? null : _save,
                  icon: _submitting ? const SizedBox(width: 16,height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                  label: const Text('Partiyani saqlash'),
                ),
              ]),
            ))),
          ),
        ]);
      },
    ),
  );
}
