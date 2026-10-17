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
    overview = Supabase.instance.client.rpc('admin_web_batch_overview',
      params: {'p_secret': widget.secret}).then((raw) {
        return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      });
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

  Widget _purchaseTile(Map<String, dynamic> item, int index) {
    final title = (item['title'] ?? 'Kitob xaridi').toString();
    final verified = item['item_breakdown_verified'] == true;
    final isOpeningStock = item['source'] == 'opening_stock_baseline';
    final posted = item['posted_date']?.toString();
    final bought = item['purchase_date']?.toString();
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
            : 'Xarid: ${_batchDate(bought)} • Moliya qaydi',
          style: const TextStyle(fontSize: 12))),
        trailing: Text(_batchMoney(_batchNum(item['total_krw'])),
          style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w900, color: UzbekCustomerColors.navy)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          _detail(isOpeningStock ? 'Boshlang‘ich qoldiq qiymati'
              : 'Umumiy xarid summasi',
            _batchMoney(_batchNum(item['total_krw']))),
          _detail('Xarid sanasi', _batchDate(bought)),
          if (posted != bought)
            _detail('Moliyaga kiritilgan sana', _batchDate(posted)),
          _detail('Manba', isOpeningStock
            ? 'Moliya → Avvaldan qolgan kitoblar'
            : 'Moliya → Yangi partiya kitoblar'),
          _detail('Kitoblar tarkibi',
            verified ? 'Tasdiqlangan' : 'Kitobma-kitob tasdiqlanmagan'),
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
        subtitle: Text('${_batchDate(item['purchased_at'])} • $qty dona'),
        trailing: Text(_batchMoney(qty * cost),
          style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
        children: [
          _detail('Dona soni', '$qty'),
          _detail('Bir dona tannarx', _batchMoney(cost)),
          _detail('Jami', _batchMoney(qty * cost)),
          _detail('Rejalangan sotuv narxi',
            _batchMoney(_batchNum(item['suggested_price']))),
          if ((item['note'] ?? '').toString().trim().isNotEmpty)
            _detail('Izoh', (item['note'] ?? '').toString()),
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
      final purchases = _items(data['purchases']);
      final inventory = _items(data['inventory']);
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
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _metric('Moliya xarid yozuvlari',
              '${realPurchases.length} ta', Icons.receipt_long_outlined),
            _metric('Yangi xaridlar summasi',
              _batchMoney(purchaseSum), Icons.account_balance_wallet_outlined),
            _metric('Boshlang‘ich qoldiq qaydi',
              _batchMoney(openingValue), Icons.bookmark_border_rounded,
              footnote: 'Yangi partiya xaridiga qo‘shilmaydi'),
            _metric('Hozirgi ombor',
              '${inventory.length} nom / $stockQty dona',
              Icons.inventory_2_outlined,
              footnote: 'Tannarxi: ${_batchMoney(stockValue)}'),
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
              ChoiceChip(label: Text('Moliya qaydlari (${purchases.length})'),
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
              _purchaseTile(shownPurchases[i],i),
          ],
          if (mode == 'inventory') ...[
            if (shownInventory.isEmpty)
              const Padding(padding: EdgeInsets.all(24),
                child: Text('Mos kitob yo‘q')),
            for (final item in shownInventory) _inventoryTile(item),
          ],
          if (mode == 'registered') ...[
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
