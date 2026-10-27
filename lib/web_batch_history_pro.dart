import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';
import 'web_batch_inline_editor.dart';
import 'web_batch_add_picker.dart';
import 'uzbek_customer_style.dart';

String _batchMoney(num value) => '₩${NumberFormat('#,###').format(value.round())}';
int _batchNum(dynamic value) => value is num ? value.round() : int.tryParse('$value') ?? 0;
String _batchDate(dynamic value) {
  final raw = (value ?? '').toString();
  if (raw.length < 10) return 'Sana ko‘rsatilmagan';
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw.substring(0, 10) : DateFormat('dd.MM.yyyy').format(parsed);
}

/// A saved catalog batch must remain visible in the main Partiyalar list,
/// even when it has no separate finance expense or import record.
@visibleForTesting
List<Map<String, dynamic>> filterCatalogBatchGroups(
  List<Map<String, dynamic>> groups,
  String query,
) {
  final needle = query.trim().toLowerCase();
  return groups.where((x) =>
      (x['title'] ?? '').toString().toLowerCase().contains(needle) ||
      (x['batch_date'] ?? '').toString().contains(needle)).toList()
    ..sort((a, b) => (b['batch_date'] ?? '').toString()
        .compareTo((a['batch_date'] ?? '').toString()));
}

/// Read-only FIFO projection: count historical intake and *estimated* outflow.
/// This is NOT a verified sale count and never changes live inventory.
@visibleForTesting
Map<String, int>? historicalBatchOutflowEstimate(
    List<Map<String, dynamic>> lines,
    List<Map<String, dynamic>> lots) {
  if (lines.isEmpty) return null;
  final byId=<String,Map<String,dynamic>>{
    for(final lot in lots) (lot['id']??'').toString():lot,
  };
  var received=0,outflow=0,remaining=0;
  for(final line in lines){
    // Prefer the batch-line RPC's authoritative per-lot FIFO projection.
    // The old optional report remains a backwards-compatible fallback.
    final hasLocal = line.containsKey('fifo_outflow_units') &&
        line.containsKey('fifo_remaining_units');
    final lot=hasLocal ? line : byId[(line['id']??'').toString()];
    if(lot==null) return null;
    int? number(dynamic v)=>v is num?v.toInt():int.tryParse((v??'').toString());
    final qty=number(line['quantity']);
    final used=number(lot['fifo_outflow_units'] ?? lot['estimated_sold_units']);
    final left=number(lot['fifo_remaining_units'] ?? lot['estimated_remaining_units']);
    if(qty==null||used==null||left==null||qty<0||
      used<0||left<0||used+left!=qty) return null;
    received+=qty;outflow+=used;remaining+=left;
  }
  return {'received':received,'outflow':outflow,'remaining':remaining};
}

/// Consistent one-decimal FIFO estimate label on the closed batch card.
@visibleForTesting
String estimatedBatchSoldLabel(Map<String,int> amounts) {
  final total=amounts['received'] ?? 0;
  final used=amounts['outflow'] ?? 0;
  if(total<=0 || used<0 || used>total) return 'Sotuv foizi hozircha aniqlanmadi';
  return 'Taxminiy sotilgan: $used / $total dona • '
      '${(used*100.0/total).toStringAsFixed(1)}%';
}

/// Only confirmed finance purchases are called historical purchase batches.
/// Current catalog stock and unit costs are NOT treated as received shipments.
class WebProfessionalBatches extends StatefulWidget {
  const WebProfessionalBatches({
    super.key,
    required this.secret,
    required this.books,
    required this.registered,
    required this.onAdd,
    required this.onReloadRegistered,
  });
  final String secret;
  final List<Book> books;
  final Future<List<dynamic>> registered;
  final VoidCallback onAdd;
  final VoidCallback onReloadRegistered;

  @override
  State<WebProfessionalBatches> createState() => _WebProfessionalBatchesState();
}

class _WebProfessionalBatchesState extends State<WebProfessionalBatches> {
  late Future<Map<String, dynamic>> overview;
  String mode = 'purchases';
  String query = '';
  bool onlyRestocked = false;
  List<Map<String,dynamic>> _lotEstimates=const [];
  bool _lotEstimatesLoaded=false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    overview = Future.wait<dynamic>([
      Supabase.instance.client.rpc('admin_web_batch_overview',
        params: {'p_secret': widget.secret}),
      Supabase.instance.client.rpc('admin_web_transport_overview',
        params: {'p_secret': widget.secret}),
      Supabase.instance.client.rpc('admin_web_batch_line_list',
        params: {'p_secret': widget.secret}),
      // Keep batch history usable if this optional read-only report fails.
      Supabase.instance.client.rpc('admin_book_profit_batches',
        params: {'p_secret':widget.secret}).catchError((_) => null),
    ]).then((data) {
      final main = data[0] is Map
        ? Map<String,dynamic>.from(data[0] as Map) : <String,dynamic>{};
      final transport = data[1] is Map
        ? Map<String,dynamic>.from(data[1] as Map) : <String,dynamic>{};
      return {...main,
        'transport_records': transport['transports'] ?? [],
        'batch_groups': transport['groups'] ?? [],
        'saved_batch_lines': data[2] ?? [],
        'fifo_outflow': data[3],
      };
    });
  }

  @override
  void didUpdateWidget(covariant WebProfessionalBatches oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registered != widget.registered ||
        oldWidget.secret != widget.secret) {
      _reload();
    }
  }

  void _refresh() {
    setState(_reload);
    widget.onReloadRegistered();
  }

  void _setMode(String value) {
    setState(() { mode = value; query = ''; });
  }

  List<Map<String, dynamic>> _items(dynamic data) {
    if (data is! List) return [];
    return data.whereType<Map>()
      .map((x) => Map<String, dynamic>.from(x))
      .toList(growable: false);
  }

  Future<void> _copyCsv(
    List<Map<String,dynamic>> purchases,
    List<Map<String,dynamic>> inventory,
  ) async {
    String csv(String raw) => '"${raw.replaceAll('"','""')}"';
    final lines = <String>[];
    if (mode == 'purchases') {
      lines.add('Xarid,kelgan_sana,moliya_sanasi,umumiy_won,tarkib_tasdiqlangan');
      for (final item in purchases) {
        lines.add([
          csv((item['title'] ?? '').toString()),
          csv((item['purchase_date'] ?? '').toString()),
          csv((item['posted_date'] ?? '').toString()),
          _batchNum(item['total_krw']).toString(),
          item['item_breakdown_verified'] == true ? 'ha' : 'yoq',
        ].join(','));
      }
    } else if (mode == 'inventory') {
      lines.add('Kitob,joriy_qoldiq,joriy_tannarx_won,sotuv_narxi_won');
      for (final item in inventory) {
        lines.add([
          csv((item['title'] ?? '').toString()),
          _batchNum(item['stock']).toString(),
          _batchNum(item['unit_cost']).toString(),
          _batchNum(item['sale_price']).toString(),
        ].join(','));
      }
    } else {
      return;
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV ma’lumotlari nusxalandi')));
  }

  Widget _metric(String name, String value, IconData icon,
      {String? footnote}) => Container(
    width: 156,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: UzbekCustomerColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: UzbekCustomerColors.teal, size: 21),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 18,
        fontWeight: FontWeight.w900, color: UzbekCustomerColors.navy)),
      const SizedBox(height: 3),
      Text(name, style: const TextStyle(fontWeight: FontWeight.w700,
        fontSize: 11.5, color: UzbekCustomerColors.textMuted)),
      if (footnote != null) Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(footnote, style: const TextStyle(
          fontSize: 10, color: UzbekCustomerColors.textMuted))),
    ]),
  );

  Future<void> _unlinkTransport(Map<String,dynamic> expense) async {
    final name = (expense['note'] ?? 'Transport').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Transportni partiyadan ajratish'),
        content: Text('$name xarajati partiyadan ajratiladi. '
          'Moliyadagi asl xarajat o‘chirilmaydi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog,false),
            child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(dialog,true),
            child: const Text('Ajratish')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Supabase.instance.client.rpc('admin_web_transport_unlink',
        params: {
          'p_secret': widget.secret,
          'p_expense_id': expense['id'],
        });
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transport bog‘lanishi olib tashlandi')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajratib bo‘lmadi: $error')));
    }
  }

  Widget _transportLine(Map<String,dynamic> expense) {
    final amount = _batchNum(expense['amount']);
    final linked = expense['batch_name'] != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined,
          color: UzbekCustomerColors.teal),
        title: Text(
          '${_batchMoney(amount)} • ${expense['note'] ?? 'Transport'}',
          style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${_batchDate(expense['expense_date'])} • '
          '${linked ? 'Partiya: ${expense['batch_name']}' : 'Hali biriktirilmagan'}',
          maxLines: 2),
        trailing: linked
          ? IconButton(tooltip: 'Partiyadan ajratish',
              icon: const Icon(Icons.link_off_rounded),
              onPressed: () => _unlinkTransport(expense))
          : const Icon(Icons.add_link_rounded, color: Colors.grey),
      ),
    );
  }

  // Edit the persisted batch line in place instead of appending another
  // receipt. RPC checks the previously saved quantity before applying delta.
  Future<void> _editSavedBatchLine(Map<String,dynamic> line) async {
    final previous = _batchNum(line['quantity']);
    final controller = TextEditingController(text:previous.toString());
    final formKey=GlobalKey<FormState>();
    final result=await showDialog<int>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:const Text('Partiyadagi sonni tahrirlash'),
        content:Form(key:formKey,child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text((line['title']??'Kitob').toString(),
              style:const TextStyle(fontWeight:FontWeight.w800)),
            const SizedBox(height:6),
            Text('Saqlangan son: $previous dona',
              style:const TextStyle(fontSize:12)),
            const SizedBox(height:12),
            TextFormField(
              controller:controller,
              keyboardType:TextInputType.number,
              autofocus:true,
              decoration:const InputDecoration(
                labelText:'Yangi kelgan soni',
                suffixText:'dona',
                border:OutlineInputBorder()),
              validator:(v){
                final n=int.tryParse(v?.trim()??'');
                if(n==null || n<1 || n>10000) {
                  return '1 dan 10000 gacha son kiriting';
                }
                return null;
              }),
            const SizedBox(height:10),
            Text(
              line['inventory_applied']==true
                ? 'Omborga faqat sonlar farqi qo‘llanadi. Eski yozuv qayta qo‘shilmaydi.'
                : 'Tarixiy partiya: bu tahrir omborga qo‘shimcha kirim yaratmaydi.',
              style:const TextStyle(fontSize:11.5,
                color:UzbekCustomerColors.textMuted)),
          ],
        )),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext),
            child:const Text('Bekor qilish')),
          FilledButton(onPressed:(){
            if(formKey.currentState?.validate()!=true)return;
            Navigator.pop(dialogContext,int.parse(controller.text.trim()));
          },child:const Text('Saqlash')),
        ],
      ),
    );
    controller.dispose();
    if(result==null || result==previous || !mounted) return;
    try {
      final response=await Supabase.instance.client.rpc(
        'admin_web_batch_edit_line',
        params:{
          'p_secret':widget.secret,
          'p_line_id':_batchNum(line['id']),
          'p_expected_quantity':previous,
          'p_quantity':result,
        });
      if(!mounted)return;
      _refresh();
      final applied=response is Map && response['inventory_updated']==true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(applied
          ? 'Partiya yangilandi: omborga faqat ${result-previous} dona farq qo‘llandi'
          : 'Partiya soni $previous → $result qilib saqlandi. Omborga takror qo‘shilmadi.'),
      ));
    } catch(error) {
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Partiyani tahrirlashda xatolik: $error')));
    }
  }

  Widget _savedBatchLine(Map<String,dynamic> line) => ListTile(
    contentPadding:EdgeInsets.zero,
    leading:const Icon(Icons.menu_book_outlined,
      color:UzbekCustomerColors.teal),
    title:Text((line['title']??'Kitob').toString(),
      maxLines:2,overflow:TextOverflow.ellipsis,
      style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)),
    subtitle:Text('${_batchNum(line['quantity'])} dona • 1 dona ${_batchMoney(_batchNum(line['unit_cost']))}',
      style:const TextStyle(fontSize:12)),
    trailing:IconButton(
      tooltip:'Kiritilgan sonni tahrirlash',
      icon:const Icon(Icons.edit_outlined),
      onPressed:()=>_editSavedBatchLine(line)),
    onTap:()=>_editSavedBatchLine(line),
  );

  Future<void> _editLinkedFinanceAmount(
      Map<String,dynamic> group, Map<String,dynamic> expense) async {
    final expenseId = (expense['id'] ?? '').toString();
    final groupId = (group['id'] ?? '').toString();
    if (expenseId.isEmpty || groupId.isEmpty) return;
    final oldAmount = _batchNum(expense['amount']);
    final category = (expense['category'] ?? '').toString();
    final title = category == 'transport'
        ? 'Transport xarajati' : 'Yangi partiya kitoblar xarajati';
    final input = TextEditingController(text: oldAmount.toString());
    String? errorText;
    final newAmount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, repaint) => AlertDialog(
          title: const Text('Moliyadagi xarajatni tahrirlash'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((group['title'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('$title • avvalgi: ${_batchMoney(oldAmount)}'),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'To‘g‘ri summa (₩)',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) repaint(() => errorText = null);
                },
              ),
              const SizedBox(height: 10),
              const Text('Bu o‘zgarish Moliyadagi asl xarajatni ham '
                'yangilaydi. Kitoblarning tannarxi va ombor soni '
                'o‘zgarmaydi.', style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Bekor qilish')),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(input.text);
                if (parsed == null || parsed < 1 || parsed > 1000000000) {
                  repaint(() => errorText =
                    '1 dan 1 000 000 000 vongacha kiriting');
                  return;
                }
                Navigator.pop(dialogContext, parsed);
              },
              child: const Text('Davom etish'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    if (!mounted || newAmount == null || newAmount == oldAmount) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xarajat summasini tasdiqlang'),
        content: Text(
          '$title\n'
          '${_batchMoney(oldAmount)} → ${_batchMoney(newAmount)}\n\n'
          'Bu Moliyadagi mavjud yozuvni o‘zgartiradi; '
          'partiya jami va farqi qayta hisoblanadi. '
          'Yangi xarajat yaratilmaydi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Orqaga')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Saqlash')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await Supabase.instance.client.rpc(
        'admin_web_batch_update_linked_expense',
        params: {
          'p_secret': widget.secret,
          'p_batch_group_id': groupId,
          'p_expense_id': expenseId,
          'p_expected_amount': oldAmount,
          'p_new_amount': newAmount,
        },
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Moliyadagi xarajat yangilandi. Partiya va farq qayta hisoblandi.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xarajatni o‘zgartirib bo‘lmadi: $error')),
      );
      _refresh();
    }
  }

  Widget _soldBatchPreview(List<Map<String,dynamic>> lines) {
    final x=historicalBatchOutflowEstimate(lines,_lotEstimates);
    if(x==null || x['received']==0) {
      return const Padding(
        padding:EdgeInsets.only(top:5),
        child:Text('Sotilgan dona va foizi: hozircha hisoblanmadi',
          style:TextStyle(fontSize:11.5,
            color:UzbekCustomerColors.textMuted)));
    }
    final total=x['received']!;
    final used=x['outflow']!;
    return Padding(
      padding:const EdgeInsets.only(top:6),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(estimatedBatchSoldLabel(x),
          style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900,
            color:UzbekCustomerColors.teal)),
        const SizedBox(height:4),
        ClipRRect(borderRadius:BorderRadius.circular(3),
          child:LinearProgressIndicator(
            value:(used/total).clamp(0.0,1.0),
            minHeight:5,
            backgroundColor:const Color(0xFFE5ECE8),
            color:UzbekCustomerColors.teal)),
        const Text('FIFO hisobiy — aniq sotuv emas',
          style:TextStyle(fontSize:10.5,
            color:UzbekCustomerColors.textMuted)),
      ]),
    );
  }

  Widget _batchOutflowSummary(List<Map<String,dynamic>> lines){
    if(lines.isEmpty) return const SizedBox.shrink();
    final x=historicalBatchOutflowEstimate(lines,_lotEstimates);
    if(x==null) return const Padding(
      padding:EdgeInsets.symmetric(vertical:7),
      child:Text('FIFO hisobi bu partiya uchun to‘liq emas.',
        style:TextStyle(fontSize:12,color:UzbekCustomerColors.textMuted)));
    return Padding(
      padding:const EdgeInsets.symmetric(vertical:10),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Partiyada sotilganlar (FIFO — taxminiy)',
          style:TextStyle(fontSize:13,fontWeight:FontWeight.w900,
            color:UzbekCustomerColors.navy)),
        _detail('Jami kelgan','${x['received']} dona'),
        _detail('Taxminiy sotilgan','${x['outflow']} dona'),
        _detail('Taxminiy qolgan','${x['remaining']} dona'),
        _detail('Taxminiy sotilish foizi',
          x['received']==0?'—':
            '${(x['outflow']!*100.0/x['received']!).toStringAsFixed(1)}%'),
        const Text('Bu aniq sotilgan son emas: hisob joriy ombor '
          'qoldig‘iga asoslanadi. Qaytarish va qo‘lda tuzatishlar '
          'ham ta’sir qilishi mumkin. Eski partiyani to‘ldirish '
          'omborni qayta oshirmaydi va sotilgan kitobni '
          'ikkinchi marta ayirmaydi.',
          style:TextStyle(fontSize:11,color:UzbekCustomerColors.textMuted,
            height:1.35)),
      ]),
    );
  }

  Widget _groupTile(Map<String,dynamic> item,
      List<Map<String,dynamic>> transports,
      List<Map<String,dynamic>> savedLines) {
    final id = item['id'].toString();
    final lines=savedLines.where((l)=>l['batch_group_id']?.toString()==id).toList();
    final count=lines.fold<int>(0,(sum,l)=>sum+_batchNum(l['quantity']));
    final linked = transports.where((t) =>
      t['batch_group_id']?.toString() == id).toList();
    final transport = linked.fold<int>(0,
      (s,t) => s + _batchNum(t['amount']));
    final books = _batchNum(item['book_value']);
    final purchaseExpense = _batchNum(item['finance_purchase_total']);
    final financeTransport = _batchNum(item['finance_transport_total']);
    final expensesLinked=_batchNum(item['finance_expense_count']);
    final difference=purchaseExpense-books;
    final references=_items(item['finance_references']);
    final purchaseReferences = references.where((e) =>
      e['category'] == 'inventory_purchase').toList();
    final transportReferences = references.where((e) =>
      e['category'] == 'transport').toList();
    return Card(margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        leading: const Icon(Icons.inventory_2_outlined,
          color: UzbekCustomerColors.teal),
        title: Text((item['title'] ?? 'Yangi partiya').toString(),
          style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${_batchDate(item['batch_date'])} • '
            '${lines.length} xil kitob · $count dona saqlangan'),
          _soldBatchPreview(lines),
        ]),
        trailing: Text(_batchMoney(books + transport),
          style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          if(expensesLinked>0) ...[
            const Text('Moliyada avval saqlangan xarajatlar',
              style:TextStyle(color:UzbekCustomerColors.navy,
                fontSize:14,fontWeight:FontWeight.w900)),
            Row(children: [
              Expanded(child: _detail('Yangi partiya kitoblar',
                _batchMoney(purchaseExpense))),
              if (purchaseReferences.length == 1)
                TextButton.icon(
                  onPressed: () => _editLinkedFinanceAmount(
                    item, purchaseReferences.single),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Tahrirlash'),
                ),
            ]),
            Row(children: [
              Expanded(child: _detail('Transport',
                _batchMoney(financeTransport))),
              if (transportReferences.length == 1)
                IconButton(
                  tooltip: 'Transport summasini tahrirlash',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editLinkedFinanceAmount(
                    item, transportReferences.single),
                ),
            ]),
            _detail('Moliyada tanlangan jami',
              _batchMoney(purchaseExpense+financeTransport)),
            const Divider(),
            _detail('Bu partiyada kiritilgan kitoblar tan narxi',
              _batchMoney(books)),
            if(references.any((e)=>e['category']=='inventory_purchase')) ...[
              _detail('Farq (Moliya kitob xaridi − tan narx)',
                (difference<0?'−':'')+_batchMoney(difference.abs())),
              Text(difference==0
                ? 'Kitob xarajati va kiritilgan kitoblar tan narxi teng.'
                : difference>0
                  ? 'Kitob xarajati katta: kiritilmagan kitob yoki '
                    'qo‘shimcha xarajatni tekshiring.'
                  : 'Kiritilgan kitoblar tan narxi katta: '
                    'son va narxlarni tekshiring.',
                style:const TextStyle(color:UzbekCustomerColors.textMuted,
                  fontSize:11.5)),
            ],
            for(final entry in references)
              Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${entry['date']??''} • '
                    '${entry['category']=='transport'
                      ? 'Transport' : 'Yangi partiya kitoblar'} • '
                    '${_batchMoney(_batchNum(entry['amount']))} • '
                    '${entry['note']??''}',
                    style: const TextStyle(fontSize: 11.5,
                      color: UzbekCustomerColors.textMuted))),
                  IconButton(
                    tooltip: 'Moliyadagi xarajat summasini tahrirlash',
                    icon: const Icon(Icons.edit_outlined,
                      color: UzbekCustomerColors.teal),
                    onPressed: () => _editLinkedFinanceAmount(item, entry),
                  ),
                ])),
            const Text('Ushbu summalar Moliyada qayta xarajat qilinmagan; '
              'faqat mavjud yozuvlarga havola qilingan.',
              style:TextStyle(fontSize:11,
                color:UzbekCustomerColors.textMuted)),
          ] else ...[
            _detail('Kiritilgan kitoblar tannarxi',_batchMoney(books)),
            _detail('Transport xarajatlari',_batchMoney(transport)),
            _detail('Kitob + transport (hisoblangan)',_batchMoney(books + transport)),
          ],
          _batchOutflowSummary(lines),
          const SizedBox(height: 12),
          WebBatchInlineEditor(
            key:ValueKey('group:'+id),
            secret:widget.secret,kind:'group',batchKey:id,
            lines:lines,onSaved:_refresh),
          const SizedBox(height: 6),
          for(final expense in linked) _transportLine(expense),
          const Text('Kitob tannarxi partiyaga kiritilgan qiymatlar '
            'asosida hisoblangan. Transport moliyada allaqachon mavjud, '
            'bu hisob xarajatni takror yozmaydi.',
            style: TextStyle(fontSize: 12,
              color: UzbekCustomerColors.textMuted)),
        ],
      ));
  }

  // Older batch records can have neither a finance import ID nor a
  // catalog group ID. Group them by their recorded purchase date for editing,
  // without fabricating a finance/stock linkage.
  Widget _legacyDateBatchTile(String date,List<Map<String,dynamic>> lines) {
    final count=lines.fold<int>(0,(sum,line)=>sum+_batchNum(line['quantity']));
    final cost=lines.fold<int>(0,(sum,line)=>
      sum+_batchNum(line['quantity'])*_batchNum(line['unit_cost']));
    return Card(margin:const EdgeInsets.only(bottom:9),
      child:ExpansionTile(
        leading:const Icon(Icons.history_rounded,
          color:UzbekCustomerColors.teal),
        title:Text('${_batchDate(date)} partiyasi',
          style:const TextStyle(fontWeight:FontWeight.w900)),
        subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${lines.length} xil kitob · $count dona saqlangan',
            style:const TextStyle(fontSize:12)),
          _soldBatchPreview(lines),
        ]),
        trailing:Text(_batchMoney(cost),
          style:const TextStyle(fontWeight:FontWeight.w900)),
        childrenPadding:const EdgeInsets.fromLTRB(16,0,16,14),
        children:[
          const Text('Bu tarixiy kirim; hozirgi omborga qayta qo‘shilmaydi.',
            style:TextStyle(fontSize:12,
              color:UzbekCustomerColors.textMuted)),
          _batchOutflowSummary(lines),
          WebBatchInlineEditor(
            key:ValueKey('legacy:'+date),secret:widget.secret,
            kind:'legacy',batchKey:date,lines:lines,onSaved:_refresh),
        ],
      ),
    );
  }

  // UI grouping only: original finance records are never rewritten or added.
  List<Map<String,dynamic>> _combinedPurchases(
      List<Map<String,dynamic>> purchases) {
    final result = <Map<String,dynamic>>[];
    final seen = <String>{};
    for (final row in purchases) {
      final groupId = (row['finance_group_id'] ?? '').toString();
      if (groupId.isEmpty) {
        result.add(row);
        continue;
      }
      if (!seen.add(groupId)) continue;
      final members = purchases.where(
        (p) => (p['finance_group_id'] ?? '').toString() == groupId,
      ).toList()..sort((a, b) =>
        _batchNum(a['id']).compareTo(_batchNum(b['id'])));
      final amount = members.fold<int>(0, (sum, m) =>
        sum + _batchNum(m['total_krw']));
      result.add({
        'id': 'finance_group:$groupId',
        'title': row['finance_group_title'] ?? 'Birlashgan partiya',
        'purchase_date': row['finance_group_date'] ?? row['purchase_date'],
        'posted_date': row['posted_date'],
        'total_krw': amount,
        'source': 'finance_group',
        'members': members,
        'finance_group_id': groupId,
      });
    }
    result.sort((a,b) {
      final n = (b['purchase_date'] ?? '').toString().compareTo(
        (a['purchase_date'] ?? '').toString());
      return n != 0 ? n : (b['id'] ?? '').toString()
        .compareTo((a['id'] ?? '').toString());
    });
    return result;
  }

  // Read-only comparison: references finance expenses without posting them
  // again or changing inventory, sales or the historical lot unit costs.
  Widget _savedBatchFinanceComparison({
    required int purchaseExpense,
    required int transportExpense,
    required List<Map<String,dynamic>> lines,
  }) {
    final entered=lines.fold<int>(0,(total,line)=>
      total+_batchNum(line['quantity'])*_batchNum(line['unit_cost']));
    final qty=lines.fold<int>(0,(total,line)=>
      total+_batchNum(line['quantity']));
    final difference=purchaseExpense-entered;
    final known=lines.isNotEmpty;
    final differenceText=(difference<0?'−':'')+
      _batchMoney(difference.abs());
    return Container(
      margin:const EdgeInsets.fromLTRB(0,14,0,12),
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(
        color:const Color(0xFFF1F7F4),
        border:Border.all(color:const Color(0xFFCDE4D9)),
        borderRadius:BorderRadius.circular(14),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Moliya va partiya tan narxi taqqoslash',
          style:TextStyle(color:UzbekCustomerColors.navy,
            fontSize:15,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        _detail('Moliyada kitoblar uchun xarajat',
          _batchMoney(purchaseExpense)),
        _detail('Moliyadagi transport xarajati',
          _batchMoney(transportExpense)),
        const Divider(),
        _detail('Moliyadagi jami xarajat',
          _batchMoney(purchaseExpense+transportExpense)),
        const SizedBox(height:8),
        _detail('Bu partiyaga kiritilgan kitoblar tan narxi ($qty dona)',
          _batchMoney(entered)),
        if(known)...[
          const Divider(),
          _detail('Farq: kitob xarajati − kiritilgan tan narx',
            differenceText),
          Text(difference==0
            ? 'Kitob xarajati va ro‘yxatdagi kitoblarning tan narxi teng.'
            : difference<0
              ? 'Ro‘yxatdagi kitoblarning tan narxi Moliyadagi '
                'kitob xarajatidan katta. Son va narxlarni tekshiring.'
              : 'Moliyadagi kitob xarajati ro‘yxatdagi tan narxdan '
                'katta. Kiritilmagan kitoblar yoki boshqa xarajatlarni tekshiring.',
            style:const TextStyle(fontSize:11.5,
              color:UzbekCustomerColors.textMuted,height:1.35)),
        ] else
          const Text('Partiyadagi kitoblar hali kiritilmagan; '
            'farqni hisoblash uchun kitoblarni belgilang.',
            style:TextStyle(color:UzbekCustomerColors.textMuted,
              fontSize:11.5)),
        const SizedBox(height:8),
        const Text('Bu faqat taqqoslash: Moliya xarajatlari, sotuv foydasi '
          'va ombor qoldig‘i o‘zgartirilmaydi.',
          style:TextStyle(color:UzbekCustomerColors.textMuted,
            fontSize:10.5,height:1.35)),
      ]),
    );
  }

  Future<void> _openFinanceGroupBookEntry(String financeGroupId) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WebBatchMultiAddPage(
        secret: widget.secret,
        initialFinanceGroupId: financeGroupId,
      )),
    );
    if (mounted && saved == true) _refresh();
  }

  Widget _purchaseTile(Map<String, dynamic> item, int index,
      List<Map<String,dynamic>> transports,
      List<Map<String,dynamic>> savedLines) {
    final title = (item['title'] ?? 'Kitob xaridi').toString();
    final members = _items(item['members']);
    final grouped = members.isNotEmpty;
    final memberIds = grouped
      ? members.map((m) => m['id'].toString()).toSet()
      : <String>{item['id'].toString()};
    final matchedLines=savedLines.where((l)=>
      memberIds.contains((l['batch_import_id']??'').toString())).toList();
    final matchedQty=matchedLines.fold<int>(
      0,(sum,l)=>sum+_batchNum(l['quantity']));
    final bookCost = _batchNum(item['total_krw']);
    final verified = item['item_breakdown_verified'] == true;
    final isOpeningStock = item['source'] == 'opening_stock_baseline';
    final posted = item['posted_date']?.toString();
    final bought = item['purchase_date']?.toString();
    final linked = transports.where((t) =>
      memberIds.contains(t['batch_import_id']?.toString())).toList();
    final shipping = linked.fold<int>(0,(s,t) => s + _batchNum(t['amount']));
    final grandTotal = bookCost + shipping;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF2ED),
          child: const Icon(Icons.inventory_2_outlined,
            color: UzbekCustomerColors.teal)),
        title: Text(title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w900)),
        subtitle:Padding(padding:const EdgeInsets.only(top:4),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(isOpeningStock
              ? 'Boshlang‘ich qoldiq • Moliya qaydi'
              : grouped
                ? '${members.length} ta xarid birlashtirilgan • '
                  '${_batchDate(bought)}'
                : 'Xarid: ${_batchDate(bought)} • Moliya qaydi',
              style:const TextStyle(fontSize:12)),
            _soldBatchPreview(matchedLines),
          ])),
        trailing: Text(_batchMoney(grandTotal),
          style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w900, color: UzbekCustomerColors.navy)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          _detail(isOpeningStock ? 'Boshlang‘ich qoldiq qiymati'
              : 'Kitoblar uchun xarajat', _batchMoney(bookCost)),
          _detail('Transport xarajati', _batchMoney(shipping)),
          const Divider(height: 16),
          _detail('JAMI — kitoblar + transport', _batchMoney(grandTotal)),
          _detail('Partiya sanasi', _batchDate(bought)),
          if (grouped) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              key: ValueKey('add-books-to-finance-group:${item['finance_group_id']}'),
              onPressed: () => _openFinanceGroupBookEntry(
                item['finance_group_id'].toString()),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Shu partiyaga kitob qo‘shish'),
            )),
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                'Mavjud partiyaga kitob soni va tannarxini kiriting. '
                'Moliya xarajati va ombor soni takror qo‘shilmaydi.',
                style: TextStyle(fontSize: 11,
                  color: UzbekCustomerColors.textMuted),
              ),
            ),
          ],
          if (!grouped && posted != bought)
            _detail('Moliyaga kiritilgan sana', _batchDate(posted)),
          _detail('Manba', isOpeningStock
            ? 'Moliya → Avvaldan qolgan kitoblar'
            : grouped ? '${members.length} ta moliya xaridi birlashtirilgan'
            : 'Moliya → Kitob xaridi'),
          if (grouped) ...[
            const SizedBox(height: 12),
            _detail('Birlashtirilgan kitob xaridlari',
              '${members.length} ta · ${_batchMoney(bookCost)}'),
            const Text('Asl xarid qaydlari moliyada saqlangan. '
              'Ularning eski alohida nomlari ko‘rsatilmaydi.',
              style: TextStyle(fontSize: 11,
                color: UzbekCustomerColors.textMuted)),
          ] else
            _detail('Kitoblar tarkibi',
              verified ? 'Tasdiqlangan' : 'Kitobma-kitob tasdiqlanmagan'),
          // One visible card for already-recorded finance and the actual
          // book receipt values. No finance insert, inventory write or
          // historical profit recalculation takes place here.
          _savedBatchFinanceComparison(
            purchaseExpense:bookCost,
            transportExpense:shipping,
            lines:matchedLines),
          const SizedBox(height:12),
          Text('Bu partiyaga kiritilgan: ${matchedLines.length} nomdagi kitob, $matchedQty dona',
            style:const TextStyle(fontWeight:FontWeight.w800)),
          _batchOutflowSummary(matchedLines),
          if(grouped)
            // Only show an editor for the group's main receipt, plus any
            // other receipt that already contains older book lines.
            // This avoids five empty editors / five obsolete names.
            for(final member in members)
              if(member['id'].toString()==members.first['id'].toString() ||
                 matchedLines.any((l) =>
                   l['batch_import_id']?.toString()==member['id'].toString())) ...[
                const SizedBox(height:12),
                if(member['id'].toString()==members.first['id'].toString())
                  const Text('Partiya kitoblarini tahrirlash',
                    style:TextStyle(fontWeight:FontWeight.w800,fontSize:13)),
                WebBatchInlineEditor(
                  key:ValueKey('import:'+member['id'].toString()),
                  secret:widget.secret,kind:'import',
                  batchKey:member['id'].toString(),
                  lines:matchedLines.where((l)=>
                    l['batch_import_id']?.toString()==member['id'].toString()
                  ).toList(),
                  onSaved:_refresh),
              ]
          else
            WebBatchInlineEditor(
              key:ValueKey('import:'+item['id'].toString()),
              secret:widget.secret,kind:'import',
              batchKey:item['id'].toString(),
              lines:matchedLines,onSaved:_refresh),
          if (linked.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Transport tafsilotlari',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
            const SizedBox(height: 8),
            for (final expense in linked) _transportLine(expense),
          ],
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft,
            child: Text(
              'Bu summa moliyada avval hisoblangan. Bu yerda faqat qaydlar tarixi ko‘rsatiladi; takror xarajat yoki ombor kirimi yaratilmaydi.',
              style: TextStyle(fontSize: 12,
                color: UzbekCustomerColors.textMuted, height: 1.35))),
        ],
      ),
    );
  }

  Widget _detail(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(title, style: const TextStyle(
        fontSize: 12, color: UzbekCustomerColors.textMuted))),
      const SizedBox(width: 10),
      Flexible(child: Text(value, textAlign: TextAlign.end,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
    ]),
  );

  Widget _inventoryTile(Map<String,dynamic> item) {
    final stock = _batchNum(item['stock']);
    final cost = _batchNum(item['unit_cost']);
    final sell = _batchNum(item['sale_price']);
    final restocked = item['restocked_at'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF1F4F1),
          child: Icon(Icons.menu_book_outlined,
            color: UzbekCustomerColors.teal)),
        title: Text((item['title'] ?? 'Kitob').toString(),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Text('$stock dona mavjud • Joriy tannarx: ${_batchMoney(cost)}',
          style: const TextStyle(fontSize: 12)),
        trailing: Text(_batchMoney(stock * cost),
          style: const TextStyle(fontWeight: FontWeight.w900,
            color: UzbekCustomerColors.navy)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
        children: [
          _detail('Hozirgi mavjud miqdor', '$stock dona'),
          _detail('Hozirgi 1 dona tannarx', _batchMoney(cost)),
          _detail('Hozirgi 1 dona sotuv narxi', _batchMoney(sell)),
          _detail('Hozirgi ombor qiymati', _batchMoney(stock * cost)),
          if (restocked != null)
            _detail('So‘nggi qayta to‘ldirish belgisi', _batchDate(restocked)),
          const Text(
            'Bu bugungi ombor ko‘rsatkichi. Tarixiy partiyada aynan shuncha dona kelgan degani emas.',
            style: TextStyle(fontSize: 11.5,
              color: UzbekCustomerColors.textMuted)),
        ],
      ),
    );
  }

  Widget _registeredTile(Map<String,dynamic> item) {
    final qty = _batchNum(item['quantity']);
    final cost = _batchNum(item['unit_cost']);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        title: Text((item['title'] ?? 'Kitob').toString(),
          style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${(item['batch_name'] ?? 'Alohida partiya')} • '
          '${_batchDate(item['purchased_at'])} • $qty dona',
          maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(_batchMoney(qty * cost),
          style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
        children: [
          _detail('Partiya', (item['batch_name'] ?? 'Alohida partiya').toString()),
          _detail('Dona soni', '$qty'),
          _detail('Bir dona tannarx', _batchMoney(cost)),
          _detail('Tannarx manbasi', item['cost_origin'] == 'catalog_prefill'
            ? 'Katalogdagi joriy tannarxdan olingan'
            : 'Qo‘lda kiritilgan tannarx'),
          _detail('Jami', _batchMoney(qty * cost)),
          _detail('Rejalangan sotuv narxi',
            _batchMoney(_batchNum(item['suggested_price']))),
          if ((item['note'] ?? '').toString().trim().isNotEmpty)
            _detail('Izoh', (item['note'] ?? '').toString()),
          Align(alignment:Alignment.centerRight,
            child:OutlinedButton.icon(
              onPressed:()=>_editSavedBatchLine(item),
              icon:const Icon(Icons.edit_outlined,size:18),
              label:const Text('Sonini tahrirlash'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String,dynamic>>(
    future: overview,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Padding(
        padding: const EdgeInsets.all(18), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Text('Partiya ma’lumotlarini yuklab bo‘lmadi'),
            const SizedBox(height: 12),
            Text('${snapshot.error}', textAlign: TextAlign.center),
            TextButton(onPressed: _refresh, child: const Text('Qayta urinish')),
          ])));
      if (!snapshot.hasData) return const Center(
        child: CircularProgressIndicator());
      final data = snapshot.data!;
      final originalPurchases = _items(data['purchases']);
      final purchases = _combinedPurchases(originalPurchases);
      final inventory = _items(data['inventory']);
      final transports = _items(data['transport_records']);
      final groups = _items(data['batch_groups']);
      final savedLines=_items(data['saved_batch_lines']);
      final fifo=data['fifo_outflow'];
      _lotEstimatesLoaded=fifo is Map && fifo['lots'] is List;
      _lotEstimates=_lotEstimatesLoaded
        ? _items((fifo as Map)['lots']) : const [];
      final unlinkedByDate=<String,List<Map<String,dynamic>>>{};
      for(final line in savedLines) {
        if(line['batch_group_id']!=null || line['batch_import_id']!=null) continue;
        final key=(line['purchased_at']??'').toString();
        unlinkedByDate.putIfAbsent(key,()=>[]).add(line);
      }
      final unlinkedDates=unlinkedByDate.keys.toList()
        ..sort((a,b)=>b.compareTo(a));
      final connectedTotal = transports.where((x) =>
        x['batch_name'] != null).fold<int>(
          0, (sum,item) => sum + _batchNum(item['amount']));
      final unlinkedTotal = transports.where((x) =>
        x['batch_name'] == null).fold<int>(
          0, (sum,item) => sum + _batchNum(item['amount']));
      final realPurchases = purchases.where((item) =>
        item['source'] != 'opening_stock_baseline').toList();
      final openingEntries = purchases.where((item) =>
        item['source'] == 'opening_stock_baseline').toList();
      final purchaseSum = realPurchases.fold<int>(
        0, (sum, item) => sum + _batchNum(item['total_krw']));
      final openingValue = openingEntries.fold<int>(
        0, (sum, item) => sum + _batchNum(item['total_krw']));
      final stockQty = inventory.fold<int>(
        0, (sum, item) => sum + _batchNum(item['stock']));
      final stockValue = inventory.fold<int>(
        0, (sum, item) => sum +
          _batchNum(item['stock']) * _batchNum(item['unit_cost']));
      final needle = query.trim().toLowerCase();
      final shownPurchases = purchases.where((x) =>
        (x['title'] ?? '').toString().toLowerCase().contains(needle)).toList();
      // Catalog batch groups are saved receipts too, separate from finance.
      // Never double-count their book value as new finance purchases.
      final shownGroups = filterCatalogBatchGroups(groups, query);
      final shownInventory = inventory.where((x) =>
        (x['title'] ?? '').toString().toLowerCase().contains(needle) &&
        (!onlyRestocked || x['restocked_at'] != null)).toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          Row(children: [
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Partiyalar va xaridlar',
                  style: TextStyle(fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: UzbekCustomerColors.navy)),
                SizedBox(height: 3),
                Text('Xaridlar, joriy qoldiq va alohida partiya qaydlari',
                  style: TextStyle(fontSize: 12,
                    color: UzbekCustomerColors.textMuted)),
              ],
            )),
            IconButton(onPressed: _refresh,
              tooltip: 'Yangilash', icon: const Icon(Icons.refresh_rounded)),
          ]),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Partiyaga kitoblar qo‘shish')),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _metric('Moliya xaridlari',
              '${realPurchases.length} ta partiya',
              Icons.receipt_long_outlined,
              footnote: '${originalPurchases.where((p) =>
                p['source'] == 'finance_record').length} ta asl xarid qaydi'),
            _metric('Yangi xaridlar summasi',
              _batchMoney(purchaseSum), Icons.account_balance_wallet_outlined),
            _metric('Boshlang‘ich qoldiq qaydi',
              _batchMoney(openingValue), Icons.bookmark_border_rounded,
              footnote: 'Yangi partiya xaridiga qo‘shilmaydi'),
            _metric('Hozirgi ombor',
              '${inventory.length} nom / $stockQty dona',
              Icons.inventory_2_outlined,
              footnote: 'Tannarxi: ${_batchMoney(stockValue)}'),
            _metric('Partiyaga biriktirilgan transport',
              _batchMoney(connectedTotal), Icons.local_shipping_outlined),
            _metric('Biriktirilmagan transport',
              _batchMoney(unlinkedTotal), Icons.link_off_rounded),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F6F4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCFE2D9))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.verified_user_outlined,
                  color: UzbekCustomerColors.teal, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Xarid summalari mavjud moliya yozuvlaridan olindi. '
                  'Ombor tannarxi va sonlari hozirgi holat. '
                  'Qaysi partiyaga qaysi kitob kirgani tasdiqlanmasa, '
                  'tizim uni taxmin qilib tarixga kiritmaydi.',
                  style: TextStyle(fontSize: 12, height: 1.4,
                    color: UzbekCustomerColors.navy))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ChoiceChip(label: Text('Partiyalar (${purchases.length + groups.length})'),
                selected: mode == 'purchases',
                onSelected: (_) => _setMode('purchases')),
              const SizedBox(width: 8),
              ChoiceChip(label: Text('Ombor (${inventory.length})'),
                selected: mode == 'inventory',
                onSelected: (_) => _setMode('inventory')),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Kitobma-kitob partiyalar'),
                selected: mode == 'registered',
                onSelected: (_) => _setMode('registered')),
              const SizedBox(width: 8),
              ChoiceChip(label: Text('Transport (${transports.length})'),
                selected: mode == 'transport',
                onSelected: (_) => _setMode('transport')),
            ]),
          ),
          const SizedBox(height: 14),
          if (mode != 'registered') ...[
            Row(children: [
              Expanded(child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  hintText: mode == 'purchases'
                    ? 'Xarid yoki qoldiq qaydini qidiring...'
                    : 'Kitob nomini qidiring...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: const OutlineInputBorder()),
              )),
              const SizedBox(width: 8),
              IconButton(onPressed: () => _copyCsv(purchases, inventory),
                tooltip: 'CSV nusxalash',
                icon: const Icon(Icons.copy_all_outlined)),
            ]),
            if (mode == 'inventory')
              CheckboxListTile(
                value: onlyRestocked, contentPadding: EdgeInsets.zero,
                title: const Text('Faqat qayta keltirilgan sanasi borlar',
                  style: TextStyle(fontSize: 12)),
                onChanged: (v) => setState(() => onlyRestocked = v ?? false)),
          ],
          if (mode == 'purchases') ...[
            if (shownGroups.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(bottom: 8),
                child: Text('Yangi kiritilgan partiyalar',
                  style: TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 16, color: UzbekCustomerColors.navy))),
              for (final group in shownGroups)
                _groupTile(group,transports,savedLines),
              const SizedBox(height: 12),
            ],
            if (shownPurchases.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(bottom: 8),
                child: Text('Moliya bo‘yicha xarid partiyalari',
                  style: TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 16, color: UzbekCustomerColors.navy))),
              for (var i=0;i<shownPurchases.length;i++)
                _purchaseTile(shownPurchases[i],i,transports,savedLines),
            ],
            if (shownGroups.isEmpty && shownPurchases.isEmpty)
              const Padding(padding: EdgeInsets.all(24),
                child: Text('Mos partiya yoki xarid yozuvi yo‘q')),
          ],
          if (mode == 'inventory') ...[
            if (shownInventory.isEmpty)
              const Padding(padding: EdgeInsets.all(24),
                child: Text('Mos kitob yo‘q')),
            for (final item in shownInventory) _inventoryTile(item),
          ],
          if (mode == 'transport') ...[
            const Text('Transport xarajatlari', style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Transport xarajatlari moliyadan olinadi. '
              'Partiyaga biriktirilganlarini bu yerdan ajratish va '
              'boshqa partiyaga qayta belgilash mumkin. '
              'Asl xarajatlar o‘zgarmaydi.',
              style: TextStyle(fontSize: 12,
                color: UzbekCustomerColors.textMuted)),
            const SizedBox(height: 12),
            for (final expense in transports) _transportLine(expense),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: widget.onAdd,
              icon: const Icon(Icons.add_link_outlined),
              label: const Text('Transportni partiyaga bog‘lash')),
          ],
          if (mode == 'registered') ...[
            const Text('Yangi partiyalar',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            for (final group in groups) _groupTile(group,transports,savedLines),
            if(unlinkedDates.isNotEmpty) ...[
              const SizedBox(height:12),
              const Text('Eski qayd qilingan partiyalar',
                style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
              const SizedBox(height:7),
              for(final date in unlinkedDates)
                _legacyDateBatchTile(date,unlinkedByDate[date]!),
            ],
            const SizedBox(height: 12),
            const Text('Kitobma-kitob aniq kirim',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('Yetib kelgan partiyaning kitob nomi, dona soni va '
              'tannarxi aniq bo‘lsa shu bo‘limga yoziladi. '
              'Moliya xarajatiga avtomatik ikkinchi marta qo‘shilmaydi.',
              style: TextStyle(color: UzbekCustomerColors.textMuted,
                fontSize: 12, height: 1.4)),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: widget.onAdd,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Aniq partiya kitobini qo‘shish')),
            const SizedBox(height: 10),
            FutureBuilder<List<dynamic>>(
              future: widget.registered,
              builder: (ctx,snap) {
                if (snap.hasError) return Text('Xato: ${snap.error}');
                if (!snap.hasData) return const Center(
                  child: CircularProgressIndicator());
                final rows = _items(snap.data);
                if (rows.isEmpty) return const Card(
                  child: Padding(padding: EdgeInsets.all(20),
                    child: Text('Hozircha har bir kitobning aniq partiya '
                    'miqdori va xarid narxi bilan tasdiqlangan yozuv yo‘q.')));
                return Column(children: [
                  for (final item in rows) _registeredTile(item),
                ]);
              },
            ),
          ],
        ],
      );
    },
  );
}
