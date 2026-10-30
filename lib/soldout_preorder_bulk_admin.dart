part of 'admin_ui.dart';

/// Explicit, per-book restock preorders. Existing paid preorders and regular
/// books are never deleted. Only the books managed by this screen can be reset.
class _SoldoutPreorderBulkPage extends StatefulWidget {
  const _SoldoutPreorderBulkPage({required this.api});
  final _AdminApi api;

  @override
  State<_SoldoutPreorderBulkPage> createState() => _SoldoutPreorderBulkPageState();
}

class _SoldoutPreorderBulkPageState extends State<_SoldoutPreorderBulkPage> {
  final query = TextEditingController();
  final Set<String> chosen = <String>{};
  final Map<String, TextEditingController> amounts =
      <String, TextEditingController>{};
  final Map<String, DateTime> arrivals = <String, DateTime>{};
  List<Book> candidates = <Book>[];
  bool loading = true;
  bool saving = false;
  bool globalEnabled = false;
  String? failure;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    query.dispose();
    for (final controller in amounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final booksRequest = widget.api.books();
      final statusRequest = widget.api._rpc(
        'admin_soldout_preorder_bulk',
        params: {'p_secret': widget.api.secret, 'p_mode': 'list'},
      );
      final books = await booksRequest;
      final raw = await statusRequest;
      final status = Map<String, dynamic>.from(raw as Map);
      final managed = ((status['managed'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final managedIds = managed
          .map((row) => (row['id'] ?? '').toString())
          .toSet();
      final available = books
          .where((book) =>
              book.isActive &&
              book.stock == 0 &&
              book.price > 0 &&
              (!book.preorderEnabled || managedIds.contains(book.id)))
          .toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      for (final controller in amounts.values) {
        controller.dispose();
      }
      amounts.clear();
      arrivals.clear();
      chosen.clear();
      for (final row in managed) {
        final id = (row['id'] ?? '').toString();
        if (!available.any((book) => book.id == id)) continue;
        chosen.add(id);
        final date = DateTime.tryParse((row['date'] ?? '').toString());
        if (date != null) arrivals[id] = date;
        amounts[id] = TextEditingController(text: '${row['deposit'] ?? 5000}');
      }
      if (!mounted) return;
      setState(() {
        candidates = available;
        globalEnabled = status['global_enabled'] == true;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        failure = error.toString();
        loading = false;
      });
    }
  }

  void _toggle(Book book, bool value) {
    setState(() {
      if (value) {
        chosen.add(book.id);
        amounts.putIfAbsent(
          book.id,
          () => TextEditingController(text:
              book.preorderDepositMin > 0 ? '${book.preorderDepositMin}' : '5000'),
        );
      } else {
        chosen.remove(book.id);
      }
    });
  }

  Future<void> _pickDate(Book book) async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final current = arrivals[book.id];
    final initial = current != null && !current.isBefore(first) ? current : first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(first.year + 3, first.month, first.day),
      helpText: 'Taxminiy kelish sanasi',
    );
    if (picked != null && mounted) {
      setState(() => arrivals[book.id] = picked);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
          ],
        ),
      ) ?? false;

  Future<void> _save() async {
    if (saving) return;
    final rows = <Map<String, dynamic>>[];
    for (final book in candidates.where((b) => chosen.contains(b.id))) {
      final date = arrivals[book.id];
      final deposit = int.tryParse(amounts[book.id]?.text.trim() ?? '');
      if (date == null || deposit == null || deposit < 1000 ||
          deposit > 1000000) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${book.title}: kelish sanasi va avansni (₩1,000–₩1,000,000) kiriting.'),
        ));
        return;
      }
      rows.add({
        'id': book.id,
        'date': '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}',
        'deposit': deposit,
      });
    }
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avval kitob tanlang yoki “Hammasini o‘chirish”ni bosing.')),
      );
      return;
    }
    final yes = await _confirm(
      'Tanlangan kitoblarni saqlash',
      '${rows.length} ta kitob oldindan sotuvga chiqariladi. Avval tanlangan, ammo hozir belgilanmagan kitoblar yopiladi. Mavjud mijoz zakazlari o‘chmaydi.',
      'Saqlash',
    );
    if (!yes || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.api._rpc(
        'admin_soldout_preorder_bulk',
        params: {
          'p_secret': widget.api.secret,
          'p_mode': 'apply',
          'p_rows': rows,
        },
      );
      await context.read<AppState>().refreshBooks();
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanlangan kitoblar oldindan sotuvga chiqarildi ✅')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saqlashda xatolik: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _clear() async {
    if (saving) return;
    final yes = await _confirm(
      'Barcha tanlanganlarni yopish',
      'Faqat shu bo‘lim orqali yoqilgan oldindan sotuvlar o‘chiriladi. '
      'Oldingi mijoz buyurtmalari, avanslar va boshqa oldindan sotuv kitoblari saqlanadi.',
      'Hammasini yopish',
    );
    if (!yes || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.api._rpc(
        'admin_soldout_preorder_bulk',
        params: {'p_secret': widget.api.secret, 'p_mode': 'clear'},
      );
      await context.read<AppState>().refreshBooks();
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanlab yoqilgan oldindan sotuvlar yopildi.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('O‘chirishda xatolik: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = candidates.where((book) =>
        book.title.toLowerCase().contains(query.text.trim().toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugagan kitoblar — oldindan sotuv'),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            onPressed: saving ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : failure != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ma’lumot yuklanmadi: $failure'),
                    TextButton(onPressed: _refresh, child: const Text('Qayta urinish')),
                  ],
                ))
              : Column(
                  children: [
                    if (globalEnabled)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Eslatma: oldingi umumiy sozlama barcha tugagan kitoblarni ochgan. '
                          'Tanlanganlarni saqlaganingizda bu umumiy sozlama o‘chadi.',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: query,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Tugagan kitobni qidirish',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(
                            '${chosen.length} ta tanlangan · ${candidates.length} ta mavjud',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          )),
                          TextButton.icon(
                            onPressed: saving ? null : _clear,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hammasini o‘chirish'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Mos tugagan kitob topilmadi.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, index) {
                                final book = filtered[index];
                                final selected = chosen.contains(book.id);
                                final date = arrivals[book.id];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  child: Column(
                                    children: [
                                      CheckboxListTile(
                                        title: Text(book.title),
                                        subtitle: Text('Omborda: 0 · Narx: ${_won(book.price)}'),
                                        value: selected,
                                        onChanged: saving ? null : (v) => _toggle(book, v ?? false),
                                      ),
                                      if (selected)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                          child: Column(
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: saving ? null : () => _pickDate(book),
                                                icon: const Icon(Icons.calendar_month_outlined),
                                                label: Text(date == null
                                                    ? 'Kelish sanasini tanlang'
                                                    : 'Kelishi: ${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}'),
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: amounts[book.id],
                                                enabled: !saving,
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: 'Avans summasi (₩)',
                                                  prefixIcon: Icon(Icons.payments_outlined),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: saving ? null : _save,
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(saving
                                ? 'Saqlanmoqda...'
                                : 'Tanlanganlarni saqlash (${chosen.length})'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
