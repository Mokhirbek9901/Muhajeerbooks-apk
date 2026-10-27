
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'uzbek_customer_style.dart';
import 'admin_batch_finance_math.dart';

/// Store an independent cost snapshot for each newly saved batch line.
/// The server must use this amount, rather than re-reading a potentially
/// changed catalog price between selecting and saving the book.
@visibleForTesting
Map<String,dynamic> batchLineSnapshotPayload({
  required String bookId,
  required int quantity,
  required int unitCost,
  required bool manuallyEdited,
}) => {
  'book_id':bookId,
  'quantity':quantity,
  'unit_cost':unitCost,
  'edited_cost':manuallyEdited,
};

class _SelectedBatchBook {
  _SelectedBatchBook(Map<String,dynamic> raw)
    : id = raw['id'].toString(),
      title = (raw['title'] ?? 'Kitob').toString(),
      catalogCost = (raw['cost_price'] as num?)?.toInt() ?? 0,
      quantity = TextEditingController(text: '1'),
      cost = TextEditingController(
        text: ((raw['cost_price'] as num?)?.toInt() ?? 0).toString());
  final String id;
  final String title;
  final int catalogCost;
  final TextEditingController quantity;
  final TextEditingController cost;
  bool changedCost = false;
  void dispose() { quantity.dispose(); cost.dispose(); }
  int get qty => int.tryParse(quantity.text) ?? 0;
  int get unitCost => int.tryParse(cost.text) ?? -1;
}

class WebBatchMultiAddPage extends StatefulWidget {
  const WebBatchMultiAddPage({
    super.key,
    required this.secret,
    this.initialFinanceGroupId,
  });
  final String secret;
  /// Existing reconciled finance group to edit, never a new inventory intake.
  final String? initialFinanceGroupId;
  @override
  State<WebBatchMultiAddPage> createState() => _WebBatchMultiAddPageState();
}

class _WebBatchMultiAddPageState extends State<WebBatchMultiAddPage> {
  late final Future<Map<String,dynamic>> _data;
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _search = TextEditingController();
  final Map<String,_SelectedBatchBook> _selected = {};
  final Set<String> _selectedTransportIds = <String>{};
  final Set<String> _selectedFinanceExpenseIds = <String>{};
  DateTime _date = DateTime.now();
  String _mode = 'new';
  String? _existing;
  bool _syncStock = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFinanceGroupId != null) {
      _mode = 'old';
      _existing = 'finance_group:${widget.initialFinanceGroupId}';
      _syncStock = false;
    }
    _data = Future.wait<dynamic>([
      Supabase.instance.client.rpc('admin_web_batch_picker_data',
        params: {'p_secret': widget.secret}),
      Supabase.instance.client.rpc('admin_web_batch_overview',
        params: {'p_secret': widget.secret}),
      Supabase.instance.client.rpc('admin_web_batch_line_list',
        params: {'p_secret': widget.secret}),
    ]).then((values) {
      final data = values[0] is Map
          ? Map<String,dynamic>.from(values[0] as Map)
          : <String,dynamic>{};
      final overview = values[1] is Map
          ? Map<String,dynamic>.from(values[1] as Map)
          : <String,dynamic>{};
      final purchases = _list(overview['purchases']);
      // Finance groups appear once, not as five individual purchase options.
      // Map each group to its real 09.09 receipt for legacy-safe inserts.
      final historical = _list(data['historical']);
      data['historical'] = [
        for (final row in historical)
          if (row['source'] == 'finance_group')
            () {
              final members = purchases.where((p) =>
                p['finance_group_id']?.toString() == row['id'].toString())
                .toList()..sort((a,b) =>
                  (a['id'] as num).toInt().compareTo((b['id'] as num).toInt()));
              final dated = members.where((m) =>
                m['purchase_date']?.toString() == row['purchase_date']?.toString());
              return {
                ...row,
                'representative_import_id': dated.isNotEmpty
                    ? dated.first['id'] : (members.isNotEmpty ? members.first['id'] : null),
                'member_import_ids': members.map((m) => m['id'].toString()).toList(),
              };
            }()
          else row,
      ];
      // Already reconciled historical finance-group entries belong only to
      // their existing batch. Do not show their obsolete individual names as
      // candidate expenses for a second, new batch.
      final groupedImports = purchases.where((row) =>
        row['finance_group_id'] != null).toList();
      final importIds = groupedImports.map((row) =>
        (row['id'] ?? '').toString()).toSet();
      final hiddenExpenseIds = <String>{
        ...groupedImports.map((row) =>
          (row['finance_expense_id'] ?? '').toString()),
        ..._list(data['transports']).where((row) =>
          importIds.contains((row['batch_import_id'] ?? '').toString()))
          .map((row) => (row['id'] ?? '').toString()),
      };
      data['finance_options'] = _list(data['finance_options'])
          .where((row) => !hiddenExpenseIds.contains(
            (row['id'] ?? '').toString())).toList();
      data['saved_lines'] = values[2] is List ? values[2] : [];
      return data;
    });
  }

  @override
  void dispose() {
    for (final item in _selected.values) { item.dispose(); }
    _title.dispose(); _note.dispose(); _search.dispose();
    super.dispose();
  }

  List<Map<String,dynamic>> _list(dynamic raw) => raw is List
    ? raw.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList()
    : [];

  String _money(num v) => '₩${NumberFormat('#,###').format(v.round())}';

  void _pick(Map<String,dynamic> book, bool select) {
    final id = book['id'].toString();
    setState(() {
      if (select) {
        _selected.putIfAbsent(id, () => _SelectedBatchBook(book));
      } else {
        _selected.remove(id)?.dispose();
      }
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
    if (_submitting) return;
    if (_selected.isEmpty && _selectedTransportIds.isEmpty &&
        _selectedFinanceExpenseIds.isEmpty) {
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
      if (row.qty < 1 || row.qty > 10000 || row.unitCost < 0 ||
          row.unitCost > 100000000) {
        _message('${row.title}: dona soni yoki tannarx noto‘g‘ri.');
        return;
      }
      // Always submit the selected amount, even if catalog-prefilled.
      // It belongs to THIS batch and must never retroactively follow the
      // changing global books.cost_price of future deliveries.
      list.add(batchLineSnapshotPayload(
        bookId:row.id,
        quantity:row.qty,
        unitCost:row.unitCost,
        manuallyEdited:row.changedCost,
      ));
    }
    final nBooks = list.length;
    final nQty = _selected.values.fold<int>(0, (s, x) => s + x.qty);
    final isOld = _mode == 'old';
    final data = await _data;
    final selectedKey = (_existing ?? '').split(':');
    final selectedFinanceGroup = selectedKey.firstOrNull == 'finance_group'
        ? _list(data['historical']).where((row) =>
            row['source'] == 'finance_group' &&
            row['id'].toString() == selectedKey.skip(1).join(':'))
        : <Map<String,dynamic>>[];
    final targetImportId = selectedFinanceGroup.isNotEmpty
        ? selectedFinanceGroup.first['representative_import_id']
        : null;
    if (_mode == 'old' && selectedKey.firstOrNull == 'finance_group' &&
        targetImportId == null) {
      _message('Birlashgan partiyaning asosiy xaridi topilmadi.');
      return;
    }
    final transportRows = _list(data['transports']);
    final financeRows = _list(data['finance_options']);
    final chosenFinance = financeRows.where((e)=>
      _selectedFinanceExpenseIds.contains(e['id'].toString())).toList();
    final purchaseTotal = chosenFinance.where((e)=>
      e['category']=='inventory_purchase').fold<int>(0,(sum,e)=>
        sum+((e['amount'] as num?)?.toInt()??0));
    final selectedFinanceTransportTotal = chosenFinance.where((e)=>
      e['category']=='transport').fold<int>(0,(sum,e)=>
        sum+((e['amount'] as num?)?.toInt()??0));
    final registeredCost = _selected.values.fold<int>(0,(sum,row)=>
      sum+row.qty*row.unitCost);
    final financeMath = BatchExpenseMath(
      purchaseExpenses:purchaseTotal,
      transportExpenses:selectedFinanceTransportTotal,
      enteredBookCost:registeredCost,
      hasPurchaseSelection:chosenFinance.any((e)=>
        e['category']=='inventory_purchase'),
    );
    final transportSum = transportRows
        .where((t) => _selectedTransportIds.contains(t['id'].toString()))
        .fold<int>(0, (sum, t) => sum + ((t['amount'] as num?)?.toInt() ?? 0));
    final transportNote = isOld
      ? '${_selectedTransportIds.length} ta transport: '
        '${_money(transportSum)}. Moliya qayta yozilmaydi.'
      : 'Moliyadan tanlangan kitob xarajati: ${_money(purchaseTotal)}; '
        'transport: ${_money(selectedFinanceTransportTotal)}; '
        'Moliya jami: ${_money(financeMath.financeTotal)}; '
        'partiyaga kiritilgan kitoblarning tan narxi: ${_money(registeredCost)}; '
        'farq: ${financeMath.bookDifference==null
          ? "hisoblanmaydi (kitob xarajati tanlanmagan)"
          : _money(financeMath.bookDifference!)}. '
        'Bu xarajatlar Moliya tarixida mavjud, qayta yaratilmaydi.';
    final text = isOld
      ? 'Eski partiyaga $nBooks nomdagi, jami $nQty dona kitob tekshiriladi. '
        'Avvaldan shu partiyada bor kitoblar qayta qo‘shilmaydi; '
        'qolganlari saqlanadi. '
        '$transportNote '
        'Bu tarixiy ma’lumot; ombor va moliyaga qayta qo‘shilmaydi. '
        'Avtomatik narxlar joriy katalog tannarxidir, tarixiy tannarx '
        'ekanligini tekshirish kerak.'
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
      final pieces = (_existing ?? '').split(':');
      final oldType = pieces.firstOrNull == 'import' ||
              pieces.firstOrNull == 'finance_group'
          ? 'old_import' : 'old_group';
      final response = await Supabase.instance.client.rpc('admin_web_bulk_batch_save',
        params: {
          'p_secret': widget.secret,
          'p_data': {
            'mode': isOld ? oldType : 'new',
            if (!isOld) 'title': _title.text.trim(),
            if (!isOld) 'date': DateFormat('yyyy-MM-dd').format(_date),
            if (!isOld) 'note': _note.text.trim(),
            if (isOld) 'existing_id': pieces.firstOrNull == 'finance_group'
                ? targetImportId.toString() : pieces.skip(1).join(':'),
            'apply_to_inventory': !isOld && _syncStock,
            'transport_ids': isOld ? _selectedTransportIds.toList() : <String>[],
            if (!isOld) 'finance_expense_ids':
              _selectedFinanceExpenseIds.toList(),
            'items': list,
          },
        });
      if (!mounted) return;
      final result = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final skipped = (result['skipped_existing'] as num?)?.toInt() ?? 0;
      if (skipped > 0) {
        final saved = (result['items'] as num?)?.toInt() ?? 0;
        final titles = result['skipped_titles'] is List
            ? (result['skipped_titles'] as List)
                .map((x) => x.toString()).join(', ')
            : '';
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Partiya saqlandi'),
            content: Text(
              '$saved ta yangi kitob qo‘shildi. '
              '$skipped ta kitob partiyada avvaldan mavjud edi '
              'va uning soni yoki tannarxi o‘zgartirilmadi.'
              '${titles.isEmpty ? '' : '\n\nMavjud kitoblar: $titles'}'
              '\n\nUlarning sonini o‘zgartirish kerak bo‘lsa, '
              'Partiya tarixi bo‘limidan tahrirlang.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Tushunarli'),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
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

  Widget _expenseChoice(Map<String,dynamic> expense) {
    final id=(expense['id']??'').toString();
    final usedGroup=expense['used_group']!=null;
    final chosen=_selectedFinanceExpenseIds.contains(id);
    final amount=(expense['amount'] as num?)?.toInt()??0;
    final hint=(expense['historical_import']??'').toString();
    final category=(expense['category']??'').toString();
    final transportHistory=expense['historical_transport']==true;
    // Finance entries already reconciled with a historical purchase or
    // transport must not also be allocated to another new batch.
    final assignedElsewhere=usedGroup||hint.isNotEmpty||transportHistory;
    return Card(
      margin:const EdgeInsets.only(bottom:7),
      child:CheckboxListTile(
        controlAffinity:ListTileControlAffinity.leading,
        value:chosen,
        onChanged:_submitting||assignedElsewhere?null:(selected)=>setState((){
          if(selected??false){
            _selectedFinanceExpenseIds.add(id);
          }else{
            _selectedFinanceExpenseIds.remove(id);
          }
        }),
        title:Text(_money(amount),style:const TextStyle(
          fontWeight:FontWeight.w900,fontSize:16)),
        subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${expense['expense_date']??''} • '
            '${(expense['note']??'Izoh yo‘q').toString()}',
            style:const TextStyle(fontSize:12)),
          if(usedGroup) Text('Boshqa partiyaga bog‘langan: '
            '${expense['used_group_title']??''}',
            style:const TextStyle(fontSize:11,color:Colors.red)),
          if(!usedGroup&&hint.isNotEmpty)
            Text('Oldingi partiyada ishlatilgan ($hint). '
              'Takroriy hisob bo‘lmasligi uchun bu yerda tanlanmaydi.',
              style:const TextStyle(fontSize:11,
                color:UzbekCustomerColors.textMuted)),
          if(!usedGroup&&category=='transport'&&transportHistory)
            const Text('Oldingi transport partiyasiga bog‘langan. '
              'Takroriy hisob bo‘lmasligi uchun bu yerda tanlanmaydi.',
              style:TextStyle(fontSize:11,
                color:UzbekCustomerColors.textMuted)),
        ]),
      ),
    );
  }

  Widget _costComparison(BatchExpenseMath totals,int count) {
    final difference=totals.bookDifference;
    final positive=difference!=null&&difference>=0;
    Widget line(String label,String value,{bool stronger=false})=>
      Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:Text(label,style:TextStyle(
            fontSize:stronger?13:12,color:UzbekCustomerColors.navy,
            fontWeight:stronger?FontWeight.w800:FontWeight.w500))),
          const SizedBox(width:8),
          Text(value,style:TextStyle(
            fontSize:stronger?16:13,
            fontWeight:FontWeight.w900,
            color:stronger?UzbekCustomerColors.teal:UzbekCustomerColors.navy)),
        ]));
    return Card(
      margin:const EdgeInsets.only(top:12,bottom:12),
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Moliya va partiya tan narxi taqqoslash',
            style:TextStyle(fontWeight:FontWeight.w900,fontSize:16,
              color:UzbekCustomerColors.navy)),
          const SizedBox(height:11),
          line('Moliya — kitob xaridi',_money(totals.purchaseExpenses)),
          line('Moliya — transport',_money(totals.transportExpenses)),
          const Divider(),
          line('Moliyadagi tanlangan jami',
            _money(totals.financeTotal),stronger:true),
          const SizedBox(height:8),
          line('Kiritilgan kitoblar tan narxi ($count dona)',
            _money(totals.enteredBookCost)),
          line('Transport qo‘shilgan hisob',
            _money(totals.enteredWithTransport)),
          const Divider(),
          line('Farq (Moliya kitob xaridi − tan narx)',
            difference==null?'Kitob xarajatini tanlang':
            (difference<0?'−':'')+_money(difference.abs()),
            stronger:true),
          Text(difference==null
            ? 'Farqni hisoblash uchun “Yangi partiya kitoblar” xarajatini belgilang.'
            : difference==0
              ? 'Mos keldi: tanlangan kitob xarajati va ro‘yxat tan narxi teng.'
              : positive
                ? 'Moliya xarajati ro‘yxatdagi kitoblar tan narxidan katta. '
                  'Kam kiritilgan kitoblar yoki qo‘shimcha xarajatni tekshiring.'
                : 'Ro‘yxatdagi tan narx Moliya kitob xarajatidan katta. '
                  'Ortiqcha kitob yoki tan narxni tekshiring.',
            style:TextStyle(fontSize:11.5,height:1.4,
              color:difference==0?UzbekCustomerColors.teal:
                UzbekCustomerColors.textMuted)),
          const SizedBox(height:7),
          const Text('Bu xarajatlar allaqachon Moliyada yozilgan. '
            'Tanlash yangi xarajat yaratmaydi. Agar “Kitob+transport” '
            'birgalikda xarajatga yozilgan bo‘lsa, summalarni solishtirishdan '
            'oldin izohini tekshiring.',
            style:TextStyle(fontSize:11,height:1.35,
              color:UzbekCustomerColors.textMuted)),
        ]),
      ),
    );
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
                  decoration: const InputDecoration(
                    labelText: 'Kelgan dona', isDense: true,
                    border: OutlineInputBorder()),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: chosen.cost,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => chosen.changedCost = true),
                  decoration: const InputDecoration(
                    labelText: 'Bir dona tannarx ₩',
                    isDense: true, border: OutlineInputBorder()),
                )),
                IconButton(
                  tooltip: 'Bazadagi tannarxni qaytarish',
                  onPressed: _submitting ? null : () {
                    chosen.cost.text = chosen.catalogCost.toString();
                    setState(() => chosen.changedCost = false);
                  },
                  icon: const Icon(Icons.restore_outlined)),
              ]),
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
        final financeOptions = _list(data['finance_options']);
        final selectedExpenseOptions = financeOptions.where((e)=>
          _selectedFinanceExpenseIds.contains(e['id'].toString())).toList();
        final purchaseExpenses=selectedExpenseOptions.where((e)=>
          e['category']=='inventory_purchase').fold<int>(0,(sum,e)=>
            sum+((e['amount'] as num?)?.toInt()??0));
        final newTransportExpenses=selectedExpenseOptions.where((e)=>
          e['category']=='transport').fold<int>(0,(sum,e)=>
            sum+((e['amount'] as num?)?.toInt()??0));
        final transportTotal = transports
          .where((t) => _selectedTransportIds.contains(t['id'].toString()))
          .fold<int>(0, (sum, t) => sum + ((t['amount'] as num?)?.toInt() ?? 0));
        // A confirmed historical finance group is one selectable batch.
        // Expose the September 9 receipt directly instead of asking users
        // to discover it under five outdated purchase names.
        final septemberBatch = imported.where((row) =>
          row['source'] == 'finance_group' &&
          (row['purchase_date'] ?? '').toString() == '2026-09-09' &&
          row['representative_import_id'] != null).toList();
        final listOfExisting = <DropdownMenuItem<String>>[
          for (final row in imported) DropdownMenuItem(
            value: row['source'] == 'finance_group'
                ? 'finance_group:${row['id']}'
                : 'import:${row['id']}',
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
        final chosenExisting = imported.where((p) =>
          _existing == 'finance_group:${p['id']}' &&
          p['source'] == 'finance_group').toList();
        final memberIds = chosenExisting.isNotEmpty
            ? (chosenExisting.first['member_import_ids'] as List? ?? const [])
                .map((id) => id.toString()).toSet()
            : <String>{};
        final savedIds = _list(data['saved_lines']).where((line) =>
          memberIds.contains((line['batch_import_id'] ?? '').toString()))
          .map((line) => (line['book_id'] ?? '').toString()).toSet();
        final visible = books.where((b) =>
          (b['title'] ?? '').toString().toLowerCase().contains(search) &&
          !(_mode == 'old' && chosenExisting.isNotEmpty &&
            savedIds.contains((b['id'] ?? '').toString()))).toList();
        final sum = _selected.values.fold<int>(0,(s,e) =>
          s + e.qty * (e.unitCost < 0 ? 0 : e.unitCost));
        final totals=BatchExpenseMath(
          purchaseExpenses:purchaseExpenses,
          transportExpenses:newTransportExpenses,
          enteredBookCost:sum,
          hasPurchaseSelection:selectedExpenseOptions.any((e)=>
            e['category']=='inventory_purchase'));
        return Column(children: [
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              children: [
                if (septemberBatch.isNotEmpty) ...[
                  Card(
                    child: ListTile(
                      key: const ValueKey('sep09-finance-batch-shortcut'),
                      leading: const Icon(Icons.inventory_2_outlined,
                        color: UzbekCustomerColors.teal),
                      title: Text(
                        (septemberBatch.first['title'] ??
                          '09.09.2026 partiyasi').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: const Text(
                        '09.09.2026 · Birlashtirilgan xarid va transport. '
                        'Kitob soni va tannarxini shu partiyaga kiriting.',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _submitting ? null : () => setState(() {
                        _mode = 'old';
                        _existing = 'finance_group:${septemberBatch.first['id']}';
                        _syncStock = false;
                        _selectedTransportIds.clear();
                        _selectedFinanceExpenseIds.clear();
                      }),
                    ),
                  ),
                  const SizedBox(height: 9),
                ],
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
                    onChanged: _submitting ? null : (v) => setState(() => _existing=v)),
                  const SizedBox(height: 8),
                  const Text(
                    'Eski partiyaga kitoblar faqat tarixiy qayd sifatida bog‘lanadi. '
                    'Ombor ko‘paymaydi va moliyaga qayta xarajat yozilmaydi. '
                    'Bazada chiqqan tannarx joriy tannarxdir, '
                    'eski partiyada farq qilgan bo‘lsa tuzating.',
                    style: TextStyle(fontSize: 12,
                      color: UzbekCustomerColors.textMuted)),
                ],
                if (_mode=='new') ...[
                  _sectionTitle('2. Moliyada saqlangan xarajatlarni tanlang'),
                  const Text('Moliyadagi “Yangi partiya kitoblar” va '
                    '“Transport” xarajatlarini belgilang. Bu yerda yangi '
                    'xarajat yozilmaydi, faqat shu partiyaga bog‘lanadi.',
                    style:TextStyle(fontSize:12,
                      color:UzbekCustomerColors.textMuted)),
                  const SizedBox(height:8),
                  const Text('Yangi partiya kitoblar',
                    style:TextStyle(fontWeight:FontWeight.w900,
                      fontSize:14,color:UzbekCustomerColors.navy)),
                  const SizedBox(height:7),
                  for(final expense in financeOptions.where((e)=>
                    e['category']=='inventory_purchase'))
                    _expenseChoice(expense),
                  const SizedBox(height:12),
                  const Text('Transport',
                    style:TextStyle(fontWeight:FontWeight.w900,
                      fontSize:14,color:UzbekCustomerColors.navy)),
                  const SizedBox(height:7),
                  for(final expense in financeOptions.where((e)=>
                    e['category']=='transport'))
                    _expenseChoice(expense),
                  const SizedBox(height:10),
                  Text('Tanlangan: kitob xaridi ${_money(purchaseExpenses)} '
                    '• transport ${_money(newTransportExpenses)}',
                    style:const TextStyle(
                      fontWeight:FontWeight.w800,fontSize:12,
                      color:UzbekCustomerColors.teal)),
                ] else ...[
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
                ],
                _sectionTitle('3. Katalogdan kitoblarni belgilang'),
                const Text(
                  'Eski partiyaga faqat transport bog‘lash uchun '
                  'kitob tanlash shart emas.',
                  style: TextStyle(fontSize: 12,
                    color: UzbekCustomerColors.textMuted),
                ),
                TextField(
                  controller: _search,
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
                if(_mode=='new')
                  _costComparison(totals,_selected.values.fold<int>(
                    0,(sum,row)=>sum+row.qty)),
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
                    Text(_mode=='new'
                        ? 'Moliya: ${_money(totals.financeTotal)}'
                        : 'Kitoblar ${_money(sum)} + '
                          'transport ${_money(transportTotal)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 11.5)),
                    Text(_mode=='new'
                        ? 'Kitob tan narxi: ${_money(sum)}'
                        : 'Jami ${_money(sum + transportTotal)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 17,
                        color: UzbekCustomerColors.navy)),
                    if(_mode=='new')
                      Text('Farq: ${totals.bookDifference==null
                        ? "kitob xarajati tanlanmagan"
                        : ((totals.bookDifference!<0?"−":"")+
                          _money(totals.bookDifference!.abs()))}',
                        style:const TextStyle(fontSize:11.5,
                          color:UzbekCustomerColors.textMuted)),
                  ],
                )),
                FilledButton.icon(
                  onPressed: _submitting ? null : _save,
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
