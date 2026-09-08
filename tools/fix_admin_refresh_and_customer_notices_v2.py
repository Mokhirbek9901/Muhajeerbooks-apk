from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"Missing patch anchor: {label}")
    return text.replace(old, new, 1)

# -------------------------
# Admin: true silent 5-second refresh
# -------------------------
admin_path = Path('lib/admin_ui.dart')
admin = admin_path.read_text(encoding='utf-8')

old_timer = '''    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      switch (tab) {
        case 0:
          _overviewKey.currentState?.reload();
        case 1:
          _booksKey.currentState?.reload(syncStore: false);
        case 2:
          _inventoryKey.currentState?.loadQuietly();
        case 3:
          _ordersKey.currentState?.reload();
        case 4:
          _customersKey.currentState?.reload();
      }
    });'''
new_timer = '''    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      switch (tab) {
        case 0:
          unawaited(_overviewKey.currentState?.reloadQuietly());
        case 1:
          unawaited(_booksKey.currentState?.reloadQuietly());
        case 2:
          unawaited(_inventoryKey.currentState?.loadQuietly());
        case 3:
          unawaited(_ordersKey.currentState?.reloadQuietly());
        case 4:
          unawaited(_customersKey.currentState?.reloadQuietly());
      }
    });'''
admin = replace_once(admin, old_timer, new_timer, 'admin timer')

old_overview = '''  void reload() {
    if (mounted) setState(() => future = load());
  }
'''
new_overview = old_overview + '''
  Future<void> reloadQuietly() async {
    try {
      final data = await load();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Background refresh must not replace visible data.
    }
  }
'''
admin = replace_once(admin, old_overview, new_overview, 'overview reload')

old_books = '''  void reload({bool syncStore = true}) {
    if (!mounted) return;
    setState(() => future = widget.api.books());
    if (syncStore) {
      context.read<AppState>().refreshBooks();
    }
  }
'''
new_books = old_books + '''
  Future<void> reloadQuietly() async {
    try {
      final data = await widget.api.books();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Keep the previous list visible when a background fetch fails.
    }
  }
'''
admin = replace_once(admin, old_books, new_books, 'books reload')

old_orders = '''  void reload() {
    if (mounted) setState(() => future = widget.api.orders());
  }
'''
new_orders = old_orders + '''
  Future<void> reloadQuietly() async {
    try {
      final data = await widget.api.orders();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Keep the current orders visible during background refresh.
    }
  }
'''
admin = replace_once(admin, old_orders, new_orders, 'orders reload')

old_customers = '''  void reload() {
    if (!mounted) return;
    _reload();
    setState(() {});
  }

  @override
  void initState() {'''
new_customers = '''  void reload() {
    if (!mounted) return;
    _reload();
    setState(() {});
  }

  Future<void> reloadQuietly() async {
    try {
      final values = await Future.wait<dynamic>([
        widget.api.userStats(),
        widget.api.customers(),
      ]);
      final data = (
        Map<String, dynamic>.from(values[0] as Map),
        (values[1] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Keep the current customer list visible during background refresh.
    }
  }

  @override
  void initState() {'''
admin = replace_once(admin, old_customers, new_customers, 'customers reload')
admin_path.write_text(admin, encoding='utf-8')

# -------------------------
# AppState: persistent in-app order notifications
# -------------------------
state_path = Path('lib/app_state.dart')
state = state_path.read_text(encoding='utf-8')

state = replace_once(
    state,
    "  static const _ordersKey = 'muhajeer_orders_v3';\n",
    "  static const _ordersKey = 'muhajeer_orders_v3';\n  static const _customerNoticesKey = 'muhajeer_customer_notices_v1';\n",
    'notice key',
)

old_save_orders = '''  Future<void> saveOrders(List<ShopOrder> orders) async {
    await (await _prefs).setString(
      _ordersKey,
      jsonEncode(orders.map((e) => e.toMap()).toList()),
    );
  }
'''
new_save_orders = old_save_orders + '''
  Future<List<Map<String, dynamic>>> loadCustomerNotices() async {
    try {
      final raw = (await _prefs).getString(_customerNoticesKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomerNotices(
    List<Map<String, dynamic>> notices,
  ) async {
    await (await _prefs).setString(
      _customerNoticesKey,
      jsonEncode(notices),
    );
  }
'''
state = replace_once(state, old_save_orders, new_save_orders, 'notice local store')

old_fields = '''  final List<ShopOrder> _localOrders = [];
  final Map<String, int> _cart = {};
  final Set<String> _favorites = {};
  RealtimeChannel? _booksChannel;
  Timer? _booksRealtimeDebounce;
  Timer? _booksFallbackTimer;
'''
new_fields = '''  final List<ShopOrder> _localOrders = [];
  final List<Map<String, dynamic>> _customerNotices = [];
  final Map<String, int> _cart = {};
  final Set<String> _favorites = {};
  RealtimeChannel? _booksChannel;
  Timer? _booksRealtimeDebounce;
  Timer? _booksFallbackTimer;
  Timer? _orderStatusTimer;
  bool _orderStatusRefreshing = false;

  List<Map<String, dynamic>> get customerNotices =>
      List.unmodifiable(_customerNotices);
  int get unreadCustomerNoticeCount =>
      _customerNotices.where((n) => n['read'] != true).length;
  Map<String, dynamic>? get latestUnreadCustomerNotice {
    for (final notice in _customerNotices) {
      if (notice['read'] != true) return notice;
    }
    return null;
  }
'''
state = replace_once(state, old_fields, new_fields, 'notice fields')

old_load_orders = '''    _localOrders
      ..clear()
      ..addAll(await _local.loadOrders());

    if (backendConfigured) {'''
new_load_orders = '''    _localOrders
      ..clear()
      ..addAll(await _local.loadOrders());
    _customerNotices
      ..clear()
      ..addAll(await _local.loadCustomerNotices());

    if (backendConfigured) {'''
state = replace_once(state, old_load_orders, new_load_orders, 'load notices')

old_start = '''      unawaited(_registerInstallation());
      await refreshBooks();
      _startLiveBooksSync();
    }
'''
new_start = '''      unawaited(_registerInstallation());
      await refreshBooks();
      _startLiveBooksSync();
      await _refreshCustomerOrderStatusesQuietly();
      _orderStatusTimer?.cancel();
      _orderStatusTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _refreshCustomerOrderStatusesQuietly(),
      );
    }
'''
state = replace_once(state, old_start, new_start, 'start order notice polling')

notice_methods = '''
  Future<void> markCustomerNoticesRead() async {
    var changed = false;
    for (final notice in _customerNotices) {
      if (notice['read'] != true) {
        notice['read'] = true;
        changed = true;
      }
    }
    if (!changed) return;
    await _local.saveCustomerNotices(_customerNotices);
    notifyListeners();
  }

  Future<void> _refreshCustomerOrderStatusesQuietly() async {
    if (_backend == null || _localOrders.isEmpty || _orderStatusRefreshing) {
      return;
    }
    _orderStatusRefreshing = true;
    try {
      final uuidIds = _localOrders
          .map((o) => o.id)
          .where((id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
          .toList();
      if (uuidIds.isEmpty) return;
      final statuses = await _backend!.fetchOrderStatuses(uuidIds);
      var ordersChanged = false;
      var noticesChanged = false;
      for (var i = 0; i < _localOrders.length; i++) {
        final oldOrder = _localOrders[i];
        final row = statuses[oldOrder.id];
        if (row == null) continue;
        final newStatus = (row['status'] ?? oldOrder.status).toString();
        final newReserved =
            row['stock_reserved'] as bool? ?? oldOrder.stockReserved;
        if (newStatus == oldOrder.status &&
            newReserved == oldOrder.stockReserved) {
          continue;
        }
        _localOrders[i] = oldOrder.copyWith(
          status: newStatus,
          stockReserved: newReserved,
        );
        ordersChanged = true;

        if (newStatus != oldOrder.status &&
            (newStatus == 'accepted' || newStatus == 'shipping')) {
          final noticeId = '${oldOrder.id}:$newStatus';
          final exists = _customerNotices.any(
            (n) => (n['id'] ?? '').toString() == noticeId,
          );
          if (!exists) {
            _customerNotices.insert(0, {
              'id': noticeId,
              'order_id': oldOrder.id,
              'status': newStatus,
              'title': newStatus == 'accepted'
                  ? '✅ Buyurtmangiz qabul qilindi'
                  : '🚚 Buyurtmangiz jo‘natildi',
              'message': newStatus == 'accepted'
                  ? 'Buyurtmangiz tasdiqlandi va tayyorlanmoqda.'
                  : 'Buyurtmangiz jo‘natildi. Yetkazib berish 1–3 ish kuni.',
              'created_at': DateTime.now().toIso8601String(),
              'read': false,
            });
            noticesChanged = true;
          }
        }
      }
      if (_customerNotices.length > 50) {
        _customerNotices.removeRange(50, _customerNotices.length);
        noticesChanged = true;
      }
      if (ordersChanged) await _local.saveOrders(_localOrders);
      if (noticesChanged) {
        await _local.saveCustomerNotices(_customerNotices);
      }
      if (ordersChanged || noticesChanged) notifyListeners();
    } catch (_) {
      // A temporary network failure must not break the customer UI.
    } finally {
      _orderStatusRefreshing = false;
    }
  }

'''
anchor = '  void _sanitizeCart() {'
if anchor not in state:
    raise SystemExit('Missing patch anchor: sanitize cart')
state = state.replace(anchor, notice_methods + anchor, 1)

state = replace_once(
    state,
    '''    _booksRealtimeDebounce?.cancel();
    _booksFallbackTimer?.cancel();
''',
    '''    _booksRealtimeDebounce?.cancel();
    _booksFallbackTimer?.cancel();
    _orderStatusTimer?.cancel();
''',
    'dispose order timer',
)
state_path.write_text(state, encoding='utf-8')

# -------------------------
# Store UI: bell badge + notification center + snackbar
# -------------------------
ui_path = Path('lib/store_ui.dart')
ui = ui_path.read_text(encoding='utf-8')

ui = replace_once(
    ui,
    '''class _StoreShellState extends State<StoreShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<AppState, int>((s) => s.cartCount);
''',
    '''class _StoreShellState extends State<StoreShell> {
  int index = 0;
  String? _lastPresentedNoticeId;

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<AppState, int>((s) => s.cartCount);
    final latestNoticeId = context.select<AppState, String?>(
      (s) => s.latestUnreadCustomerNotice?['id']?.toString(),
    );
    if (latestNoticeId != null && latestNoticeId != _lastPresentedNoticeId) {
      _lastPresentedNoticeId = latestNoticeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notice = context.read<AppState>().latestUnreadCustomerNotice;
        if (notice == null || notice['id']?.toString() != latestNoticeId) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                (notice['title'] ?? 'Buyurtma yangilandi').toString(),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
      });
    }
''',
    'store shell notice snackbar',
)

old_bell = '''              IconButton(
                tooltip: 'Bildirishnomalar',
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: UzbekCustomerColors.navy,
                ),
              ),'''
new_bell = '''              Badge(
                isLabelVisible: state.unreadCustomerNoticeCount > 0,
                label: Text('${state.unreadCustomerNoticeCount}'),
                child: IconButton(
                  tooltip: 'Bildirishnomalar',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerNotificationsPage(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: UzbekCustomerColors.navy,
                  ),
                ),
              ),'''
ui = replace_once(ui, old_bell, new_bell, 'notification bell')

page = '''class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState
    extends State<CustomerNotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().markCustomerNoticesRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notices = context.watch<AppState>().customerNotices;
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Bildirishnomalar'),
      ),
      body: notices.isEmpty
          ? const Center(
              child: Text(
                'Hozircha bildirishnoma yo‘q',
                style: TextStyle(color: UzbekCustomerColors.textMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              itemCount: notices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final notice = notices[i];
                final status = (notice['status'] ?? '').toString();
                final created = DateTime.tryParse(
                  (notice['created_at'] ?? '').toString(),
                );
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: status == 'shipping'
                          ? UzbekCustomerColors.goldSoft
                          : const Color(0xFFE8F5EE),
                      child: Icon(
                        status == 'shipping'
                            ? Icons.local_shipping_rounded
                            : Icons.check_circle_rounded,
                        color: status == 'shipping'
                            ? UzbekCustomerColors.goldDeep
                            : UzbekCustomerColors.success,
                      ),
                    ),
                    title: Text(
                      (notice['title'] ?? 'Buyurtma yangilandi').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text(
                          (notice['message'] ?? '').toString(),
                          style: const TextStyle(height: 1.4),
                        ),
                        if (created != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy.MM.dd HH:mm')
                                .format(created.toLocal()),
                            style: const TextStyle(
                              fontSize: 11,
                              color: UzbekCustomerColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

'''
anchor_ui = 'class _StoreHeader extends StatelessWidget {'
if anchor_ui not in ui:
    raise SystemExit('Missing patch anchor: store header')
ui = ui.replace(anchor_ui, page + anchor_ui, 1)
ui_path.write_text(ui, encoding='utf-8')

print('Patched admin silent refresh + customer in-app order notices v2')
