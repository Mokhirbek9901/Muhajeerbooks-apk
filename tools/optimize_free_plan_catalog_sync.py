from pathlib import Path

path = Path('lib/app_state.dart')
source = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global source
    if old not in source:
        raise SystemExit(f'{label}: target not found')
    source = source.replace(old, new, 1)


replace_once(
    "  Future<void> saveBook(Book book) async {\n",
    """  Future<Map<String, dynamic>> fetchCatalogDelta(String since) async {
    final raw = await client.rpc(
      'customer_catalog_delta',
      params: {'p_since': since},
    );
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
  }

  Future<void> saveBook(Book book) async {
""",
    'backend delta method',
)

replace_once(
    "  static const _restockSubscriptionsKey = 'muhajeer_restock_subscriptions_v1';\n",
    """  static const _restockSubscriptionsKey = 'muhajeer_restock_subscriptions_v1';
  static const _catalogCursorKey = 'muhajeer_catalog_cursor_v1';
""",
    'catalog cursor key',
)

replace_once(
    """  Future<void> saveRestockSubscriptions(Set<String> ids) async =>
      (await _prefs).setStringList(_restockSubscriptionsKey, ids.toList());
}
""",
    """  Future<void> saveRestockSubscriptions(Set<String> ids) async =>
      (await _prefs).setStringList(_restockSubscriptionsKey, ids.toList());

  Future<String> loadCatalogCursor() async =>
      (await _prefs).getString(_catalogCursorKey) ??
      '1970-01-01T00:00:00Z';

  Future<void> saveCatalogCursor(String value) async =>
      (await _prefs).setString(_catalogCursorKey, value);
}
""",
    'catalog cursor local methods',
)

replace_once(
    """  final Set<String> _restockSubscriptions = {};
  Timer? _booksFallbackTimer;
""",
    """  final Set<String> _restockSubscriptions = {};
  String _catalogCursor = '1970-01-01T00:00:00Z';
  Timer? _booksFallbackTimer;
""",
    'catalog cursor state field',
)

replace_once(
    """      _local.loadCustomerNotices(),
      _local.loadBooks(),
    ]);
""",
    """      _local.loadCustomerNotices(),
      _local.loadBooks(),
      _local.loadCatalogCursor(),
    ]);
""",
    'initialize cursor load',
)

replace_once(
    """    final cachedBooks = initial[7] as List<Book>;

    if (storedVerification == null) {
""",
    """    final cachedBooks = initial[7] as List<Book>;
    _catalogCursor = initial[8] as String;

    if (storedVerification == null) {
""",
    'initialize cursor assign',
)

replace_once(
    """    _booksFallbackTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_refreshBooksQuietly());
      unawaited(_checkRestockNotificationsQuietly());
    });
""",
    """    // Full katalogni qayta-qayta yuklamaymiz. Har 2 daqiqada serverdan
    // faqat o'zgargan kitoblar va o'chirilgan IDlar olinadi. Checkout paytida
    // ombor baribir serverda live tekshiriladi, shuning uchun sotuv xavfsiz qoladi.
    _booksFallbackTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(_refreshBooksQuietly());
      unawaited(_checkRestockNotificationsQuietly());
    });
""",
    'catalog poll interval',
)

old_refresh = """  Future<void> _refreshBooksQuietly() async {
    if (_backend == null || _quietBooksRefreshing) return;
    _quietBooksRefreshing = true;
    try {
      final fresh = await _backend!.fetchBooks();
      if (_catalogStamp(fresh) == _catalogStamp(_books)) return;
      _books
        ..clear()
        ..addAll(fresh);
      _sanitizeCart();
      notifyListeners();
      // Diskka yozish UI ni kutib turmasin.
      unawaited(_local.saveBooks(_books));
    } catch (_) {
      // Oddiy internet uzilishida ekrandagi oxirgi katalog saqlanadi.
    } finally {
      _quietBooksRefreshing = false;
    }
  }
"""

new_refresh = """  Future<void> _refreshBooksQuietly() async {
    if (_backend == null || _quietBooksRefreshing) return;
    _quietBooksRefreshing = true;
    try {
      final delta = await _backend!.fetchCatalogDelta(_catalogCursor);
      final serverTime = (delta['server_time'] ?? '').toString().trim();
      if (serverTime.isEmpty) return;

      final isInitialSync = _catalogCursor.startsWith('1970-01-01');
      final byId = <String, Book>{
        if (!isInitialSync)
          for (final book in _books) book.id: book,
      };

      final deletedRaw = delta['deleted_ids'];
      if (deletedRaw is List) {
        for (final id in deletedRaw) {
          byId.remove(id.toString());
        }
      }

      final upsertsRaw = delta['upserts'];
      if (upsertsRaw is List) {
        for (final raw in upsertsRaw.whereType<Map>()) {
          final book = Book.fromMap(Map<String, dynamic>.from(raw));
          if (book.id.isEmpty) continue;
          if (book.isActive) {
            byId[book.id] = book;
          } else {
            byId.remove(book.id);
          }
        }
      }

      final merged = byId.values.toList()
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

      final changed = _catalogStamp(merged) != _catalogStamp(_books);
      _catalogCursor = serverTime;
      unawaited(_local.saveCatalogCursor(_catalogCursor));

      if (!changed) return;
      _books
        ..clear()
        ..addAll(merged);
      _sanitizeCart();
      notifyListeners();
      // Diskka yozish UI ni kutib turmasin.
      unawaited(_local.saveBooks(_books));
    } catch (_) {
      // Oddiy internet uzilishida ekrandagi oxirgi katalog saqlanadi.
    } finally {
      _quietBooksRefreshing = false;
    }
  }
"""
replace_once(old_refresh, new_refresh, 'delta refresh implementation')

replace_once(
    """      await Future.wait([
        _local.saveOrders(_localOrders),
        _local.saveCart(_cart),
      ]);
      await refreshBooks();
      return id;
""",
    """      await Future.wait([
        _local.saveOrders(_localOrders),
        _local.saveCart(_cart),
      ]);
      // Buyurtmadan keyin butun katalogni emas, faqat ombori o'zgargan
      // kitoblarni delta orqali yangilaymiz.
      await _refreshBooksQuietly();
      return id;
""",
    'post-order delta refresh',
)

# Profil ochilganda faqat hali yakunlanmagan buyurtmalar statusini tekshiramiz.
replace_once(
    """        final uuidIds = _localOrders
            .map((o) => o.id)
            .where((id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
            .toList();
""",
    """        final uuidIds = _localOrders
            .where(
              (o) => !const {'shipping', 'done', 'cancelled'}.contains(o.status),
            )
            .map((o) => o.id)
            .where((id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
            .toList();
""",
    'profile active order filter',
)

# Fon polling ham yakunlangan eski buyurtmalar uchun serverga umuman bormaydi.
replace_once(
    """      final uuidIds = _localOrders
          .map((o) => o.id)
          .where((id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
          .toList();
""",
    """      final uuidIds = _localOrders
          .where(
            (o) => !const {'shipping', 'done', 'cancelled'}.contains(o.status),
          )
          .map((o) => o.id)
          .where((id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
          .toList();
""",
    'background active order filter',
)

path.write_text(source, encoding='utf-8')
print('Free-plan catalog delta optimization applied')
