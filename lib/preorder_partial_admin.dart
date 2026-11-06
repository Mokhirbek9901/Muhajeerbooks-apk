part of 'admin_ui.dart';

/// Isolated partial-arrival flow. Ordinary preorder/admin screens stay intact.
/// The server validates stock, original request indices and deposit allocation.
class _PartialPreorderAdminPage extends StatefulWidget {
  const _PartialPreorderAdminPage({required this.api, required this.id});
  final _AdminApi api;
  final String id;
  @override
  State<_PartialPreorderAdminPage> createState() => _PartialPreorderAdminPageState();
}

class _PartialPreorderAdminPageState extends State<_PartialPreorderAdminPage> {
  Map<String, dynamic>? detail;
  List<Book> catalog = [];
  final selectedArrival = <int>{};
  final selectedMissing = <int>{};
  final chosenBooks = <int, Book>{};
  final quantities = <int, TextEditingController>{};
  final prices = <int, TextEditingController>{};
  bool busy = false;
  String? error;

  List<Map<String, dynamic>> get originals =>
      (detail?['original_items'] as List? ?? const [])
          .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();

  List<Map<String, dynamic>> get batches =>
      (detail?['batches'] as List? ?? const [])
          .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();

  List<Map<String, dynamic>> get missing =>
      (detail?['missing_items'] as List? ?? const [])
          .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();

  bool get activeBatch => batches.any((v) =>
      const ['prepared', 'awaiting_payment', 'proof_submitted', 'completed']
          .contains(v['status']));

  int requestedQty(int index) =>
      (originals[index]['quantity'] as num?)?.toInt() ?? 0;

  int arrivedQty(int index) {
    var qty = 0;
    for (final batch in batches) {
      if (batch['status'] == 'cancelled') continue;
      for (final raw in (batch['items'] as List? ?? const [])) {
        if (raw is Map && (raw['index'] as num?)?.toInt() == index) {
          qty += (raw['quantity'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return qty;
  }

  int missingQty(int index) {
    var qty = 0;
    for (final m in missing) {
      if ((m['index'] as num?)?.toInt() == index) {
        qty += (m['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return qty;
  }

  int remaining(int index) =>
      (requestedQty(index) - arrivedQty(index) - missingQty(index)).clamp(0, 100000);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    for (final c in quantities.values) c.dispose();
    for (final c in prices.values) c.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final values = await Future.wait<dynamic>([
        widget.api.releasePreorder('web', widget.id, 'partial_detail'),
        widget.api.books(),
      ]);
      if (!mounted) return;
      setState(() {
        detail = Map<String, dynamic>.from(values[0] as Map);
        catalog = (values[1] as List).cast<Book>();
        error = null;
        selectedArrival.clear();
        selectedMissing.clear();
        for (var i = 0; i < originals.length; i++) {
          quantities.putIfAbsent(i, () => TextEditingController());
          prices.putIfAbsent(i, () => TextEditingController());
          if (quantities[i]!.text.isEmpty) quantities[i]!.text = remaining(i).toString();
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<Book?> _chooseBook() async {
    final available = catalog.where((b) => b.isActive && b.stock > 0).toList();
    var query = '';
    return showModalBottomSheet<Book>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, update) {
        final matching = available.where((b) =>
            b.title.toLowerCase().contains(query.toLowerCase())).toList();
        return SafeArea(child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .68,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(14), child: TextField(
              decoration: const InputDecoration(
                labelText: 'Katalogdan kelgan kitobni tanlang',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => update(() => query = v),
            )),
            Expanded(child: ListView.builder(
              itemCount: matching.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(matching[i].title),
                subtitle: Text('Omborda: ' + matching[i].stock.toString() + ' ta'),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => Navigator.pop(sheet, matching[i]),
              ),
            )),
          ]),
        ));
      }),
    );
  }

  Future<void> _run(String action, Map<String, dynamic> payload, String question) async {
    if (busy) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Tasdiqlash'),
      content: Text(question),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ortga')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tasdiqlash')),
      ],
    ));
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.api.releasePreorder('web', widget.id, 'partial_' + action, payload);
      await _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Server saqladi. Mijozga bildirishnoma navbatga qo‘shildi.'),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Amal bajarilmadi: ' + e.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _sendArrived() {
    if (selectedArrival.isEmpty) return;
    final items = <Map<String, dynamic>>[];
    for (final index in selectedArrival.toList()..sort()) {
      final book = chosenBooks[index];
      final q = int.tryParse(quantities[index]?.text ?? '') ?? 0;
      final price = int.tryParse(prices[index]?.text ?? '') ?? 0;
      if (book == null || q < 1 || q > remaining(index) ||
          price < 1 || book.stock < q) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text((originals[index]['book_title'] ?? 'Kitob').toString() +
              ': katalog kitobi, soni, narxi va omborni tekshiring.'),
        ));
        return;
      }
      items.add({'index': index, 'book_id': book.id,
        'quantity': q, 'unit_price': price});
    }
    _run('prepare', {'items': items},
      'Tanlangan ' + items.length.toString() +
      ' turdagi kelgan kitob mijozga yuboriladi. ' +
      'Barcha ishlatilmagan avans faqat shu kelgan kitoblar va yetkazish hisobiga ayriladi. ' +
      'Kelmagan kitoblar alohida qoladi.');
  }

  void _sendMissing() {
    if (selectedMissing.isEmpty) return;
    _run('missing', {'indices': selectedMissing.toList()..sort()},
      'Tanlangan kelmagan kitoblar haqida mijozga alohida xabar yuborilsinmi? ' +
      'Ularni keyin yangi oldindan buyurtma bilan qayta zakaz qilish mumkin. ' +
      'Bu amal avansga yoki ombordagi mavjud kitoblarga tegmaydi.');
  }

  Widget _line(int index, {required bool forArrival}) {
    final raw = originals[index];
    final title = (raw['book_title'] ?? raw['title'] ?? 'Kitob').toString();
    final isSelected = forArrival
        ? selectedArrival.contains(index) : selectedMissing.contains(index);
    final available = remaining(index);
    return Card(child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: isSelected,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('So‘ralgan: ' + requestedQty(index).toString() + ' dona · ' +
              'Kelgan: ' + arrivedQty(index).toString() +
              ' · Kelmagan deb yuborilgan: ' + missingQty(index).toString() +
              ' · Qolgan: ' + available.toString()),
          onChanged: busy ? null : (v) => setState(() {
            final set = forArrival ? selectedArrival : selectedMissing;
            if (v == true) set.add(index); else set.remove(index);
          }),
        ),
        if (forArrival && isSelected) ...[
          Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
            onPressed: busy ? null : () async {
              final b = await _chooseBook();
              if (b == null || !mounted) return;
              setState(() {
                chosenBooks[index] = b;
                prices[index]!.text = b.currentPrice.toString();
              });
            },
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(chosenBooks[index]?.title ?? 'Katalog kitobini tanlash'),
          )),
          Row(children: [
            Expanded(child: TextField(controller: quantities[index],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kelgan dona'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: prices[index],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '1 dona narxi ₩'))),
          ]),
        ],
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = detail;
    return Scaffold(
      appBar: AppBar(title: const Text('Qisman kelgan kitoblar'),
          actions: [IconButton(onPressed: busy ? null : _reload,
              icon: const Icon(Icons.refresh))]),
      body: d == null
          ? Center(child: Text(error ?? 'Yuklanmoqda…'))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('Mijoz: ' + (d['customer_name'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('Buyurtma: ' + widget.id.substring(0, 8)),
              const SizedBox(height: 8),
              const Text('Kelgan kitoblar', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
              if (!activeBatch) ...[
                const Text('Avval kelganlarini tanlang, katalogdan kitobni ko‘rsating.'),
                for (var i = 0; i < originals.length; i++)
                  if (remaining(i) > 0) _line(i, forArrival: true),
                FilledButton.icon(onPressed: busy ? null : _sendArrived,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Shu kitoblar keldi')),
              ] else ...[
                for (final batch in batches)
                  if (batch['status'] != 'cancelled')
                    Card(child: Column(children: [
                      ListTile(title: const Text('Keldi'),
                        subtitle: Text('Holat: ' + batch['status'].toString())),
                      for (final raw in (batch['items'] as List? ?? const []))
                        if (raw is Map) ListTile(
                          title: Text((raw['title'] ?? raw['requested_title'] ?? 'Kitob').toString()),
                          trailing: Text((raw['quantity'] ?? '').toString() + ' dona'),
                        ),
                    ])),
                if (batches.any((b) => b['status'] == 'prepared'))
                  OutlinedButton(
                    onPressed: busy ? null : () => _run('cancel_prepare', {},
                      'Mijoz hali to‘lovni boshlamagan bo‘lsa, kelgan kitoblar omborga qaytariladi.'),
                    child: const Text('Kelganlarni belgilashni bekor qilish')),
              ],
              const SizedBox(height: 20),
              const Text('Kelmagan kitoblar', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
              if (!activeBatch)
                const Text('Avval kelgan kitoblarni mijozga yuboring.'),
              if (activeBatch) ...[
                for (var i = 0; i < originals.length; i++)
                  if (remaining(i) > 0) _line(i, forArrival: false),
                if (selectedMissing.isNotEmpty)
                  FilledButton.icon(onPressed: busy ? null : _sendMissing,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Tanlangan kitoblar kelmadi')),
                for (final raw in missing)
                  if (raw is Map)
                    ListTile(
                      leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                      title: Text((raw['book_title'] ?? raw['title'] ?? 'Kitob').toString()),
                      subtitle: const Text('Kelmagan — mijozga xabar yuborilgan'),
                    ),
              ],
              const SizedBox(height: 18),
              for (final batch in batches)
                if (batch['status'] == 'proof_submitted' ||
                    (batch['status'] == 'awaiting_payment' &&
                     ((batch['amount_due'] as num?)?.toInt() ?? 0) == 0))
                  FilledButton(
                    onPressed: busy ? null : () => _run('confirm', {},
                      'Mijoz to‘lovi va manzilini tekshirdingizmi? ' +
                      'Tasdiqlangach kelgan kitoblar jo‘natiladigan buyurtmaga o‘tadi.'),
                    child: const Text('To‘lovni tasdiqlash • jo‘natishga o‘tkazish')),
              if (busy) const LinearProgressIndicator(),
            ]),
    );
  }
}
