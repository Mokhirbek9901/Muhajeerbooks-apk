from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


p = Path("lib/app_state.dart")
s = p.read_text(encoding="utf-8")

anchor = """  Future<void> registerInstallation(String installId, String platform) async {
    await client.rpc(
      'register_app_install',
      params: {'p_install_id': installId, 'p_platform': platform},
    );
  }
"""
add = anchor + """

  Future<Map<String, dynamic>> subscribeRestock(
    String installId,
    String bookId,
  ) async {
    final raw = await client.rpc(
      'customer_restock_subscribe',
      params: {'p_install_id': installId, 'p_book_id': bookId},
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> unsubscribeRestock(String installId, String bookId) async {
    await client.rpc(
      'customer_restock_unsubscribe',
      params: {'p_install_id': installId, 'p_book_id': bookId},
    );
  }

  Future<List<Map<String, dynamic>>> fetchRestockNotifications(
    String installId,
  ) async {
    final raw = await client.rpc(
      'customer_restock_notifications',
      params: {'p_install_id': installId},
    );
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
"""
if "customer_restock_subscribe" not in s:
    s = replace_once(s, anchor, add, "backend restock helpers")

if "_restockSubscriptionsKey" not in s:
    s = replace_once(
        s,
        "  static const _installIdKey = 'muhajeer_install_id_v1';",
        "  static const _installIdKey = 'muhajeer_install_id_v1';\n  static const _restockSubscriptionsKey = 'muhajeer_restock_subscriptions_v1';",
        "restock local key",
    )

install_method = """  Future<String> installId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_installIdKey);
    if (existing != null && existing.length >= 12) return existing;
    final generated =
        'mb-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(prefs).abs()}';
    await prefs.setString(_installIdKey, generated);
    return generated;
  }
"""
install_add = install_method + """

  Future<Set<String>> loadRestockSubscriptions() async =>
      (await _prefs).getStringList(_restockSubscriptionsKey)?.toSet() ??
      <String>{};

  Future<void> saveRestockSubscriptions(Set<String> ids) async =>
      (await _prefs).setStringList(_restockSubscriptionsKey, ids.toList());
"""
if "loadRestockSubscriptions" not in s:
    s = replace_once(s, install_method, install_add, "local restock storage")

if "final Set<String> _restockSubscriptions" not in s:
    s = replace_once(
        s,
        "  final Set<String> _favorites = {};\n",
        "  final Set<String> _favorites = {};\n  final Set<String> _restockSubscriptions = {};\n",
        "restock state set",
    )
if "bool _restockRefreshing" not in s:
    s = replace_once(
        s,
        "  bool _orderStatusRefreshing = false;\n",
        "  bool _orderStatusRefreshing = false;\n  bool _restockRefreshing = false;\n",
        "restock refresh flag",
    )
if "isRestockSubscribed(Book book)" not in s:
    s = replace_once(
        s,
        "  Set<String> get favorites => Set.unmodifiable(_favorites);\n",
        "  Set<String> get favorites => Set.unmodifiable(_favorites);\n  bool isRestockSubscribed(Book book) =>\n      _restockSubscriptions.contains(book.id);\n",
        "restock getter",
    )

init_anchor = """    _favorites
      ..clear()
      ..addAll(await _local.loadFavorites());
    _cart
"""
init_new = """    _favorites
      ..clear()
      ..addAll(await _local.loadFavorites());
    _restockSubscriptions
      ..clear()
      ..addAll(await _local.loadRestockSubscriptions());
    _cart
"""
if "..addAll(await _local.loadRestockSubscriptions())" not in s:
    s = replace_once(s, init_anchor, init_new, "startup restock load")

init_online = """      await refreshBooks();
      _startLiveBooksSync();
      await _refreshCustomerOrderStatusesQuietly();
"""
init_online_new = """      await refreshBooks();
      _startLiveBooksSync();
      await _checkRestockNotificationsQuietly();
      await _refreshCustomerOrderStatusesQuietly();
"""
if "await _checkRestockNotificationsQuietly();" not in s:
    s = replace_once(s, init_online, init_online_new, "initial restock check")

timer_old = """    _booksFallbackTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshBooksQuietly(),
    );
"""
timer_new = """    _booksFallbackTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        unawaited(_refreshBooksQuietly());
        unawaited(_checkRestockNotificationsQuietly());
      },
    );
"""
if "unawaited(_checkRestockNotificationsQuietly())" not in s:
    s = replace_once(s, timer_old, timer_new, "restock polling")

dispose_anchor = """  @override
  void dispose() {
"""
methods = """  Future<String> toggleRestockNotification(Book book) async {
    if (book.inStock) return 'Kitob hozir sotuvda mavjud.';
    if (_backend == null) return 'Xabar berish uchun internet kerak.';

    final installId = await _local.installId();
    if (_restockSubscriptions.contains(book.id)) {
      await _backend!.unsubscribeRestock(installId, book.id);
      _restockSubscriptions.remove(book.id);
      await _local.saveRestockSubscriptions(_restockSubscriptions);
      notifyListeners();
      return 'Xabar berish bekor qilindi.';
    }

    final result = await _backend!.subscribeRestock(installId, book.id);
    if (result['already_available'] == true) {
      await refreshBooks();
      return 'Kitob hozir sotuvda mavjud.';
    }

    _restockSubscriptions.add(book.id);
    await _local.saveRestockSubscriptions(_restockSubscriptions);
    notifyListeners();
    return 'Kitob kelganda sizga xabar beramiz ✅';
  }

  Future<void> _checkRestockNotificationsQuietly() async {
    if (_backend == null || _restockRefreshing || _restockSubscriptions.isEmpty) {
      return;
    }
    _restockRefreshing = true;
    try {
      final installId = await _local.installId();
      final rows = await _backend!.fetchRestockNotifications(installId);
      if (rows.isEmpty) return;

      var changed = false;
      for (final row in rows) {
        final bookId = (row['book_id'] ?? '').toString();
        final title = (row['title'] ?? 'Kitob').toString();
        final at = (row['notified_at'] ?? DateTime.now().toIso8601String()).toString();
        final noticeId = 'restock:$bookId:$at';
        if (_customerNotices.any((n) => (n['id'] ?? '').toString() == noticeId)) {
          continue;
        }
        _customerNotices.insert(0, {
          'id': noticeId,
          'status': 'restock',
          'book_id': bookId,
          'title': '📚 Kitob yana sotuvda!',
          'message': '$title yana mavjud. Hozir buyurtma berishingiz mumkin.',
          'created_at': at,
          'read': false,
        });
        _restockSubscriptions.remove(bookId);
        changed = true;
      }
      if (!changed) return;
      if (_customerNotices.length > 50) {
        _customerNotices.removeRange(50, _customerNotices.length);
      }
      await Future.wait([
        _local.saveCustomerNotices(_customerNotices),
        _local.saveRestockSubscriptions(_restockSubscriptions),
      ]);
      notifyListeners();
    } catch (_) {
      // Network error should not block shopping.
    } finally {
      _restockRefreshing = false;
    }
  }

""" + dispose_anchor
if "toggleRestockNotification(Book book)" not in s:
    s = replace_once(s, dispose_anchor, methods, "restock state methods")

p.write_text(s, encoding="utf-8")

p = Path("lib/store_ui.dart")
u = p.read_text(encoding="utf-8")

fav_line = """    final favorite = context.select<AppState, bool>((s) => s.isFavorite(book));
    final state = context.read<AppState>();
"""
fav_new = """    final favorite = context.select<AppState, bool>((s) => s.isFavorite(book));
    final restockSubscribed = context.select<AppState, bool>(
      (s) => s.isRestockSubscribed(book),
    );
    final state = context.read<AppState>();
"""
if "final restockSubscribed = context.select<AppState, bool>" not in u:
    u = replace_once(u, fav_line, fav_new, "book card restock selector")

old_button = """                        child: FilledButton(
                          onPressed: book.inStock
                              ? () {
                                  state.addToCart(book);
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${book.title} savatga qo‘shildi ✅',
                                        ),
                                        duration: const Duration(
                                          milliseconds: 900,
                                        ),
                                      ),
                                    );
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(38, 38),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 18,
                          ),
                        ),
"""
new_button = """                        child: FilledButton(
                          onPressed: book.inStock
                              ? () {
                                  state.addToCart(book);
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${book.title} savatga qo‘shildi ✅',
                                        ),
                                        duration: const Duration(
                                          milliseconds: 900,
                                        ),
                                      ),
                                    );
                                }
                              : () async {
                                  final message = await state.toggleRestockNotification(book);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(SnackBar(content: Text(message)));
                                },
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(38, 38),
                          ),
                          child: Icon(
                            book.inStock
                                ? Icons.add_shopping_cart_rounded
                                : restockSubscribed
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_none_rounded,
                            size: 18,
                          ),
                        ),
"""
if "restockSubscribed\n                                    ? Icons.notifications_active_rounded" not in u:
    u = replace_once(u, old_button, new_button, "book card restock button")

old_detail = """              FilledButton.icon(
                onPressed: b.inStock
                    ? () {
                        state.addToCart(b);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Savatchaga qo‘shildi ✅'),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.shopping_bag_rounded),
                label: Text(b.inStock ? 'Savatchaga qo‘shish' : 'Mavjud emas'),
              ),
"""
new_detail = """              FilledButton.icon(
                onPressed: b.inStock
                    ? () {
                        state.addToCart(b);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Savatchaga qo‘shildi ✅')),
                        );
                      }
                    : () async {
                        final message = await state.toggleRestockNotification(b);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      },
                icon: Icon(
                  b.inStock
                      ? Icons.shopping_bag_rounded
                      : state.isRestockSubscribed(b)
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                ),
                label: Text(
                  b.inStock
                      ? 'Savatchaga qo‘shish'
                      : state.isRestockSubscribed(b)
                          ? 'Xabar beramiz ✅'
                          : 'Kelganda xabar berish',
                ),
              ),
"""
if "'Kelganda xabar berish'" not in u:
    u = replace_once(u, old_detail, new_detail, "book detail restock button")

p.write_text(u, encoding="utf-8")
print("Restock notifications patch applied")
