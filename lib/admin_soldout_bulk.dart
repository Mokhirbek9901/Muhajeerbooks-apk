part of 'admin_ui.dart';

/// Owner-only, per-book advance sales for titles with zero physical stock.
/// The server keeps a private registry so "Clear all" does not touch other
/// independently configured or already accepted preorder flows.
class _SoldoutPreorderBulkPage extends StatefulWidget {
  const _SoldoutPreorderBulkPage({required this.api});

  final _AdminApi api;

  @override
  State<_SoldoutPreorderBulkPage> createState() => _SoldoutPreorderBulkPageState();
}

class _SoldoutPreorderBulkPageState extends State<_SoldoutPreorderBulkPage> {
  final _search = TextEditingController();
  final Set<String> _selected = <String>{};
  final Map<String, DateTime> _dates = <String, DateTime>{};
  final Map<String, TextEditingController> _deposits =
      <String, TextEditingController>{};

  List<Book> _books = <Book>[];
  bool _loading = true;
  bool _busy = false;
  bool _globalEnabled = false;
  int _savedCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    for (final c in _deposits.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booksRequest = widget.api.books();
      final settingsRequest = widget.api.soldoutPreorderBulk();
      final all = await booksRequest;
      final settings = await settingsRequest;
      if (!mounted) return;

      final managed = ((settings['managed'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
      final managedIds = managed.map((entry) => '${entry['id']}').toSet();
      final soldout = all
          .where(
            (b) =>
                b.isActive &&
                b.stock == 0 &&
                b.price > 0 &&
                (!b.preorderEnabled || managedIds.contains(b.id)),
          )
          .toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      for (final controller in _deposits.values) {
        controller.dispose();
      }
      _deposits.clear();
      _dates.clear();
      _selected.clear();

      final initialDay = DateUtils.dateOnly(DateTime.now()).add(
        const Duration(days: 14),
      );
      final byId = <String, Map<String, dynamic>>{
        for (final row in managed) '${row['id']}': row,
      };
      for (final book in soldout) {
        final stored = byId[book.id];
        if (stored != null) _selected.add(book.id);
        final rawDate = stored?['date']?.toString() ?? '';
        final parsed = DateTime.tryParse(rawDate);
        _dates[book.id] = parsed != null &&
                !DateUtils.dateOnly(parsed).isBefore(DateUtils.dateOnly(DateTime.now()))
            ? DateUtils.dateOnly(parsed)
            : initialDay;
        _deposits[book.id] = TextEditingController(
          text: '${stored?['deposit'] ?? (book.preorderDepositMin >= 1000 ? book.preorderDepositMin : 5000)}',
        );
      }
      setState(() {
        _books = soldout;
        _savedCount = managed.length;
        _globalEnabled = settings['global_enabled'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectDate(String bookId) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = _dates[bookId] ?? today.add(const Duration(days: 14));
    final value = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      initialDate: current.isBefore(today) ? today : current,
      helpText: 'Kitobning taxminiy kelish sanasi',
      confirmText: 'Tanlash',
      cancelText: 'Bekor qilish',
    );
    if (value != null && mounted) {
      setState(() => _dates[bookId] = DateUtils.dateOnly(value));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(text),
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
    );
    return result == true;
  }

  Future<void> _apply() async {
    if (_busy || _loading) return;
    final now = DateUtils.dateOnly(DateTime.now());
    final rows = <Map<String, dynamic>>[];
    for (final book in _books.where((b) => _selected.contains(b.id))) {
      final amount = int.tryParse(
        _deposits[book.id]?.text.trim().replaceAll(',', '') ?? '',
      );
      final arrival = _dates[book.id];
      if (amount == null || amount < 1000 || amount > 1000000 ||
          arrival == null || arrival.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${book.title}: kelish sanasi va avansni (₩1,000–₩1,000,000) tekshiring.',
            ),
          ),
        );
        return;
      }
      rows.add({
        'id': book.id,
        'date': DateFormat('yyyy-MM-dd').format(arrival),
        'deposit': amount,
      });
    }
    if (!await _confirm(
      title: 'Oldindan sotuvni saqlash',
      text: '${rows.length} ta tanlangan kitob oldindan sotuvga qo‘yiladi. '
          'Bu bo‘limda avval tanlangan, lekin hozir belgilanmagan kitoblar '
          'oldindan sotuvdan olinadi. Umumiy avtomatik tugagan-kitoblar '
          'rejimi o‘chiriladi; boshqa maxsus oldindan sotuvlar va '
          'oldingi mijoz buyurtmalari saqlanadi.',
      action: 'Saqlash',
    ) || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.api.soldoutPreorderBulk(
        mode: 'apply',
        rows: rows,
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['saved'] ?? rows.length} ta kitob oldindan sotuv uchun saqlandi.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saqlashda xatolik: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy || _loading || _savedCount == 0 && !_globalEnabled) return;
    if (!await _confirm(
      title: 'Barcha tanlangan kitoblarni olib tashlash',
      text: 'Ushbu yangi bo‘lim orqali oldindan sotuvga chiqarilgan '
          '$_savedCount ta kitob bir vaqtning o‘zida oldindan sotuvdan '
          'olinadi. Umumiy tugagan-kitoblar rejimi ham o‘chiriladi. '
          'Boshqa maxsus oldindan sotuvlar va qabul qilingan buyurtmalar '
          'o‘chirilmaydi.',
      action: 'Hammasini o‘chirish',
    ) || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.soldoutPreorderBulk(mode: 'clear');
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanlangan oldindan sotuvlar yopildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('O‘chirishda xatolik: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchTerm = _search.text.trim().toLowerCase();
    final visible = _books.where((b) =>
        searchTerm.isEmpty || b.title.toLowerCase().contains(searchTerm)).toList();

    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        title: const Text('Tugaganlarni oldindan sotuvga'),
        backgroundColor: UzbekCustomerColors.background,
        actions: [
          IconButton(
            tooltip: 'Qayta yuklash',
            onPressed: _busy ? null : () => unawaited(_refresh()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ma’lumot yuklanmadi: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Qayta urinish'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selected.length} ta tanlangan • $_savedCount ta hozir faol',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Omborda 0 ta qolgan kitoblarni birma-bir tanlang. '
                            'Har biriga kelish sanasi va avansni kiriting. '
                            'Oldingi buyurtmalarga tegilmaydi.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          if (_globalEnabled)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Diqqat: hozir umumiy avtomatik oldindan sotuv yoqilgan. '
                                'Saqlash bilan faqat tanlangan kitoblar rejimiga o‘tiladi.',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Kitob nomini qidirish',
                              prefixIcon: Icon(Icons.search_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text('Tugagan kitob topilmadi.'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final book = visible[index];
                                final checked = _selected.contains(book.id);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          controlAffinity: ListTileControlAffinity.leading,
                                          title: Text(
                                            book.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Omborda 0 ta • Narx: ${_won(book.price)}',
                                          ),
                                          value: checked,
                                          onChanged: _busy
                                              ? null
                                              : (value) => setState(() {
                                                    if (value == true) {
                                                      _selected.add(book.id);
                                                    } else {
                                                      _selected.remove(book.id);
                                                    }
                                                  }),
                                        ),
                                        if (checked)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _selectDate(book.id),
                                                  icon: const Icon(Icons.calendar_month_outlined),
                                                  label: Text(
                                                    'Taxminiy kelishi: ${DateFormat('yyyy-MM-dd').format(_dates[book.id]!)}',
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller: _deposits[book.id],
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Avans summasi (₩)',
                                                    border: OutlineInputBorder(),
                                                    prefixIcon: Icon(Icons.payments_outlined),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _apply,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(_busy ? 'Saqlanmoqda…' : 'Tanlanganlarni saqlash'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _clear,
                              icon: const Icon(Icons.delete_sweep_outlined),
                              label: const Text('Hammasini o‘chirish'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
