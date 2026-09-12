from pathlib import Path

path = Path('lib/admin_ui.dart')
text = path.read_text(encoding='utf-8')
start_marker = 'class _BooksAdminState extends State<_BooksAdmin> {'
end_marker = '\nclass _AdminBookThumb extends StatelessWidget'
start = text.index(start_marker)
end = text.index(end_marker, start)

new_block = r'''class _BooksAdminState extends State<_BooksAdmin> {
  String query = '';
  String filter = 'all';
  late Future<List<Book>> future;
  Set<String> soldBookIds = <String>{};
  Set<String> soldTitleKeys = <String>{};
  bool salesLoaded = false;

  static const Set<String> _problemFilterKeys = <String>{
    'problems',
    'low_profit',
    'below_cost',
    'recent',
    'out_of_stock',
    'low_stock',
    'invalid_image',
    'missing_author',
  };

  String _titleKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool _missingImage(Book book) => book.galleryImages.isEmpty;

  bool _missingAuthor(Book book) {
    final value = book.author.trim().toLowerCase();
    return value.isEmpty ||
        value == 'ko‘rsatilmagan' ||
        value == "ko'rsatilmagan" ||
        value == 'ko`rsatilmagan';
  }

  bool _invalidImage(Book book) {
    if (book.galleryImages.isEmpty) return false;
    return book.galleryImages.any((raw) {
      final value = raw.trim();
      final uri = Uri.tryParse(value);
      return uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty ||
          value.toLowerCase().contains('placeholder');
    });
  }

  bool _belowCost(Book book) =>
      book.costPrice > 0 && book.currentPrice > 0 && book.currentPrice < book.costPrice;

  bool _lowProfit(Book book) {
    if (book.costPrice <= 0 || book.currentPrice <= 0) return false;
    final profit = book.currentPrice - book.costPrice;
    final margin = profit / book.currentPrice;
    return margin < 0.20;
  }

  bool _recent(Book book) {
    final created = book.createdAt;
    if (created == null) return false;
    return created.isAfter(DateTime.now().subtract(const Duration(days: 7)));
  }

  bool _outOfStock(Book book) => book.stock <= 0;
  bool _lowStock(Book book) => book.stock > 0 && book.stock <= 2;

  bool _hasProblem(Book book) =>
      _missingImage(book) ||
      book.costPrice <= 0 ||
      _invalidImage(book) ||
      _missingAuthor(book) ||
      _outOfStock(book) ||
      _lowStock(book) ||
      _belowCost(book) ||
      _lowProfit(book);

  bool _unsold(Book book) {
    if (!salesLoaded) return false;
    if (soldBookIds.contains(book.id)) return false;
    return !soldTitleKeys.contains(_titleKey(book.title));
  }

  bool _matchesFilter(Book book) {
    switch (filter) {
      case 'missing_image':
        return _missingImage(book);
      case 'missing_cost':
        return book.costPrice <= 0;
      case 'active':
        return book.isActive;
      case 'hidden':
        return !book.isActive;
      case 'unsold':
        return _unsold(book);
      case 'problems':
        return _hasProblem(book);
      case 'low_profit':
        return _lowProfit(book);
      case 'below_cost':
        return _belowCost(book);
      case 'recent':
        return _recent(book);
      case 'out_of_stock':
        return _outOfStock(book);
      case 'low_stock':
        return _lowStock(book);
      case 'invalid_image':
        return _invalidImage(book);
      case 'missing_author':
        return _missingAuthor(book);
      default:
        return true;
    }
  }

  String _filterLabel(String value) {
    switch (value) {
      case 'problems':
        return 'Muammoli kitoblar';
      case 'low_profit':
        return 'Foydasi past';
      case 'below_cost':
        return 'Narxi tannarxdan past';
      case 'recent':
        return 'Yaqinda qo‘shilgan';
      case 'out_of_stock':
        return 'Omborda tugagan';
      case 'low_stock':
        return 'Kam qolgan';
      case 'invalid_image':
        return 'Rasmi bor, lekin xato';
      case 'missing_author':
        return 'Muallifi kiritilmagan';
      default:
        return 'Muammoli';
    }
  }

  int _countFor(List<Book> all, String value) {
    switch (value) {
      case 'problems':
        return all.where(_hasProblem).length;
      case 'low_profit':
        return all.where(_lowProfit).length;
      case 'below_cost':
        return all.where(_belowCost).length;
      case 'recent':
        return all.where(_recent).length;
      case 'out_of_stock':
        return all.where(_outOfStock).length;
      case 'low_stock':
        return all.where(_lowStock).length;
      case 'invalid_image':
        return all.where(_invalidImage).length;
      case 'missing_author':
        return all.where(_missingAuthor).length;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    future = widget.api.books();
    unawaited(_loadSales());
  }

  Future<void> _loadSales() async {
    try {
      final rows = await widget.api.sales();
      final ids = <String>{};
      final titles = <String>{};
      for (final row in rows) {
        final id = (row['book_id'] ?? '').toString().trim();
        if (id.isNotEmpty && id != 'null') ids.add(id);
        final title = (row['title'] ?? '').toString().trim();
        if (title.isNotEmpty) titles.add(_titleKey(title));
      }
      if (!mounted) return;
      setState(() {
        soldBookIds = ids;
        soldTitleKeys = titles;
        salesLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => salesLoaded = true);
    }
  }

  void reload({bool syncStore = true}) {
    if (!mounted) return;
    setState(() => future = widget.api.books());
    unawaited(_loadSales());
    if (syncStore) {
      context.read<AppState>().refreshBooks();
    }
  }

  Future<void> reloadQuietly() async {
    try {
      final data = await widget.api.books();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Keep the previous list visible when a background fetch fails.
    }
  }

  Future<void> openForm([Book? book]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _BookForm(api: widget.api, book: book),
      ),
    );
    if (changed == true && mounted) reload();
  }

  Future<void> remove(Book book) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kitobni o‘chirish'),
        content: Text('“${book.title}” o‘chirilsinmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Yo‘q'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await widget.api.deleteBook(book.id);
      if (mounted) reload();
    }
  }

  Future<void> _openProblemFilters(List<Book> all) async {
    final options = <({String key, String label, IconData icon})>[
      (key: 'problems', label: 'Muammoli kitoblar', icon: Icons.warning_amber_rounded),
      (key: 'low_profit', label: 'Foydasi past', icon: Icons.trending_down_rounded),
      (key: 'below_cost', label: 'Narxi tannarxdan past', icon: Icons.money_off_csred_outlined),
      (key: 'recent', label: 'Yaqinda qo‘shilgan', icon: Icons.fiber_new_rounded),
      (key: 'out_of_stock', label: 'Omborda tugagan', icon: Icons.inventory_2_outlined),
      (key: 'low_stock', label: 'Kam qolgan', icon: Icons.low_priority_rounded),
      (key: 'invalid_image', label: 'Rasmi bor, lekin xato', icon: Icons.broken_image_outlined),
      (key: 'missing_author', label: 'Muallifi kiritilmagan', icon: Icons.person_off_outlined),
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Muammoli',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kerakli turini tanlang — ro‘yxatda faqat o‘sha kitoblar qoladi.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: options.map((option) {
                      final count = _countFor(all, option.key);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Icon(option.icon, color: _navy),
                        title: Text(
                          option.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$count',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            if (filter == option.key) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded, color: _orange),
                            ],
                          ],
                        ),
                        onTap: () => Navigator.pop(sheetContext, option.key),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => filter = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Book>>(
      future: future,
      builder: (context, snap) {
        final all = snap.data ?? const <Book>[];
        final q = query.trim().toLowerCase();
        final books = all
            .where(
              (b) =>
                  _matchesFilter(b) &&
                  (q.isEmpty ||
                      b.title.toLowerCase().contains(q) ||
                      b.author.toLowerCase().contains(q)),
            )
            .toList();
        final totalStock = all.fold<int>(0, (s, b) => s + b.stock);
        final missingImages = all.where(_missingImage).length;
        final missingCost = all.where((b) => b.costPrice <= 0).length;
        final activeBooks = all.where((b) => b.isActive).length;
        final hiddenBooks = all.where((b) => !b.isActive).length;
        final unsoldBooks = salesLoaded ? all.where(_unsold).length : 0;
        final problemBooks = all.where(_hasProblem).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(
                        label: 'Kitob',
                        value: '${all.length}',
                        selected: filter == 'all',
                        onTap: () => setState(() => filter = 'all'),
                      ),
                      _MiniStat(label: 'Ombor', value: '$totalStock dona'),
                      _MiniStat(
                        label: 'Rasm yuklanmagan',
                        value: '$missingImages',
                        selected: filter == 'missing_image',
                        onTap: () => setState(() => filter = 'missing_image'),
                      ),
                      _MiniStat(
                        label: 'Tan narxi kiritilmagan',
                        value: '$missingCost',
                        selected: filter == 'missing_cost',
                        onTap: () => setState(() => filter = 'missing_cost'),
                      ),
                      _MiniStat(
                        label: 'Sotuvda ko‘rsatilgan',
                        value: '$activeBooks',
                        selected: filter == 'active',
                        onTap: () => setState(() => filter = 'active'),
                      ),
                      _MiniStat(
                        label: 'Sotuvda ko‘rsatilmagan',
                        value: '$hiddenBooks',
                        selected: filter == 'hidden',
                        onTap: () => setState(() => filter = 'hidden'),
                      ),
                      _MiniStat(
                        label: 'Sotilmagan kitoblar',
                        value: salesLoaded ? '$unsoldBooks' : '…',
                        selected: filter == 'unsold',
                        onTap: salesLoaded
                            ? () => setState(() => filter = 'unsold')
                            : null,
                      ),
                      _MiniStat(
                        label: 'Muammoli',
                        value: '$problemBooks',
                        selected: _problemFilterKeys.contains(filter),
                        onTap: () => _openProblemFilters(all),
                      ),
                    ],
                  ),
                  if (_problemFilterKeys.contains(filter)) ...[
                    const SizedBox(height: 10),
                    InputChip(
                      avatar: const Icon(Icons.tune_rounded, size: 17),
                      label: Text('Muammoli → ${_filterLabel(filter)}'),
                      onDeleted: () => setState(() => filter = 'all'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => query = v),
                          decoration: const InputDecoration(
                            hintText: 'Kitob yoki muallif...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: reload,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        onPressed: () => openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Qo‘shish'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (snap.connectionState == ConnectionState.waiting && snap.data == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (snap.hasError)
              Expanded(child: Center(child: Text('Xatolik: ${snap.error}')))
            else if (books.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 44, color: Colors.black38),
                        const SizedBox(height: 10),
                        Text(
                          filter == 'unsold' && !salesLoaded
                              ? 'Sotuvlar tekshirilmoqda...'
                              : 'Bu filtrda kitob topilmadi.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = books[i];
                    final profit = b.currentPrice - b.costPrice;
                    final showCostLine = _problemFilterKeys.contains(filter) ||
                        filter == 'missing_cost';
                    return Card(
                      child: ListTile(
                        leading: _AdminBookThumb(url: b.imageUrl),
                        title: Text(
                          b.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          [
                            '${b.author} • ${b.stock} dona • ${_won(b.currentPrice)}${b.isActive ? '' : ' • Yashirilgan'}',
                            if (showCostLine)
                              b.costPrice <= 0
                                  ? 'Tannarx kiritilmagan'
                                  : 'Tannarx ${_won(b.costPrice)} • Foyda ${_won(profit)}',
                          ].join('\n'),
                        ),
                        isThreeLine: showCostLine,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) =>
                              v == 'edit' ? openForm(b) : remove(b),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Tahrirlash'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('O‘chirish'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
'''

path.write_text(text[:start] + new_block + text[end:], encoding='utf-8')
print('admin problem filters applied')
