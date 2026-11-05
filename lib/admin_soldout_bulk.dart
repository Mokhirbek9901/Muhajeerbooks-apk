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
  final Map<String, DateTime> _endDates = <String, DateTime>{};
  final Map<String, TextEditingController> _deposits =
      <String, TextEditingController>{};

  List<Book> _books = <Book>[];
  List<Book> _activePreorders = <Book>[];
  Map<String, Map<String, dynamic>> _managedPreorders = {};
  bool _showActivePreorders = false;
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
      final activePreorders = all.where(
        (b) => b.isActive && (b.preorderEnabled || managedIds.contains(b.id)),
      ).toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
      _endDates.clear();
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
        final storedEnd = DateTime.tryParse(stored?['end_date']?.toString() ?? '');
        _endDates[book.id] = storedEnd != null &&
                !DateUtils.dateOnly(storedEnd).isBefore(_dates[book.id]!)
            ? DateUtils.dateOnly(storedEnd)
            : _dates[book.id]!;
        _deposits[book.id] = TextEditingController(
          text: '${stored?['deposit'] ?? (book.preorderDepositMin >= 1000 ? book.preorderDepositMin : 5000)}',
        );
      }
      setState(() {
        _books = soldout;
        _activePreorders = activePreorders;
        _managedPreorders = byId;
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

  Future<void> _selectDate(String bookId, {required bool end}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = _dates[bookId] ?? today.add(const Duration(days: 14));
    final earliest = end && start.isAfter(today) ? start : today;
    final latest = today.add(const Duration(days: 730));
    final saved = end ? (_endDates[bookId] ?? start) : start;
    final initial = saved.isBefore(earliest)
        ? earliest
        : saved.isAfter(latest) ? latest : saved;
    final value = await showDatePicker(
      context: context,
      firstDate: earliest,
      lastDate: latest,
      initialDate: initial,
      helpText: end
          ? 'Taxminiy kelishi: shu sanagacha'
          : 'Taxminiy kelishi: shu sanadan',
      confirmText: 'Tanlash',
      cancelText: 'Bekor qilish',
    );
    if (value != null && mounted) {
      setState(() {
        final selected = DateUtils.dateOnly(value);
        if (end) {
          _endDates[bookId] = selected;
        } else {
          _dates[bookId] = selected;
          if ((_endDates[bookId] ?? selected).isBefore(selected)) {
            _endDates[bookId] = selected;
          }
        }
      });
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

  Future<void> _editActivePreorder(Book book) async {
    if (_busy || _loading) return;
    final row = await _showPreorderActiveEditor(
      context, book, _managedPreorders[book.id],
    );
    if (row == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.soldoutPreorderBulk(
        mode: 'edit_one', rows: [row],
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${book.title}: sanasi va avansi saqlandi.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kitob tahrirlanmadi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeActivePreorder(Book book) async {
    if (_busy || _loading) return;
    final confirmed = await _confirm(
      title: 'Oldindan sotuvdan chiqarish',
      text: '“${book.title}” endi yangi oldindan zakaslarni '
        'qabul qilmaydi. Mijozlarning mavjud zakaslari, '
        'avanslari va to‘lov cheklari saqlanadi. '
        'Boshqa kitoblarning holati o‘zgarmaydi.',
      action: 'Sotuvdan olish',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.soldoutPreorderBulk(
        mode: 'remove_one', rows: [{'id': book.id}],
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${book.title} oldindan sotuvdan olindi.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sotuvdan olib bo‘lmadi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      final until = _endDates[book.id];
      if (amount == null || amount < 1000 || amount > 1000000 ||
          arrival == null || until == null || arrival.isBefore(now) ||
          until.isBefore(arrival) ||
          until.isAfter(arrival.add(const Duration(days: 730)))) {
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
        'end_date': DateFormat('yyyy-MM-dd').format(until),
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
    final visibleActive = _activePreorders.where((b) =>
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
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const Key('soldout_preorder_tab_add'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !_showActivePreorders
                                    ? AppColors.successSoft : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 12),
                              ),
                              onPressed: () => setState(
                                () => _showActivePreorders = false),
                              child: const Text(
                                'Tugagan kitoblarni oldindan buyurtmaga qo‘shish',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              key: const Key('soldout_preorder_tab_active'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _showActivePreorders
                                    ? AppColors.successSoft : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 12),
                              ),
                              onPressed: () => setState(
                                () => _showActivePreorders = true),
                              child: const Text(
                                'Oldindan sotuvga qo‘shilgan kitoblar',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_showActivePreorders) Padding(
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
                            'Har biriga kelish oralig‘i (shu sanadan ~ shu sanagacha) va avansni kiriting. '
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
                    if (_showActivePreorders)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_activePreorders.length} ta oldindan sotuvdagi kitob',
                              style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Har bir kitobni alohida tahrirlash yoki sotuvdan olish '
                              'mumkin. Eski mijoz buyurtmalari saqlanadi.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const Key('preorder_active_search'),
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Oldindan sotuvdagi kitobni qidirish',
                                prefixIcon: Icon(Icons.search_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _showActivePreorders
                          ? (visibleActive.isEmpty
                              ? const Center(child: Text(
                                  'Hozir oldindan sotuvga qo‘shilgan kitob yo‘q.'))
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                                  itemCount: visibleActive.length,
                                  itemBuilder: (context, index) {
                                    final book = visibleActive[index];
                                    return Card(
                                      key: ValueKey('active_preorder_${book.id}'),
                                      color: Colors.white,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.event_available_rounded,
                                              color: AppColors.success,
                                            ),
                                            title: Text(book.title, style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                            subtitle: Text(
                                              'Omborda ${book.stock} ta • Narx: ${_won(book.price)}\n'
                                              'Kelishi: ${book.preorderArrivalNote.isEmpty ? 'Ko‘rsatilmagan' : book.preorderArrivalNote}\n'
                                              'Avans: ${_won(book.preorderDepositMin)}',
                                            ),
                                            isThreeLine: true,
                                            onTap: _busy ? null
                                                : () => _editActivePreorder(book),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    key: ValueKey('preorder_active_edit_${book.id}'),
                                                    onPressed: _busy ? null
                                                        : () => _editActivePreorder(book),
                                                    icon: const Icon(Icons.edit_calendar_outlined),
                                                    label: const Text('Tahrirlash'),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    key: ValueKey('preorder_active_remove_${book.id}'),
                                                    onPressed: _busy ? null
                                                        : () => _removeActivePreorder(book),
                                                    icon: const Icon(Icons.remove_circle_outline),
                                                    label: const Text('Sotuvdan olish'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ))
                          : visible.isEmpty
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
                                                const Text(
                                                  'Taxminiy kelish oralig‘i',
                                                  style: TextStyle(fontWeight: FontWeight.w800),
                                                ),
                                                const SizedBox(height: 7),
                                                Row(children: [
                                                  Expanded(child: OutlinedButton.icon(
                                                    key: Key('soldout_start_${book.id}'),
                                                    onPressed: _busy ? null
                                                        : () => _selectDate(book.id, end: false),
                                                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                                                    label: Text(
                                                      'Dan: ${DateFormat('MM.dd').format(_dates[book.id]!)}',
                                                      maxLines: 1,
                                                    ),
                                                  )),
                                                  const SizedBox(width: 7),
                                                  const Text('~', style: TextStyle(fontWeight: FontWeight.w800)),
                                                  const SizedBox(width: 7),
                                                  Expanded(child: OutlinedButton.icon(
                                                    key: Key('soldout_end_${book.id}'),
                                                    onPressed: _busy ? null
                                                        : () => _selectDate(book.id, end: true),
                                                    icon: const Icon(Icons.event_available_outlined, size: 16),
                                                    label: Text(
                                                      'Gacha: ${DateFormat('MM.dd').format(_endDates[book.id]!)}',
                                                      maxLines: 1,
                                                    ),
                                                  )),
                                                ]),
                                                const SizedBox(height: 5),
                                                Text(
                                                  '${DateFormat('yyyy-MM-dd').format(_dates[book.id]!)} ~ ${DateFormat('yyyy-MM-dd').format(_endDates[book.id]!)}',
                                                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
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
                    if (!_showActivePreorders) SafeArea(
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
