from pathlib import Path

# -------- app_state.dart: live customer catalog sync --------
p = Path('lib/app_state.dart')
s = p.read_text(encoding='utf-8')

if "import 'dart:async';" not in s:
    s = s.replace("import 'dart:convert';\n", "import 'dart:async';\nimport 'dart:convert';\n", 1)

field_needle = '''  final Map<String, int> _cart = {};\n  final Set<String> _favorites = {};\n  bool loading = true;\n'''
field_repl = '''  final Map<String, int> _cart = {};\n  final Set<String> _favorites = {};\n  RealtimeChannel? _booksChannel;\n  Timer? _booksRealtimeDebounce;\n  Timer? _booksFallbackTimer;\n  bool _quietBooksRefreshing = false;\n  bool loading = true;\n'''
assert field_needle in s, 'AppState fields not found'
s = s.replace(field_needle, field_repl, 1)

init_needle = '''    if (_backend == null) {\n      await _initializeLocalCatalog();\n    } else {\n      await refreshBooks();\n    }\n  }\n\n  Future<void> _initializeLocalCatalog() async {\n'''
init_repl = '''    if (_backend == null) {\n      await _initializeLocalCatalog();\n    } else {\n      await refreshBooks();\n      _startLiveBooksSync();\n    }\n  }\n\n  void _startLiveBooksSync() {\n    if (_backend == null || _booksChannel != null) return;\n\n    _booksChannel = Supabase.instance.client\n        .channel('muhajeer-books-catalog-live')\n        .onPostgresChanges(\n          event: PostgresChangeEvent.all,\n          schema: 'public',\n          table: 'books',\n          callback: (_) {\n            _booksRealtimeDebounce?.cancel();\n            _booksRealtimeDebounce = Timer(\n              const Duration(milliseconds: 180),\n              _refreshBooksQuietly,\n            );\n          },\n        )\n        .subscribe();\n\n    // Realtime uzilib qolgan holat uchun yengil zaxira tekshiruv.\n    _booksFallbackTimer = Timer.periodic(\n      const Duration(seconds: 20),\n      (_) => _refreshBooksQuietly(),\n    );\n  }\n\n  String _catalogStamp(Iterable<Book> items) => items\n      .map(\n        (b) => [\n          b.id,\n          b.title,\n          b.author,\n          b.category,\n          b.description,\n          b.price,\n          b.stock,\n          b.discountPercent,\n          b.imageUrl,\n          b.isActive,\n          b.coverType,\n          b.costPrice,\n          b.recommended,\n        ].join('¦'),\n      )\n      .join('§');\n\n  Future<void> _refreshBooksQuietly() async {\n    if (_backend == null || _quietBooksRefreshing) return;\n    _quietBooksRefreshing = true;\n    try {\n      final fresh = await _backend!.fetchBooks();\n      if (_catalogStamp(fresh) == _catalogStamp(_books)) return;\n      _books\n        ..clear()\n        ..addAll(fresh);\n      _sanitizeCart();\n      notifyListeners();\n    } catch (_) {\n      // Oddiy internet uzilishida ekrandagi oxirgi katalog saqlanadi.\n    } finally {\n      _quietBooksRefreshing = false;\n    }\n  }\n\n  @override\n  void dispose() {\n    _booksRealtimeDebounce?.cancel();\n    _booksFallbackTimer?.cancel();\n    final channel = _booksChannel;\n    if (channel != null) {\n      unawaited(Supabase.instance.client.removeChannel(channel));\n    }\n    super.dispose();\n  }\n\n  Future<void> _initializeLocalCatalog() async {\n'''
assert init_needle in s, 'AppState initialize block not found'
s = s.replace(init_needle, init_repl, 1)
p.write_text(s, encoding='utf-8')

# -------- admin_ui.dart: refresh only the active admin page --------
p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')
if "import 'dart:async';" not in s:
    s = s.replace("import 'dart:convert';\n", "import 'dart:async';\nimport 'dart:convert';\n", 1)

# Parent admin keys/timer.
parent_fields = '''class _AdminDashboardPageState extends State<AdminDashboardPage> {\n  int tab = 0;\n  late final _AdminApi api;\n'''
parent_repl = '''class _AdminDashboardPageState extends State<AdminDashboardPage> {\n  int tab = 0;\n  late final _AdminApi api;\n  Timer? _liveRefreshTimer;\n  final _overviewKey = GlobalKey<_OverviewAdminState>();\n  final _booksKey = GlobalKey<_BooksAdminState>();\n  final _inventoryKey = GlobalKey<_InventoryAdminState>();\n  final _ordersKey = GlobalKey<_OrdersAdminState>();\n'''
assert parent_fields in s, 'Admin parent fields not found'
s = s.replace(parent_fields, parent_repl, 1)

init_parent = '''  @override\n  void initState() {\n    super.initState();\n    api = _AdminApi(widget.secret);\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    final pages = [\n      _OverviewAdmin(api: api),\n      _BooksAdmin(api: api),\n      _InventoryAdmin(api: api),\n      _OrdersAdmin(api: api),\n      _DiscountAdmin(api: api),\n    ];\n'''
repl_parent = '''  @override\n  void initState() {\n    super.initState();\n    api = _AdminApi(widget.secret);\n    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {\n      if (!mounted) return;\n      switch (tab) {\n        case 0:\n          _overviewKey.currentState?.reload();\n        case 1:\n          _booksKey.currentState?.reload(syncStore: false);\n        case 2:\n          _inventoryKey.currentState?.loadQuietly();\n        case 3:\n          _ordersKey.currentState?.reload();\n      }\n    });\n  }\n\n  @override\n  void dispose() {\n    _liveRefreshTimer?.cancel();\n    super.dispose();\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    final pages = [\n      _OverviewAdmin(key: _overviewKey, api: api),\n      _BooksAdmin(key: _booksKey, api: api),\n      _InventoryAdmin(key: _inventoryKey, api: api),\n      _OrdersAdmin(key: _ordersKey, api: api),\n      _DiscountAdmin(api: api),\n    ];\n'''
assert init_parent in s, 'Admin parent init/pages not found'
s = s.replace(init_parent, repl_parent, 1)

# Constructors accept keys.
s = s.replace('''class _OverviewAdmin extends StatefulWidget {\n  const _OverviewAdmin({required this.api});\n''', '''class _OverviewAdmin extends StatefulWidget {\n  const _OverviewAdmin({super.key, required this.api});\n''', 1)
s = s.replace('''class _InventoryAdmin extends StatefulWidget {\n  const _InventoryAdmin({required this.api});\n''', '''class _InventoryAdmin extends StatefulWidget {\n  const _InventoryAdmin({super.key, required this.api});\n''', 1)
s = s.replace('''class _BooksAdmin extends StatefulWidget {\n  const _BooksAdmin({required this.api});\n''', '''class _BooksAdmin extends StatefulWidget {\n  const _BooksAdmin({super.key, required this.api});\n''', 1)
s = s.replace('''class _OrdersAdmin extends StatefulWidget {\n  const _OrdersAdmin({required this.api});\n''', '''class _OrdersAdmin extends StatefulWidget {\n  const _OrdersAdmin({super.key, required this.api});\n''', 1)

# Inventory quiet refresh: no spinner every 5 seconds.
load_needle = '''  Future<void> _load() async {\n    if (mounted) {\n      setState(() {\n        loading = true;\n        error = null;\n      });\n    }\n'''
load_repl = '''  Future<void> _load({bool showLoading = true}) async {\n    if (mounted && showLoading) {\n      setState(() {\n        loading = true;\n        error = null;\n      });\n    }\n'''
assert load_needle in s, 'Inventory load not found'
s = s.replace(load_needle, load_repl, 1)
# Don't switch loading false on quiet success/failure in a way that harms UI; harmless if already false.
marker = '''  Future<void> change(Book book, int delta) async {\n'''
assert marker in s
s = s.replace(marker, '''  Future<void> loadQuietly() => _load(showLoading: false);\n\n  Future<void> change(Book book, int delta) async {\n''', 1)

# Books reload optionally avoids triggering another customer-catalog network call.
books_reload = '''  void reload() {\n    setState(() => future = widget.api.books());\n    context.read<AppState>().refreshBooks();\n  }\n'''
books_reload_repl = '''  void reload({bool syncStore = true}) {\n    if (!mounted) return;\n    setState(() => future = widget.api.books());\n    if (syncStore) {\n      context.read<AppState>().refreshBooks();\n    }\n  }\n'''
assert books_reload in s, 'Books reload not found'
s = s.replace(books_reload, books_reload_repl, 1)

# Guard simple reloads after dispose.
s = s.replace('''  void reload() => setState(() => future = load());\n''', '''  void reload() {\n    if (mounted) setState(() => future = load());\n  }\n''', 1)
s = s.replace('''  void reload() => setState(() => future = widget.api.orders());\n''', '''  void reload() {\n    if (mounted) setState(() => future = widget.api.orders());\n  }\n''', 1)

p.write_text(s, encoding='utf-8')
