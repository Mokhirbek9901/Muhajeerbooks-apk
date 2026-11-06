part of 'admin_ui.dart';

/// Validate one selected wave without changing any stock or advance.
/// The authoritative SQL routine repeats these checks under row locks.
@visibleForTesting
Map<String, dynamic> partialFoundSelectionRow({
  required int index,
  required String bookId,
  required int requestedRemaining,
  required int availableStock,
  required int quantity,
  required int unitPrice,
}) {
  if (index < 0 || bookId.trim().isEmpty ||
      quantity < 1 || quantity > 200 ||
      quantity > requestedRemaining || quantity > availableStock ||
      unitPrice < 1 || unitPrice > 10000000) {
    throw ArgumentError('Kelgan kitob miqdori yoki narxi noto‘g‘ri.');
  }
  return {
    'index': index,
    'book_id': bookId,
    'quantity': quantity,
    'unit_price': unitPrice,
  };
}

/// Always settle the found wave using the whole unused advance.
/// Neither admin UI nor older clients can select a keep-credit policy.
@visibleForTesting
Map<String,dynamic> partialAllAdvancePreparePayload(
  List<Map<String,dynamic>> items,
) {
  if(items.isEmpty) throw ArgumentError('Topilgan kitoblarni tanlang');
  return {'items': items, 'apply_all': true};
}

/// Admin workflow for a multi-title web preorder. A selected catalog title
/// must already have live stock. No customer order or payment is created by
/// opening this page. Preparing one wave reserves only selected stock.
class _AdminWebPreorderPartialPage extends StatefulWidget {
  const _AdminWebPreorderPartialPage({
    required this.api,
    required this.id,
    required this.customerTitle,
  });
  final _AdminApi api;
  final String id;
  final String customerTitle;

  @override
  State<_AdminWebPreorderPartialPage> createState() =>
      _AdminWebPreorderPartialPageState();
}

class _AdminWebPreorderPartialPageState
    extends State<_AdminWebPreorderPartialPage> {
  Map<String, dynamic>? detail;
  List<Book> catalog = [];
  final Map<int, Book> matched = {};
  final Map<int, TextEditingController> amounts = {};
  final Map<int, TextEditingController> prices = {};
  bool loading = true;
  bool saving = false;
  bool proofViewed = false;
  bool showMissing = false;
  final Set<int> missingSelection = {};
  String? error;

  int _num(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  TextEditingController _qty(int i) =>
      amounts.putIfAbsent(i, () => TextEditingController(text: '1'));
  TextEditingController _price(int i) =>
      prices.putIfAbsent(i, () => TextEditingController(text: '0'));

  Future<void> _load() async {
    try {
      final result = await Future.wait<dynamic>([
        widget.api.partialWebPreorder(widget.id, 'detail'),
        widget.api.books(),
      ]);
      if (!mounted) return;
      setState(() {
        detail = Map<String, dynamic>.from(result[0] as Map);
        catalog = List<Book>.from(result[1] as List);
        error = null;
        proofViewed = false;
        missingSelection.clear();
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        error = 'Qisman zakas yuklanmadi: $e';
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in amounts.values) { c.dispose(); }
    for (final c in prices.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickCatalog(int index) async {
    var query = '';
    final chosen = await showModalBottomSheet<Book>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, refresh) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.viewInsetsOf(sheet).bottom + 16),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheet).height * .65,
              child: Column(children: [
                const Text('Omborga kelgan kitobni katalogdan tanlang',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Kitob qidirish',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder()),
                  onChanged: (v) => refresh(() => query = v),
                ),
                const SizedBox(height: 8),
                Expanded(child: ListView(
                  children: catalog.where((book) =>
                    book.isActive && book.stock > 0 &&
                    book.title.toLowerCase().contains(query.toLowerCase()))
                    .map((book) => ListTile(
                      title: Text(book.title),
                      subtitle: Text(
                        'Omborda: ${book.stock} dona • Narx: ${_won(book.currentPrice)}'),
                      onTap: () => Navigator.pop(sheet, book),
                    )).toList(),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
    if (chosen != null && mounted) setState(() {
      matched[index] = chosen;
      _price(index).text = chosen.currentPrice.toString();
    });
  }

  List<Map<String, dynamic>> _pending() =>
    (detail?['items'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();

  List<Map<String, dynamic>> _batches() =>
    (detail?['batches'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();

  Map<String, dynamic>? get _activeBatch {
    for (final batch in _batches().reversed) {
      if (const {'prepared','awaiting_payment','proof_submitted'}
          .contains('${batch['status']}')) return batch;
    }
    return null;
  }

  /// Only a fully linked and quantitatively valid selection reaches server.
  List<Map<String, dynamic>> _selection() {
    final chosen = <Map<String,dynamic>>[];
    for (final line in _pending()) {
      final index = _num(line['index']);
      final book = matched[index];
      if (book == null) continue;
      final count = int.tryParse(_qty(index).text.trim()) ?? 0;
      final price = int.tryParse(_price(index).text.trim()) ?? 0;
      final remaining = _num(line['remaining_quantity']);
      try {
        chosen.add(partialFoundSelectionRow(
          index: index,
          bookId: book.id,
          requestedRemaining: remaining,
          availableStock: book.stock,
          quantity: count,
          unitPrice: price,
        ));
      } catch (_) {
        throw StateError(
          '“${line['book_title'] ?? line['title']}”: miqdor, ombor yoki narx noto‘g‘ri.');
      }
    }
    if (chosen.isEmpty) throw StateError(
      'Topilgan kitoblarni belgilang va katalogdan tanlang.');
    return chosen;
  }

  Future<bool> _approve(String title, String text, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog,false),
            child: const Text('Bekor')),
          FilledButton(
            onPressed: () => Navigator.pop(dialog,true),
            child: Text(action)),
        ],
      ),
    ) ?? false;

  Future<void> _prepare() async {
    if (saving) return;
    List<Map<String, dynamic>> items;
    try { items = _selection(); }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')));
      return;
    }
    final total = items.fold<int>(0, (sum,item) =>
      sum+_num(item['quantity'])*_num(item['unit_price']));
    final lines = items.map((item) {
      final index = _num(item['index']);
      final book = matched[index]!;
      return '${book.title}: ${item['quantity']} dona × ${_won(_num(item['unit_price']))}';
    }).join('\n');
    final confirmed = await _approve(
      'Shu kitoblar keldi — mijozga yuborish',
      '$lines\n\nKelgan kitoblar jami: ${_won(total)}\n'
      'Qolgan avans: ${_won(_num(detail?['deposit_remaining']))}\n\n'
      'Mijozning shu zakaz uchun hali ishlatilmagan AVANSI TO‘LIQ '
      'faqat topilgan kitoblar va ularning pochtasidan ayriladi. '
      'Mijozga qolgan summani va manzilni tasdiqlash ko‘rsatiladi. '
      'Topilmagan kitoblarni keyin qaytadan oldindan buyurtma qilishi mumkin. '
      'Faqat belgilangan kitoblar ombordan band qilinadi. '
      'Mijozga ilova xabari yaratiladi, push yetishi qurilma ruxsatiga bog‘liq.',
      'Shu kitoblar keldi',
    );
    if (!confirmed || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.api.partialWebPreorder(
        widget.id,'prepare',partialAllAdvancePreparePayload(items));
      if (!mounted) return;
      matched.clear();
      for(final c in amounts.values){c.dispose();}
      for(final c in prices.values){c.dispose();}
      amounts.clear(); prices.clear();
      await _load();
      if (mounted) setState(() => showMissing = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Topilgan kitoblar saqlandi. Mijozga xabar yaratildi; push yetkazilishi alohida tekshiriladi.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xabar yuborilmadi / saqlanmadi: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<Map<String, dynamic>> _missingRows() =>
    preorderMissingBookRows(detail ?? const <String, dynamic>{});

  bool get _hasReceived => _batches().any(
    (b) => b['status'] != 'cancelled');

  Future<void> _notifyMissing() async {
    if (saving || missingSelection.isEmpty || !_hasReceived) return;
    final selected = _missingRows()
      .where((row) => missingSelection.contains(_num(row['index'])) &&
          _num(row['unreported_quantity']) > 0)
      .toList();
    if (selected.length != missingSelection.length) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kelmagan kitoblar ro‘yxatini yangilang.')));
      return;
    }
    final names = selected.map((row) =>
      '${row['title']} — ${row['unreported_quantity']} dona').join('\n');
    if (!await _approve(
      'Tanlangan kitoblar kelmadi',
      'Quyidagi kitoblar hozircha kelmadi:\n$names\n\n'
      'Mijozga alohida bildirishnoma yuboriladi. '
      'Ularni keyinchalik qayta buyurtma qilishi mumkin. '
      'Avans, kelgan kitoblar va ombor o‘zgarmaydi.',
      'Kelmadi deb yuborish')) return;
    if (!mounted) return;
    setState(() => saving = true);
    try {
      await widget.api.partialWebPreorder(
        widget.id, 'missing',
        {'indices': selected.map((row) => _num(row['index'])).toList()});
      missingSelection.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Kelmagan kitoblar haqida mijozga alohida xabar yaratildi.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kelmaganlar yuborilmadi: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _cancel() async {
    if (saving) return;
    if (!await _approve(
      'Tayyorlovni bekor qilish',
      'Mijoz hali avans taqsimotini tanlamagan bo‘lsa '
      'band qilingan kitoblar omborga qaytariladi. '
      'To‘langan avans o‘zgarmaydi.',
      'Tayyorlovni bekor qilish')) return;
    if (!mounted) return;
    setState(() => saving = true);
    try {
      await widget.api.partialWebPreorder(widget.id,'cancel_prepare');
      if (mounted) await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bekor qilinmadi: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openBalanceProof() async {
    final batch = _activeBatch;
    if (batch == null) return;
    final path = '${batch['proof_path'] ?? ''}'.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mijozning to‘lov cheki hali yuborilmagan.')));
      return;
    }
    try {
      final url = await widget.api.paymentProofUrl(path);
      if (url.isEmpty || !await launchUrl(
        Uri.parse(url), mode: LaunchMode.externalApplication)) {
        throw StateError('To‘lov cheki ochilmadi');
      }
      if (mounted) setState(() => proofViewed = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chekni ochib bo‘lmadi: $e')));
    }
  }

  Future<void> _confirm() async {
    final b = _activeBatch;
    if (saving || b == null) return;
    final due = _num(b['amount_due']);
    final allowed = (due == 0 && b['status']=='awaiting_payment') ||
      b['status']=='proof_submitted';
    if (!allowed) return;
    if (due > 0 && !proofViewed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Avval qolgan to‘lov chekini ochib tekshiring.')));
      return;
    }
    if (!await _approve('To‘lovni tasdiqlash',
      'Qolgan to‘lov: ${_won(due)}. '
      'Faqat haqiqatan tekshirilgan chek yoki ₩0 qolgan to‘lovni '
      'tasdiqlang. Bu kitoblar alohida jo‘natma buyurtmasiga o‘tadi.',
      'Tasdiqlash')) return;
    if (!mounted) return;
    setState(() => saving = true);
    try {
      await widget.api.partialWebPreorder(widget.id,'confirm');
      if (mounted) await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kelgan kitoblar jo‘natishga o‘tkazildi.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tasdiqlanmadi: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _batchTitle(Map<String,dynamic> batch) {
    final items=(batch['items'] as List? ?? const []).whereType<Map>().toList();
    return items.map((x)=>'${x['requested_title']??x['title']}: ${x['quantity']} dona').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final pending=_pending(), batches=_batches(), active=_activeBatch;
    return Scaffold(
      appBar: AppBar(title: const Text('Qisman topilgan kitoblar'),
        actions: [IconButton(onPressed: saving ? null : _load,
          icon: const Icon(Icons.refresh),tooltip: 'Yangilash')]),
      body: loading ? const Center(child: CircularProgressIndicator())
      : error!=null ? Center(child: Text(error!))
      : ListView(padding: const EdgeInsets.all(16),children: [
        Text(widget.customerTitle,
          style: const TextStyle(fontSize:20,fontWeight: FontWeight.w900)),
        const SizedBox(height:8),
        Text('To‘langan avans: ${_won(_num(detail?['deposit_amount']))} • '
          'Hali ishlatilmagan: ${_won(_num(detail?['deposit_remaining']))}'),
        const SizedBox(height:10),
        const Text(
          'Faqat kelgan kitoblarni tanlang. Kelmaganlari kutilayotgan '
          'bu bosqichda jo‘natilmaydi. To‘langan avansning barchasi '
          'topilgan kitoblarga bir marta ishlatiladi. Qolgan kitoblarni '
          'keyin qayta oldindan zakaz qilish mumkin.',
          style: TextStyle(color:AppColors.muted)),
        if (detail?['closed']==true)
          const Padding(padding:EdgeInsets.only(top:12),
            child:Text('Bu zakazning qolgan qismi yopilgan. '
              'Qolgan kitoblar kerak bo‘lsa yangi zakaz qilinadi.')),
        if (_hasReceived)
          Row(children: [
            Expanded(child: showMissing
              ? OutlinedButton(
                  onPressed: () => setState(() => showMissing = false),
                  child: const Text('Keldi'))
              : FilledButton.tonal(
                  onPressed: () => setState(() => showMissing = false),
                  child: const Text('Keldi'))),
            const SizedBox(width: 8),
            Expanded(child: showMissing
              ? FilledButton.tonal(
                  onPressed: () => setState(() => showMissing = true),
                  child: const Text('Kelmagan'))
              : OutlinedButton(
                  onPressed: () => setState(() => showMissing = true),
                  child: const Text('Kelmagan'))),
          ]),
        if (!showMissing) ...[
        for (final batch in batches) Card(child: ListTile(
          title: Text(_batchTitle(batch)),
          subtitle: Text(
            'Holat: ${batch['status']}\n'
            'Kitoblar: ${_won(_num(batch['subtotal']))} • '
            'Pochta: ${_won(_num(batch['shipping_fee']))}\n'
            'Avansdan ayirildi: ${_won(_num(batch['deposit_applied']))} • '
            'Qolgan to‘lov: ${_won(_num(batch['amount_due']))}\n'
            'Qaytarilishi kerak: ${_won(_num(batch['refund_due']))}'),
          isThreeLine:true,
        )),
        if (active != null) ...[
          const SizedBox(height:12),
          OutlinedButton.icon(
            key: const Key('partial_copy_social_message'),
            onPressed: () async {
              final text =
                'Assalomu alaykum! Oldindan buyurtmangizdagi quyidagi '
                'kitoblar topildi: ${_batchTitle(active)}. '
                'To‘lagan avansingizning ishlatilmagan qismi shu '
                'kitoblar va ularning pochta haqidan to‘liq ayriladi. '
                'Qolgan to‘lovni ko‘rish va manzilni tasdiqlash uchun '
                'Muhajeer Books ilovasida “Oldindan zakaslarim”ga kiring. '
                'Topilmagan kitoblarni keyinchalik qayta zakas qilishingiz mumkin.';
              await Clipboard.setData(ClipboardData(text: text));
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Xabar nusxalandi. '
                  'Instagram/Telegram orqali o‘zingiz yuborishingiz mumkin.')));
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Instagram/Telegram xabarini nusxalash')),
          const SizedBox(height: 6),
          if (active['status']=='prepared') ...[
            const Text('Mijoz faqat manzilini va qolgan to‘lovni '
              'tasdiqlaydi. Barcha qolgan avans shu kelgan kitoblarga ishlatiladi. '
              'Topilmaganlarini keyinchalik qayta oldindan zakaz qilish mumkin.'),
            OutlinedButton.icon(
              onPressed:saving?null:_cancel,
              icon: const Icon(Icons.undo),
              label:const Text('Tayyorlovni bekor qilish')),
          ] else ...[
            const Text('Mijoz tanlovini saqlagan. Qolgan to‘lov '
              'va manzilni tekshiring.'),
            if (active['status']=='proof_submitted') ...[
              const Text('Mijoz qolgan to‘lov chekini yuborgan. '
                'Tasdiqlashdan oldin chekni tekshiring.'),
              OutlinedButton.icon(
                onPressed: saving ? null : _openBalanceProof,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Qolgan to‘lov chekini ko‘rish')),
            ],
            FilledButton.icon(
              onPressed: saving || !(
                (active['status']=='awaiting_payment' &&
                   _num(active['amount_due'])==0) ||
                (active['status']=='proof_submitted' &&
                  (proofViewed || _num(active['amount_due'])==0))) ? null : _confirm,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Qolgan to‘lovni tasdiqlash')),
          ],
        ],
        if (active==null && detail?['closed']!=true) ...[
          const Divider(height:26),
          const Text('Kelgan kitoblar',
            style: TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),
          for(final line in pending) if(_num(line['remaining_quantity'])>0)
            _pendingCard(line),
          const SizedBox(height:12),
          FilledButton.icon(
            key: const Key('admin_partial_send_found'),
            onPressed:saving?null:_prepare,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Shu kitoblar keldi — mijozga yuborish')),
        ],
        ],
        if (showMissing) ...[
          const SizedBox(height: 12),
          const Text('Kelmagan kitoblar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const Text('Avval kelgan kitoblarni mijozga yuboring. '
            'Keyin kelmaganlarini tanlab alohida xabar jo‘nating.'),
          for (final row in _missingRows())
            Card(child: CheckboxListTile(
              key: ValueKey('partial_missing_${row['index']}'),
              value: missingSelection.contains(_num(row['index'])),
              onChanged: saving || !_hasReceived ||
                _num(row['unreported_quantity']) <= 0
                  ? null
                  : (value) => setState(() {
                      final i = _num(row['index']);
                      if (value == true) missingSelection.add(i);
                      else missingSelection.remove(i);
                    }),
              title: Text(row['title'].toString()),
              subtitle: Text(
                'Kelmagan: ${row['remaining_quantity']} dona • '
                '${_num(row['reported_quantity']) > 0 ? 'Xabar yuborilgan' : 'Hali xabar yuborilmagan'}'),
              secondary: Icon(
                _num(row['reported_quantity']) > 0
                  ? Icons.cancel_outlined : Icons.schedule_outlined,
                color: _num(row['reported_quantity']) > 0
                  ? Colors.red : Colors.orange),
            )),
          if (_missingRows().isEmpty)
            const Text('Kelmagan kitob qolmadi.'),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('admin_partial_send_missing'),
            onPressed: saving || missingSelection.isEmpty
              ? null : _notifyMissing,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Tanlangan kitoblar kelmadi')),
        ],
        if (saving) const LinearProgressIndicator(),
      ]),
    );
  }

  Widget _pendingCard(Map<String,dynamic> line) {
    final index=_num(line['index']);
    final remaining=_num(line['remaining_quantity']);
    final linked=matched[index];
    return Card(
      child: Padding(padding:const EdgeInsets.all(12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('${line['book_title']??'Kitob'}',
            style:const TextStyle(fontWeight:FontWeight.w900)),
          Text('Kutilmoqda: $remaining dona',
            style:const TextStyle(color:AppColors.muted)),
          const SizedBox(height:6),
          OutlinedButton.icon(
            key:ValueKey('partial_select_catalog_$index'),
            onPressed:saving?null:()=>_pickCatalog(index),
            icon:const Icon(Icons.search),
            label:Text(linked==null
              ? 'Kelgan kitobni katalogdan tanlash'
              : '${linked.title} • ombor ${linked.stock} dona')),
          if(linked!=null) ...[
            Row(children:[
              Expanded(child:TextField(
                key:ValueKey('partial_qty_$index'),
                controller:_qty(index),
                keyboardType:TextInputType.number,
                decoration:const InputDecoration(labelText:'Topilgan miqdor'),
              )),
              const SizedBox(width:12),
              Expanded(child:TextField(
                key:ValueKey('partial_price_$index'),
                controller:_price(index),
                keyboardType:TextInputType.number,
                decoration:const InputDecoration(labelText:'Narx (₩)'),
              )),
              IconButton(
                tooltip:'Tanlovni olib tashlash',
                onPressed:()=>setState(()=>matched.remove(index)),
                icon:const Icon(Icons.close_rounded)),
            ]),
          ],
        ])),
    );
  }
}
