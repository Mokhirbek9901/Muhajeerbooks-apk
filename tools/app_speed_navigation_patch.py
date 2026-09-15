from pathlib import Path

STORE = Path('lib/store_ui.dart')
STATE = Path('lib/app_state.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f'{label}: marker not found')
    return text.replace(old, new, 1)


store = STORE.read_text(encoding='utf-8')
state = STATE.read_text(encoding='utf-8')

# 1) Scroll paytida har frame Timer yaratib/o‘chirishni to‘xtatamiz.
#    Bir vaqtning o‘zida faqat bitta kechiktirilgan disk yozuvi bo‘ladi.
store = replace_once(
    store,
    """    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_write(value));
    });
""",
    """    if (_saveTimer != null) return;
    _saveTimer = Timer(const Duration(milliseconds: 900), () {
      _saveTimer = null;
      final latest = _scrollMemory[storageKey] ?? value;
      unawaited(_write(latest));
    });
""",
    'scroll write throttle',
)

# 2) Detailga bosilgan lahzada katta original rasmni decode/precache qilish
#    navigatsiya animatsiyasi bilan raqobat qilmasin.
store = replace_once(
    store,
    """Future<void> _openBookDetail(BuildContext context, Book book) async {
  if (book.imageUrl.trim().isNotEmpty) {
    unawaited(
      precacheImage(NetworkImage(book.imageUrl), context).catchError((_) {}),
    );
  }
  await Navigator.push<void>(
""",
    """Future<void> _openBookDetail(BuildContext context, Book book) async {
  await Navigator.push<void>(
""",
    'remove eager detail precache',
)

# 3) Katalogga aloqasi bo‘lmagan cart/favorite/profile notify'lari butun Home
#    sliver daraxtini qayta build qilmasin. Faqat katalog, loading yoki error
#    o‘zgarsa HomePage qayta build bo‘ladi.
store = replace_once(
    store,
    """  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = <String>{
""",
    """  @override
  Widget build(BuildContext context) {
    final homeState = context.select<
      AppState,
      ({int catalogRevision, bool loading, String? error})
    >(
      (s) => (
        catalogRevision: s.catalogRevision,
        loading: s.loading,
        error: s.error,
      ),
    );
    final state = context.read<AppState>();
    final categories = <String>{
""",
    'home selector',
)

old_header_call = 'SliverToBoxAdapter(child: _StoreHeader(state: state))'
new_header_call = 'const SliverToBoxAdapter(child: _StoreHeader())'
if new_header_call not in store:
    if old_header_call not in store:
        raise SystemExit('home header const: marker not found')
    store = store.replace(old_header_call, new_header_call, 1)

# Home'ning loading/error shartlari selector snapshotdan o‘qiladi.
store = replace_once(
    store,
    """            if (state.error != null)
""",
    """            if (homeState.error != null)
""",
    'home error selector',
)
store = replace_once(
    store,
    """            if (state.loading && state.books.isEmpty)
""",
    """            if (homeState.loading && state.books.isEmpty)
""",
    'home loading selector',
)

# Header o‘zi faqat unread notification sonini tinglaydi.
store = replace_once(
    store,
    """class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
""",
    """class _StoreHeader extends StatelessWidget {
  const _StoreHeader();

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.select<AppState, int>(
      (s) => s.unreadCustomerNoticeCount,
    );
    return Container(
""",
    'header local selector',
)
store = store.replace('state.unreadCustomerNoticeCount', 'unreadCount')

# 4) Grid preview rasmlarini telefon uchun ortiqcha katta decode qilmaymiz.
store = store.replace('cacheWidth: 420,', 'cacheWidth: 360,')

# 5) Har bir grid kartasidagi blur shadow + antiAlias scroll GPU xarajatini
#    oshiradi. Border saqlanadi, clipping esa hardEdge bo‘ladi.
book_start = store.find('class BookCard extends StatelessWidget {')
book_end = store.find('class _BookCover extends StatelessWidget {', book_start)
if book_start < 0 or book_end < 0:
    raise SystemExit('BookCard segment not found')
book = store[book_start:book_end]
shadow = """        boxShadow: const [
          BoxShadow(
            color: Color(0x0A173F4A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
"""
if shadow in book:
    book = book.replace(shadow, '', 1)
book = book.replace('clipBehavior: Clip.antiAlias,', 'clipBehavior: Clip.hardEdge,', 1)
store = store[:book_start] + book + store[book_end:]

# 6) HomePage uchun arzon katalog revision signali.
state = replace_once(
    state,
    """  final Set<String> _restockSubscriptions = {};
  String _catalogCursor = '1970-01-01T00:00:00Z';
""",
    """  final Set<String> _restockSubscriptions = {};
  int _catalogRevision = 0;
  int get catalogRevision => _catalogRevision;
  void _touchCatalog() => _catalogRevision++;
  String _catalogCursor = '1970-01-01T00:00:00Z';
""",
    'catalog revision field',
)

# Initial cached/seed catalog becomes visible.
state = replace_once(
    state,
    """    loading = false;
    notifyListeners();

    // Qolgan lokal holat storefront allaqachon ko‘ringandan keyin yuklanadi.
""",
    """    _touchCatalog();
    loading = false;
    notifyListeners();

    // Qolgan lokal holat storefront allaqachon ko‘ringandan keyin yuklanadi.
""",
    'initial catalog revision',
)

# Quiet delta sync.
state = replace_once(
    state,
    """      _books
        ..clear()
        ..addAll(merged);
      _sanitizeCart();
      notifyListeners();
""",
    """      _books
        ..clear()
        ..addAll(merged);
      _sanitizeCart();
      _touchCatalog();
      notifyListeners();
""",
    'quiet catalog revision',
)

# Local catalog init.
needle = "Future<void> _initializeLocalCatalog() async {"
start = state.find(needle)
end = state.find("\n  Future<List<Book>> _loadTelegramSeed()", start)
if start < 0 or end < 0:
    raise SystemExit('local catalog init segment not found')
seg = state[start:end]
old_finally = """    } finally {
      loading = false;
      notifyListeners();
    }
"""
new_finally = """    } finally {
      _touchCatalog();
      loading = false;
      notifyListeners();
    }
"""
if new_finally not in seg:
    if old_finally not in seg:
        raise SystemExit('local catalog finally marker not found')
    seg = seg.replace(old_finally, new_finally, 1)
state = state[:start] + seg + state[end:]

# Manual/full refresh.
start = state.find('  Future<void> refreshBooks({bool includeInactive = false}) async {')
end = state.find('\n  List<CartLine> get cartLines', start)
if start < 0 or end < 0:
    raise SystemExit('refreshBooks segment not found')
seg = state[start:end]
if new_finally not in seg:
    if old_finally not in seg:
        raise SystemExit('refreshBooks finally marker not found')
    seg = seg.replace(old_finally, new_finally, 1)
state = state[:start] + seg + state[end:]

# Local admin mutations.
state = replace_once(
    state,
    """    if (index == -1) {
      _books.insert(0, saved);
    } else {
      _books[index] = saved;
    }
    await _local.saveBooks(_books);
""",
    """    if (index == -1) {
      _books.insert(0, saved);
    } else {
      _books[index] = saved;
    }
    _touchCatalog();
    await _local.saveBooks(_books);
""",
    'saveBook revision',
)
state = replace_once(
    state,
    """    _books.removeWhere((b) => b.id == book.id);
    _cart.remove(book.id);
""",
    """    _books.removeWhere((b) => b.id == book.id);
    _touchCatalog();
    _cart.remove(book.id);
""",
    'deleteBook revision',
)
state = replace_once(
    state,
    """    for (var i = 0; i < _books.length; i++) {
      _books[i] = _books[i].copyWith(discountPercent: safe);
    }
    await _local.saveBooks(_books);
""",
    """    for (var i = 0; i < _books.length; i++) {
      _books[i] = _books[i].copyWith(discountPercent: safe);
    }
    _touchCatalog();
    await _local.saveBooks(_books);
""",
    'discount revision',
)
state = replace_once(
    state,
    """    _books
      ..clear()
      ..addAll(await _loadTelegramSeed());
    _cart.clear();
""",
    """    _books
      ..clear()
      ..addAll(await _loadTelegramSeed());
    _touchCatalog();
    _cart.clear();
""",
    'reset catalog revision',
)

# Mahalliy order statusi stockni o‘zgartirganda Home'dagi qoldiq ham yangilansin.
state = replace_once(
    state,
    """    _localOrders[index] = old.copyWith(status: status, stockReserved: reserved);
    await Future.wait([
""",
    """    _localOrders[index] = old.copyWith(status: status, stockReserved: reserved);
    _touchCatalog();
    await Future.wait([
""",
    'local order stock revision',
)

STORE.write_text(store, encoding='utf-8')
STATE.write_text(state, encoding='utf-8')
print('Storefront performance hardening applied.')
