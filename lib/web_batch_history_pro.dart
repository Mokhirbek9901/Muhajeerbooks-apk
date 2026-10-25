import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';
import 'uzbek_customer_style.dart';

String _batchMoney(num value) => '₩${NumberFormat('#,###').format(value.round())}';
int _batchNum(dynamic value) => value is num ? value.round() : int.tryParse('$value') ?? 0;
String _batchDate(dynamic value) {
  final raw = (value ?? '').toString();
  if (raw.length < 10) return 'Sana ko‘rsatilmagan';
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw.substring(0, 10) : DateFormat('dd.MM.yyyy').format(parsed);
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
    ]).then((data) {
      final main = data[0] is Map
        ? Map<String,dynamic>.from(data[0] as Map) : <String,dynamic>{};
      final transport = data[1] is Map
        ? Map<String,dynamic>.from(data[1] as Map) : <String,dynamic>{};
      return {...main,
        'transport_records': transport['transports'] ?? [],
        'batch_groups': transport['groups'] ?? [],
        'saved_batch_lines': data[2] ?? [],
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
    return Card(margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        leading: const Icon(Icons.inventory_2_outlined,
          color: UzbekCustomerColors.teal),
        title: Text((item['title'] ?? 'Yangi partiya').toString(),
          style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${_batchDate(item['batch_date'])} • '
          '${lines.length} xil kitob · $count dona saqlangan'),
        trailing: Text(_batchMoney(books + transport),
          style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          _detail('Kiritilgan kitoblar tannarxi',_batchMoney(books)),
          _detail('Transport xarajatlari',_batchMoney(transport)),
          _detail('Kitob + transport (hisoblangan)',_batchMoney(books + transport)),
          const SizedBox(height: 12),
          const Align(alignment:Alignment.centerLeft,
            child:Text('Partiyaga saqlangan kitoblar',
              style:TextStyle(fontWeight:FontWeight.w900))),
          for(final line in lines) _savedBatchLine(line),
          if(lines.isEmpty) const Text(
            'Hali partiyaga kitoblar kiritilmagan.',
            style:TextStyle(fontSize:12,color:UzbekCustomerColors.textMuted)),
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
      ).toList();
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
        subtitle: Padding(padding: const EdgeInsets.only(top: 4),
          child: Text(isOpeningStock
            ? 'Boshlang‘ich qoldiq • Moliya qaydi'
            : grouped
              ? '${members.length} ta xarid birlashtirilgan • '
                '${_batchDate(bought)}'
              : 'Xarid: ${_batchDate(bought)} • Moliya qaydi',
          style: const TextStyle(fontSize: 12))),
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
          if (!grouped && posted != bought)
            _detail('Moliyaga kiritilgan sana', _batchDate(posted)),
          _detail('Manba', isOpeningStock
            ? 'Moliya → Avvaldan qolgan kitoblar'
            : grouped ? '${members.length} ta moliya xaridi birlashtirilgan'
            : 'Moliya → Kitob xaridi'),
          if (grouped) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Partiya ichidagi kitob xaridlari',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
            const SizedBox(height: 6),
            for (final member in members)
              _detail(
                '${_batchDate(member['purchase_date'])} · '
                '${member['title'] ?? 'Kitob xaridi'}',
                _batchMoney(_batchNum(member['total_krw'])),
              ),
          ] else
            _detail('Kitoblar tarkibi',
              verified ? 'Tasdiqlangan' : 'Kitobma-kitob tasdiqlanmagan'),
          const SizedBox(height:12),
          Text('Bu partiyaga kiritilgan: ${matchedLines.length} nomdagi kitob, $matchedQty dona',
            style:const TextStyle(fontWeight:FontWeight.w800)),
          for(final line in matchedLines) _savedBatchLine(line),
          if(matchedLines.isEmpty)
            const Text('Kitoblar soni hali tasdiqlanmagan. Partiyaga kitoblar qo‘shish tugmasidan foydalaning.',
              style:TextStyle(fontSize:12,color:UzbekCustomerColors.textMuted)),
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
              ChoiceChip(label: Text('Partiyalar (${purchases.length})'),
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
            if (shownPurchases.isEmpty)
              const Padding(padding: EdgeInsets.all(24),
                child: Text('Mos xarid yozuvi yo‘q')),
            for (var i=0;i<shownPurchases.length;i++)
              _purchaseTile(shownPurchases[i],i,transports,savedLines),
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
