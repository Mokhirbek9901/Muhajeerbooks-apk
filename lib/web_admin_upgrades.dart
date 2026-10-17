import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_state.dart';
import 'uzbek_customer_style.dart';

String webWon(num value) => '₩${NumberFormat('#,###').format(value.round())}';

class WebAdminApi {
  const WebAdminApi(this.secret);
  final String secret;
  Future<dynamic> call(String action, [Map<String,dynamic> data = const {}]) async {
    return Supabase.instance.client.rpc('admin_web_tools', params: {
      'p_secret': secret, 'p_action': action, 'p_payload': data,
    });
  }
}

class WebTodayWork extends StatelessWidget {
  const WebTodayWork({super.key, required this.books,
    required this.orders, required this.openTab});
  final List<Book> books;
  final List<ShopOrder> orders;
  final ValueChanged<int> openTab;
  @override
  Widget build(BuildContext context) {
    final newOrders = orders.where((x) => x.status == 'new').length;
    final waiting = orders.where((x) =>
      (x.status == 'accepted' || x.status == 'paid') &&
      x.preparedAt == null).length;
    final prepared = orders.where((x) =>
      (x.status == 'accepted' || x.status == 'paid') &&
      x.preparedAt != null).length;
    final low = books.where((x) => x.isActive && x.stock <= 2).length;
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bugungi ishlar', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900,
          color: UzbekCustomerColors.navy)),
        const SizedBox(height: 4),
        const Text('Bajarilishi kerak bo‘lgan amallar',
          style: TextStyle(color: UzbekCustomerColors.textMuted)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(avatar: const Icon(Icons.notifications_active_outlined, size: 17),
            label: Text('Yangi buyurtmalar: $newOrders'), onPressed: () => openTab(3)),
          ActionChip(avatar: const Icon(Icons.inventory_2_outlined, size: 17),
            label: Text('Qadoqlash: $waiting'), onPressed: () => openTab(3)),
          ActionChip(avatar: const Icon(Icons.local_shipping_outlined, size: 17),
            label: Text('Jo‘natishga tayyor: $prepared'),
            onPressed: () => openTab(3)),
          ActionChip(avatar: const Icon(Icons.warning_amber_rounded, size: 17),
            label: Text('Kam qolgan: $low'), onPressed: () => openTab(2)),
        ]),
      ]),
    ));
  }
}

class WebPackingPage extends StatefulWidget {
  const WebPackingPage({super.key, required this.order, required this.secret,
    required this.onPrepared});
  final ShopOrder order;
  final String secret;
  final VoidCallback onPrepared;
  @override
  State<WebPackingPage> createState() => _WebPackingPageState();
}
class _WebPackingPageState extends State<WebPackingPage> {
  Map<String,dynamic> checked = {};
  bool busy = false;
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final result = await WebAdminApi(widget.secret).call('packing_get',
        {'order_id': widget.order.id});
      if (mounted) setState(() {
        checked = Map<String,dynamic>.from(result as Map);
        loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tekshiruv ro‘yxati ochilmadi: $error')));
      }
    }
  }
  Future<void> _toggle(int index, bool value) async {
    if (busy) return;
    final old = {...checked};
    setState(() { checked['$index'] = value; busy = true; });
    try {
      await WebAdminApi(widget.secret).call('packing_save', {
        'order_id': widget.order.id, 'checked': checked,
      });
    } catch (error) {
      if (mounted) {
        setState(() => checked = old);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saqlanmadi: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final items = widget.order.items;
    final done = items.asMap().entries.where((e) => checked['${e.key}'] == true).length;
    final complete = items.isNotEmpty && done == items.length;
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(title: const Text('Qadoqlash tekshiruvi'),
        backgroundColor: UzbekCustomerColors.background),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: loading ? const Center(child: CircularProgressIndicator()) :
        ListView(padding: const EdgeInsets.all(18), children: [
          Card(child: Padding(padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Buyurtma №${widget.order.displayOrderNumber > 0 ? widget.order.displayOrderNumber : widget.order.id}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(widget.order.customerName),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: items.isEmpty ? 0 : done / items.length),
              const SizedBox(height: 8),
              Text('$done / ${items.length} turdagi kitob tekshirildi'),
            ]),
          )),
          for (final entry in items.asMap().entries)
            Card(child: CheckboxListTile(
              value: checked['${entry.key}'] == true,
              onChanged: busy ? null : (v) => _toggle(entry.key, v ?? false),
              title: Text((entry.value['title'] ?? 'Kitob').toString()),
              subtitle: Text('Miqdor: ${entry.value['quantity'] ?? 1} dona. Qutiga joylanganidan keyin belgilang.'),
              controlAffinity: ListTileControlAffinity.leading,
            )),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: !complete || busy ? null : () {
              widget.onPrepared();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.verified_rounded),
            label: const Text('Jo‘natishga tayyor'),
          ),
          const SizedBox(height: 8),
          const Text('Barcha kitoblar tasdiqlanmaguncha buyurtma tayyor deb belgilanmaydi.',
            style: TextStyle(fontSize: 12)),
        ]),
      )),
    );
  }
}

class WebAdminToolsPage extends StatelessWidget {
  const WebAdminToolsPage({super.key, required this.secret, required this.books});
  final String secret;
  final List<Book> books;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        title: const Text('Biznes asboblari'),
        backgroundColor: UzbekCustomerColors.background,
        bottom: const TabBar(isScrollable: true, tabs: [
          Tab(text: 'Narx kalkulyatori'),
          Tab(text: 'Partiyalar tarixi'),
          Tab(text: 'O‘zgarishlar tarixi'),
          Tab(text: 'Server xarajatlari'),
        ]),
      ),
      body: TabBarView(children: [
        const _WebPriceCalculator(),
        _WebBatchesPanel(secret: secret, books: books),
        _WebHistoryPanel(secret: secret),
        _WebServerBudgetPanel(secret: secret),
      ]),
    ),
  );
}

class _WebPriceCalculator extends StatefulWidget {
  const _WebPriceCalculator();
  @override
  State<_WebPriceCalculator> createState() => _WebPriceCalculatorState();
}
class _WebPriceCalculatorState extends State<_WebPriceCalculator> {
  final sum = TextEditingController(text: '80000');
  final rate = TextEditingController(text: '80000');
  final weight = TextEditingController(text: '0.5');
  final freight = TextEditingController(text: '10000');
  final packaging = TextEditingController(text: '500');
  final margin = TextEditingController(text: '30');
  @override
  void dispose() {
    for (final c in [sum, rate, weight, freight, packaging, margin]) { c.dispose(); }
    super.dispose();
  }
  Widget field(String label, TextEditingController controller) =>
    Padding(padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: controller, keyboardType:
        const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
  @override
  Widget build(BuildContext context) {
    final money = double.tryParse(sum.text) ?? 0;
    final fx = double.tryParse(rate.text) ?? 0;
    final kg = double.tryParse(weight.text) ?? 0;
    final perKg = double.tryParse(freight.text) ?? 0;
    final pack = double.tryParse(packaging.text) ?? 0;
    final percent = double.tryParse(margin.text) ?? 0;
    final cost = fx > 0 ? money * 10000 / fx + kg * perKg + pack : 0.0;
    final target = percent >= 0 && percent < 99 ? cost / (1 - percent / 100) : 0.0;
    final recommended = (target / 1000).ceil() * 1000;
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Kitob tannarxidan tavsiya narx', style:
        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      field('Kitobning O‘zbekistondagi narxi (so‘m)', sum),
      field('10 000 ₩ necha so‘m?', rate),
      field('Kitob vazni (kg)', weight),
      field('Koreyaga 1 kg tashish (₩)', freight),
      field('Qadoqlash va boshqa xarajat (₩)', packaging),
      field('Istalgan foyda marjasi (%)', margin),
      Card(color: const Color(0xFFE7F3ED),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Taxminiy tannarx: ${webWon(cost)}'),
            const SizedBox(height: 7),
            Text('Tavsiya sotuv narxi: ${webWon(recommended)}',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('Hisob-kitob avtomatik, narxni o‘zgartirish esa faqat admin tasdig‘i bilan.',
              style: TextStyle(fontSize: 12)),
          ],
        ))),
    ]);
  }
}

class _WebBatchesPanel extends StatefulWidget {
  const _WebBatchesPanel({required this.secret, required this.books});
  final String secret;
  final List<Book> books;
  @override
  State<_WebBatchesPanel> createState() => _WebBatchesPanelState();
}
class _WebBatchesPanelState extends State<_WebBatchesPanel> {
  late Future<List<dynamic>> rows;
  @override void initState() { super.initState(); _refresh(); }
  void _refresh() { rows = WebAdminApi(widget.secret).call('batches_list')
    .then((x) => x is List ? x : <dynamic>[]); }
  Future<void> _add() async {
    if (widget.books.isEmpty) return;
    var bookId = widget.books.first.id;
    final qty = TextEditingController(text: '1');
    final cost = TextEditingController();
    final price = TextEditingController();
    final note = TextEditingController();
    final yes = await showDialog<bool>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('Yangi partiyani ro‘yxatga olish'),
        content: SizedBox(width: 450, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: bookId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kitob'),
              items: widget.books.map((b) => DropdownMenuItem(
                value: b.id, child: Text(b.title, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) { if (v != null) update(() => bookId = v); }),
            TextField(controller: qty, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Partiyadagi dona')),
            TextField(controller: cost, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Har birining tannarxi (₩)')),
            TextField(controller: price, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rejadagi sotuv narxi (₩)')),
            TextField(controller: note, decoration: const InputDecoration(
              labelText: 'Izoh / yetib kelgan sana')),
          ]),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Saqlash')),
        ],
      )));
    if (yes == true && mounted) {
      try {
        await WebAdminApi(widget.secret).call('batch_add', {
          'book_id': bookId,
          'quantity': int.tryParse(qty.text) ?? 0,
          'unit_cost': int.tryParse(cost.text) ?? -1,
          'suggested_price': int.tryParse(price.text) ?? 0,
          'note': note.text.trim(),
        });
        if (mounted) setState(_refresh);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Partiya saqlanmadi: $e')));
      }
    }
    qty.dispose(); cost.dispose(); price.dispose(); note.dispose();
  }
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18), children: [
      const Text('Partiyalar tarixi', style: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('Bu partiya reestri alohida yuritiladi. Oldingi sotilgan kitoblar tannarxini o‘zgartirmaydi; ombor qoldig‘ini esa Ombor bo‘limida yangilang.',
        style: TextStyle(fontSize: 12)),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add),
        label: const Text('Partiya qo‘shish')),
      const SizedBox(height: 10),
      FutureBuilder<List<dynamic>>(future: rows, builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Text('Xatolik: ${snap.error}');
        if (snap.data!.isEmpty) return const Text('Partiya kiritilmagan.');
        return Column(children: [
          for (final raw in snap.data!.whereType<Map>())
            Card(child: ListTile(
              title: Text((raw['title'] ?? 'Kitob').toString()),
              subtitle: Text('${raw['purchased_at']} • ${raw['quantity']} dona • ${raw['note'] ?? ''}'),
              trailing: Text(webWon((raw['unit_cost'] as num?) ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w900)),
            )),
        ]);
      }),
    ]);
}

class _WebHistoryPanel extends StatelessWidget {
  const _WebHistoryPanel({required this.secret});
  final String secret;
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: WebAdminApi(secret).call('history_list'),
    builder: (ctx, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Tarixni ochib bo‘lmadi: ${snap.error}'));
      final rows = (snap.data as List?) ?? const [];
      return ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Kitob narxi va ombor o‘zgarishlari',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Yangi qaydlar avtomatik yoziladi. Migratsiyadan oldingi tarix o‘zgartirilmaydi.',
          style: TextStyle(fontSize: 12)),
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(20),
          child: Text('Hali yangi o‘zgarish yo‘q.')),
        for (final raw in rows.whereType<Map>())
          Card(child: ListTile(
            title: Text((raw['book_title'] ?? '').toString()),
            subtitle: Text((raw['created_at'] ?? '').toString()),
            onTap: () => showDialog<void>(context: ctx,
              builder: (c) => AlertDialog(
                title: const Text('Oldingi va yangi qiymatlar'),
                content: SelectableText('Oldin: ${raw['before_value']}\nKeyin: ${raw['after_value']}'),
                actions: [TextButton(onPressed: () => Navigator.pop(c),
                  child: const Text('Yopish'))])),
            trailing: const Icon(Icons.history_rounded),
          )),
      ]);
    });
}

class _WebServerBudgetPanel extends StatefulWidget {
  const _WebServerBudgetPanel({required this.secret});
  final String secret;
  @override
  State<_WebServerBudgetPanel> createState() => _WebServerBudgetPanelState();
}
class _WebServerBudgetPanelState extends State<_WebServerBudgetPanel> {
  final fields = List.generate(4, (_) => TextEditingController());
  bool loading = true;
  bool saving = false;
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { for (final c in fields) { c.dispose(); } super.dispose(); }
  Future<void> _load() async {
    try {
      final raw = await WebAdminApi(widget.secret).call('budget_get') as Map;
      for (var i = 0; i < fields.length; i++) {
        fields[i].text = (raw[
          ['supabase_budget','railway_budget','supabase_entered','railway_entered'][i]
        ] ?? 0).toString();
      }
    } catch (_) { /* No fictional usage values on failure. */ }
    if (mounted) setState(() => loading = false);
  }
  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final keys = ['supabase_budget','railway_budget','supabase_entered','railway_entered'];
      await WebAdminApi(widget.secret).call('budget_save', {
        for (var i=0;i<4;i++) keys[i]: double.tryParse(fields[i].text) ?? 0,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limit va qo‘lda kiritilgan summalar saqlandi')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final labels = [
      'Supabase oylik budjet (USD)',
      'Railway oylik budjet (USD)',
      'Supabase haqiqiy hisobdan kiritilgan summa (USD)',
      'Railway haqiqiy hisobdan kiritilgan summa (USD)',
    ];
    final supBudget = double.tryParse(fields[0].text) ?? 0;
    final railBudget = double.tryParse(fields[1].text) ?? 0;
    final supSpent = double.tryParse(fields[2].text) ?? 0;
    final railSpent = double.tryParse(fields[3].text) ?? 0;
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Server xarajatlari nazorati', style: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Bu ekran billing API bilan ulanmagan: summalarni Supabase va Railway hisobidan tekshirib, qo‘lda kiriting. Avtomatik real-time deb ko‘rsatilmaydi.',
        style: TextStyle(fontSize: 12)),
      const SizedBox(height: 12),
      if (supBudget > 0 && supSpent >= supBudget || railBudget > 0 && railSpent >= railBudget)
        const Card(color: Color(0xFFFFECE8),
          child: ListTile(leading: Icon(Icons.warning_amber_rounded),
            title: Text('Kiritilgan xarajat budjetdan oshdi!'))),
      for (var i=0;i<4;i++) Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: fields[i],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            border: const OutlineInputBorder(), labelText: labels[i]))),
      FilledButton.icon(onPressed: saving ? null : _save,
        icon: const Icon(Icons.save_outlined), label: const Text('Saqlash')),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => launchUrl(Uri.parse('https://supabase.com/dashboard'),
        mode: LaunchMode.externalApplication), child: const Text('Supabase hisobini ochish')),
      OutlinedButton(onPressed: () => launchUrl(Uri.parse('https://railway.com/dashboard'),
        mode: LaunchMode.externalApplication), child: const Text('Railway hisobini ochish')),
    ]);
  }
}
