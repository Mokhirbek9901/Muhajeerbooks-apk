import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'brand.dart';
import 'design_system.dart';

const _navy = Color(0xFF10213D);
const _orange = Color(0xFFFF8A00);
final _money = NumberFormat('#,###', 'en_US');
String _won(int value) => '₩${_money.format(value)}';

class _AdminApi {
  _AdminApi(this.secret);
  final String secret;
  SupabaseClient get client => Supabase.instance.client;

  Future<bool> verify() async {
    final result = await client.rpc(
      'admin_verify',
      params: {'p_secret': secret},
    );
    return result == true;
  }

  Future<List<Book>> books() async {
    final data = await client.rpc(
      'admin_list_books',
      params: {'p_secret': secret},
    );
    return (data as List)
        .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveBook(Book book) async {
    await client.rpc(
      'admin_save_book',
      params: {
        'p_secret': secret,
        'p_id':
            book.id.isEmpty ||
                book.id.startsWith('local-') ||
                book.id.startsWith('telegram-')
            ? null
            : book.id,
        'p_data': {
          'title': book.title,
          'author': book.author,
          'category': book.category,
          'description': book.description,
          'price': book.price,
          'stock': book.stock,
          'discount_percent': book.discountPercent,
          'image_url': book.imageUrl,
          'is_active': book.isActive,
          'cover': book.coverType,
          'cost_price': book.costPrice,
          'recommended': book.recommended,
        },
      },
    );
  }

  Future<String> uploadCover(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('Rasm bo‘sh.');
    if (bytes.length > 7 * 1024 * 1024) {
      throw StateError('Rasm hajmi 7 MB dan kichik bo‘lishi kerak.');
    }

    final lower = file.name.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';

    final response = await client.functions.invoke(
      'admin-cover-upload',
      body: {
        'admin_code': secret,
        'file_name': file.name,
        'content_type': contentType,
        'data_base64': base64Encode(bytes),
      },
    );

    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final url = (data['url'] ?? '').toString();
    if (url.isEmpty) {
      throw StateError((data['error'] ?? 'Rasm yuklanmadi.').toString());
    }
    return url;
  }

  Future<void> deleteBook(String id) async {
    await client.rpc(
      'admin_delete_book',
      params: {'p_secret': secret, 'p_id': id},
    );
  }

  Future<void> applyDiscount(int percent) async {
    await client.rpc(
      'admin_apply_discount',
      params: {'p_secret': secret, 'p_percent': percent},
    );
  }

  Future<void> clearDiscounts() async {
    await client.rpc('admin_clear_discounts', params: {'p_secret': secret});
  }

  Future<List<ShopOrder>> orders() async {
    final data = await client.rpc(
      'admin_list_orders',
      params: {'p_secret': secret},
    );
    return (data as List)
        .map((e) => ShopOrder.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String> paymentProofUrl(String path) async {
    final response = await client.functions.invoke(
      'payment-proof',
      body: {'action': 'view', 'admin_code': secret, 'path': path},
    );
    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final url = (data['url'] ?? '').toString();
    if (url.isEmpty)
      throw StateError((data['error'] ?? 'Chek ochilmadi.').toString());
    return url;
  }

  Future<void> setStock(Book book, int value) async {
    await saveBook(book.copyWith(stock: value < 0 ? 0 : value));
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await client.rpc(
      'admin_update_order_status',
      params: {'p_secret': secret, 'p_id': id, 'p_status': status},
    );
  }

  Future<Map<String, dynamic>> userStats() async {
    final raw = await client.rpc(
      'admin_user_stats',
      params: {'p_secret': secret},
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> customers() async {
    final raw = await client.rpc(
      'admin_list_customers',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

class AdminGatePage extends StatefulWidget {
  const AdminGatePage({super.key});

  @override
  State<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends State<AdminGatePage> {
  final code = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final value = code.text.trim();
    if (value.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = _AdminApi(value);
      if (!await api.verify()) {
        if (mounted) setState(() => error = 'Admin kodi noto‘g‘ri.');
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminDashboardPage(secret: value)),
      );
    } catch (_) {
      if (mounted)
        setState(() => error = 'Kirishda xatolik. Internetni tekshiring.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: AppSurface(
                padding: const EdgeInsets.all(24),
                shadow: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MuhajeerLogoBadge(size: 92, radius: 25),
                    const SizedBox(height: 18),
                    Text(
                      'Muhajeer Books Admin',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Savdo, ombor, kitoblar va buyurtmalarni xavfsiz boshqarish markazi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: code,
                      obscureText: obscure,
                      autofocus: false,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Admin kodi',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      AppInfoPill(
                        icon: Icons.error_outline_rounded,
                        label: error!,
                        foreground: AppColors.danger,
                        background: AppColors.dangerSoft,
                        border: const Color(0xFFFFCCD1),
                      ),
                    ],
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: loading ? null : _login,
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(
                          loading
                              ? 'Tekshirilmoqda...'
                              : 'Boshqaruv paneliga kirish',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Himoyalangan admin kirishi',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.secret});
  final String secret;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int tab = 0;
  late final _AdminApi api;
  Timer? _liveRefreshTimer;
  final _overviewKey = GlobalKey<_OverviewAdminState>();
  final _booksKey = GlobalKey<_BooksAdminState>();
  final _inventoryKey = GlobalKey<_InventoryAdminState>();
  final _ordersKey = GlobalKey<_OrdersAdminState>();

  static const titles = [
    'Boshqaruv markazi',
    'Kitoblar',
    'Ombor',
    'Buyurtmalar',
    'Mijozlar',
    'Chegirmalar',
  ];
  static const icons = [
    Icons.dashboard_rounded,
    Icons.menu_book_rounded,
    Icons.inventory_2_rounded,
    Icons.receipt_long_rounded,
    Icons.people_alt_rounded,
    Icons.percent_rounded,
  ];

  @override
  void initState() {
    super.initState();
    api = _AdminApi(widget.secret);
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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
      }
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OverviewAdmin(key: _overviewKey, api: api),
      _BooksAdmin(key: _booksKey, api: api),
      _InventoryAdmin(key: _inventoryKey, api: api),
      _OrdersAdmin(key: _ordersKey, api: api),
      _DiscountAdmin(api: api),
    ];
    const railDestinations = [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: Text('Bosh sahifa'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book_rounded),
        label: Text('Kitoblar'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2_rounded),
        label: Text('Ombor'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: Text('Buyurtmalar'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.percent_rounded),
        label: Text('Chegirma'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final extended = constraints.maxWidth >= 1180;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                if (!desktop) ...[
                  const MuhajeerLogoBadge(
                    size: 36,
                    radius: 10,
                    showShadow: false,
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titles[tab],
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const Text(
                        'Muhajeer Books boshqaruvi',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 14),
                child: AppInfoPill(
                  icon: Icons.cloud_done_rounded,
                  label: 'Onlayn',
                  foreground: AppColors.success,
                  background: AppColors.successSoft,
                  border: Color(0xFFCDEAD7),
                ),
              ),
            ],
          ),
          body: desktop
              ? Row(
                  children: [
                    NavigationRail(
                      extended: extended,
                      selectedIndex: tab,
                      onDestinationSelected: (v) => setState(() => tab = v),
                      labelType: extended
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.selected,
                      groupAlignment: -.72,
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 20),
                        child: extended
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MuhajeerLogoBadge(
                                    size: 46,
                                    radius: 13,
                                    showShadow: false,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Muhajeer\nBooks',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              )
                            : const MuhajeerLogoBadge(
                                size: 46,
                                radius: 13,
                                showShadow: false,
                              ),
                      ),
                      destinations: railDestinations,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: IndexedStack(index: tab, children: pages),
                    ),
                  ],
                )
              : IndexedStack(index: tab, children: pages),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (v) => setState(() => tab = v),
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  destinations: List.generate(
                    titles.length,
                    (i) => NavigationDestination(
                      icon: Icon(icons[i]),
                      label: i == 0 ? 'Bosh' : titles[i],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _OverviewData {
  const _OverviewData(this.books, this.orders);
  final List<Book> books;
  final List<ShopOrder> orders;
}

class _OverviewAdmin extends StatefulWidget {
  const _OverviewAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_OverviewAdmin> createState() => _OverviewAdminState();
}

class _OverviewAdminState extends State<_OverviewAdmin> {
  late Future<_OverviewData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_OverviewData> load() async =>
      _OverviewData(await widget.api.books(), await widget.api.orders());
  void reload() {
    if (mounted) setState(() => future = load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_OverviewData>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (snap.hasError) {
        return Center(
          child: AppSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 44,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ma’lumotni yuklab bo‘lmadi',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Qayta urinish'),
                ),
              ],
            ),
          ),
        );
      }
      final data = snap.data ?? const _OverviewData([], []);
      final books = data.books;
      final orders = data.orders;
      final now = DateTime.now();
      final todayOrders = orders
          .where(
            (o) =>
                o.createdAt.year == now.year &&
                o.createdAt.month == now.month &&
                o.createdAt.day == now.day,
          )
          .length;
      final newOrders = orders.where((o) => o.status == 'new').length;
      final proofOrders = orders
          .where((o) => o.status == 'new' && o.hasPaymentProof)
          .length;
      final activeRevenue = orders
          .where(
            (o) => ['accepted', 'paid', 'shipping', 'done'].contains(o.status),
          )
          .fold<int>(0, (sum, o) => sum + o.total);
      final completedRevenue = orders
          .where((o) => o.status == 'done')
          .fold<int>(0, (sum, o) => sum + o.total);
      final totalStock = books.fold<int>(0, (sum, b) => sum + b.stock);
      final lowStock = books.where((b) => b.stock <= 2).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));
      final recent = orders.take(5).toList();
      final activeStatuses = {'accepted', 'paid', 'shipping', 'done'};
      final activeOrders = orders
          .where((o) => activeStatuses.contains(o.status))
          .toList();
      final monthOrders = orders.where((o) {
        return o.createdAt.year == now.year &&
            o.createdAt.month == now.month &&
            o.status != 'cancelled';
      }).toList();
      final monthRevenue = monthOrders
          .where((o) => activeStatuses.contains(o.status))
          .fold<int>(0, (sum, o) => sum + o.total);
      final todayRevenue = orders
          .where((o) {
            return o.createdAt.year == now.year &&
                o.createdAt.month == now.month &&
                o.createdAt.day == now.day &&
                activeStatuses.contains(o.status);
          })
          .fold<int>(0, (sum, o) => sum + o.total);
      final averageOrder = activeOrders.isEmpty
          ? 0
          : activeRevenue ~/ activeOrders.length;
      final acceptedOrders = orders.where((o) => o.status == 'accepted').length;
      final shippingOrders = orders.where((o) => o.status == 'shipping').length;
      final doneOrders = orders.where((o) => o.status == 'done').length;
      final cancelledOrders = orders
          .where((o) => o.status == 'cancelled')
          .length;
      final outOfStock = books.where((b) => b.stock == 0).length;
      final completionRate = orders.isEmpty
          ? 0
          : ((doneOrders / orders.length) * 100).round();
      final cancelRate = orders.isEmpty
          ? 0
          : ((cancelledOrders / orders.length) * 100).round();

      return RefreshIndicator(
        onRefresh: () async => reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            AppPageHeading(
              title: 'Boshqaruv markazi',
              subtitle: 'Savdo, buyurtmalar va ombor holati real vaqtga yaqin ko‘rinishda.',
              trailing: IconButton.filledTonal(
                onPressed: reload,
                tooltip: 'Yangilash',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, c) {
                final cardWidth = c.maxWidth >= 1200
                    ? (c.maxWidth - 36) / 4
                    : c.maxWidth >= 760
                    ? (c.maxWidth - 24) / 3
                    : c.maxWidth >= 480
                    ? (c.maxWidth - 12) / 2
                    : c.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.new_releases_outlined,
                        label: 'Yangi buyurtmalar',
                        value: '$newOrders',
                        accent: AppColors.orange,
                        note: proofOrders > 0
                            ? '$proofOrders ta chek kutilmoqda'
                            : 'Tekshirish navbati',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.today_outlined,
                        label: 'Bugungi buyurtma',
                        value: '$todayOrders',
                        accent: AppColors.info,
                        note: DateFormat('yyyy.MM.dd').format(now),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'Ombordagi dona',
                        value: '$totalStock',
                        accent: const Color(0xFF6B5DD3),
                        note: '${books.length} xil kitob',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.payments_outlined,
                        label: 'Faol savdo',
                        value: _won(activeRevenue),
                        accent: AppColors.success,
                        note: 'Qabul qilingan buyurtmalar',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.task_alt_rounded,
                        label: 'Yakunlangan savdo',
                        value: _won(completedRevenue),
                        accent: AppColors.navy,
                        note: 'Yakunlangan buyurtmalar',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.warning_amber_rounded,
                        label: 'Kam qolgan kitob',
                        value: '${lowStock.length}',
                        accent: AppColors.warning,
                        note: '2 dona yoki undan kam',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.calendar_month_outlined,
                        label: 'Bu oy savdo',
                        value: _won(monthRevenue),
                        accent: AppColors.info,
                        note: '${monthOrders.length} ta buyurtma',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.calculate_outlined,
                        label: 'O‘rtacha buyurtma',
                        value: _won(averageOrder),
                        accent: const Color(0xFF7A5AF8),
                        note: 'Faol buyurtmalar bo‘yicha',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.point_of_sale_outlined,
                        label: 'Bugungi savdo',
                        value: _won(todayRevenue),
                        accent: AppColors.success,
                        note: '$todayOrders ta buyurtma',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.remove_shopping_cart_outlined,
                        label: 'Tugagan kitob',
                        value: '$outOfStock',
                        accent: AppColors.danger,
                        note: 'Omborda 0 dona',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            AppSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'Buyurtmalar statistikasi',
                    subtitle: 'Holatlar va ishlov berish ko‘rsatkichlari',
                    icon: Icons.analytics_outlined,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppInfoPill(
                        icon: Icons.fiber_new_rounded,
                        label: '$newOrders yangi',
                        foreground: AppColors.orange,
                        background: AppColors.warningSoft,
                      ),
                      AppInfoPill(
                        icon: Icons.inventory_rounded,
                        label: '$acceptedOrders qabul qilingan',
                        foreground: AppColors.success,
                        background: AppColors.successSoft,
                      ),
                      AppInfoPill(
                        icon: Icons.local_shipping_rounded,
                        label: '$shippingOrders jo‘natilgan',
                        foreground: AppColors.info,
                        background: const Color(0xFFEAF2FF),
                      ),
                      AppInfoPill(
                        icon: Icons.task_alt_rounded,
                        label: '$doneOrders yakunlangan',
                        foreground: AppColors.navy,
                        background: AppColors.surfaceSoft,
                      ),
                      AppInfoPill(
                        icon: Icons.cancel_outlined,
                        label: '$cancelledOrders bekor',
                        foreground: AppColors.danger,
                        background: AppColors.dangerSoft,
                      ),
                      AppInfoPill(
                        icon: Icons.receipt_long_outlined,
                        label: '$proofOrders yangi chek',
                        foreground: AppColors.success,
                        background: AppColors.successSoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AdminProgressStat(
                    label: 'Yakunlangan buyurtmalar',
                    value: completionRate,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  _AdminProgressStat(
                    label: 'Bekor qilingan buyurtmalar',
                    value: cancelRate,
                    color: AppColors.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final lowCard = AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSectionHeader(
                        title: 'Ombor nazorati',
                        subtitle: 'Eng avval e’tibor beriladigan qoldiqlar',
                        icon: Icons.warning_amber_rounded,
                        trailing: AppInfoPill(label: '${lowStock.length} ta'),
                      ),
                      const SizedBox(height: 12),
                      if (lowStock.isEmpty)
                        const AppInfoPill(
                          icon: Icons.check_circle_rounded,
                          label: 'Hamma qoldiq yaxshi',
                          foreground: AppColors.success,
                          background: AppColors.successSoft,
                          border: Color(0xFFCDEAD7),
                        )
                      else
                        ...lowStock
                            .take(6)
                            .map(
                              (b) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: _AdminBookThumb(url: b.imageUrl),
                                title: Text(
                                  b.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  _won(b.currentPrice),
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                trailing: AppInfoPill(
                                  label: '${b.stock} dona',
                                  foreground: b.stock == 0
                                      ? AppColors.danger
                                      : AppColors.warning,
                                  background: b.stock == 0
                                      ? AppColors.dangerSoft
                                      : AppColors.warningSoft,
                                  border: b.stock == 0
                                      ? const Color(0xFFFFCCD1)
                                      : const Color(0xFFFFDCA0),
                                ),
                              ),
                            ),
                    ],
                  ),
                );
                final recentCard = AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSectionHeader(
                        title: 'So‘nggi buyurtmalar',
                        subtitle: 'Yaqinda kelgan mijoz buyurtmalari',
                        icon: Icons.receipt_long_outlined,
                        trailing: AppInfoPill(label: '${orders.length} ta'),
                      ),
                      const SizedBox(height: 12),
                      if (recent.isEmpty)
                        const Text(
                          'Hozircha buyurtma yo‘q.',
                          style: TextStyle(color: AppColors.muted),
                        )
                      else
                        ...recent.map(
                          (o) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 19,
                              ),
                            ),
                            title: Text(
                              o.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('MM.dd • HH:mm').format(o.createdAt),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _AdminOrderStatusChip(status: o.status),
                                const SizedBox(height: 3),
                                Text(
                                  _won(o.total),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
                if (!wide)
                  return Column(
                    children: [recentCard, const SizedBox(height: 12), lowCard],
                  );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: recentCard),
                    const SizedBox(width: 12),
                    Expanded(child: lowCard),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _AdminProgressStat extends StatelessWidget {
  const _AdminProgressStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$safeValue%',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: safeValue / 100,
            minHeight: 8,
            backgroundColor: AppColors.surfaceSoft,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE6E8EC)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InventoryAdmin extends StatefulWidget {
  const _InventoryAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_InventoryAdmin> createState() => _InventoryAdminState();
}

class _InventoryAdminState extends State<_InventoryAdmin> {
  final Set<String> busy = {};
  List<Book> all = [];
  String query = '';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final loaded = await widget.api.books();
      loaded.sort((a, b) {
        final stockCompare = a.stock.compareTo(b.stock);
        if (stockCompare != 0) return stockCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        all = loaded;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> loadQuietly() => _load(showLoading: false);

  Future<void> change(Book book, int delta) async {
    if (busy.contains(book.id)) return;
    final index = all.indexWhere((b) => b.id == book.id);
    if (index < 0) return;

    final oldBook = all[index];
    final newStock = (oldBook.stock + delta).clamp(0, 99999).toInt();
    if (newStock == oldBook.stock) return;
    final updated = oldBook.copyWith(stock: newStock);

    setState(() {
      busy.add(book.id);
      all[index] = updated;
    });

    try {
      await widget.api.setStock(updated, newStock);
      context.read<AppState>().refreshBooks();
    } catch (e) {
      if (!mounted) return;
      setState(() => all[index] = oldBook);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ombor xatosi: $e')));
    } finally {
      if (mounted) setState(() => busy.remove(book.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visibleBooks = all
        .where((b) => q.isEmpty || b.title.toLowerCase().contains(q))
        .toList();
    final total = all.fold<int>(0, (s, b) => s + b.stock);
    final low = all.where((b) => b.stock <= 2).length;
    final out = all.where((b) => b.stock == 0).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeading(
                title: 'Ombor boshqaruvi',
                subtitle: 'Qoldiqni tez o‘zgartiring. +/− bosilganda kitob joyi o‘zgarmaydi.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppInfoPill(
                    icon: Icons.inventory_2_outlined,
                    label: '$total dona',
                  ),
                  AppInfoPill(
                    icon: Icons.warning_amber_rounded,
                    label: '$low kam qolgan',
                    foreground: AppColors.warning,
                    background: AppColors.warningSoft,
                  ),
                  AppInfoPill(
                    icon: Icons.remove_shopping_cart_outlined,
                    label: '$out tugagan',
                    foreground: AppColors.danger,
                    background: AppColors.dangerSoft,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  hintText: 'Kitob nomi bo‘yicha qidiring...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ],
          ),
        ),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (error != null)
          Expanded(
            child: Center(
              child: AppSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 42,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Omborni yuklab bo‘lmadi',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (visibleBooks.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Kitob topilmadi',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: visibleBooks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final b = visibleBooks[i];
                final isBusy = busy.contains(b.id);
                return Card(
                  key: ValueKey(b.id),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        _AdminBookThumb(url: b.imageUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_won(b.currentPrice)} • ${b.stock == 0
                                    ? 'Tugagan'
                                    : b.stock <= 2
                                    ? 'Kam qolgan'
                                    : 'Qoldiq yaxshi'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: b.stock == 0
                                      ? AppColors.danger
                                      : b.stock <= 2
                                      ? AppColors.warning
                                      : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.outlined(
                              onPressed: isBusy ? null : () => change(b, -1),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(
                                '${b.stock}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: isBusy ? null : () => change(b, 1),
                              icon: const Icon(Icons.add_rounded),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<int>(
                              enabled: !isBusy,
                              tooltip: 'Tez qo‘shish',
                              onSelected: (v) => change(b, v),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 5, child: Text('+5 dona')),
                                PopupMenuItem(
                                  value: 10,
                                  child: Text('+10 dona'),
                                ),
                                PopupMenuItem(
                                  value: 20,
                                  child: Text('+20 dona'),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: isBusy
                                  ? const Padding(
                                      padding: EdgeInsets.all(3),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
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
  }
}

class _BooksAdmin extends StatefulWidget {
  const _BooksAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_BooksAdmin> createState() => _BooksAdminState();
}

class _BooksAdminState extends State<_BooksAdmin> {
  String query = '';
  late Future<List<Book>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.books();
  }

  void reload({bool syncStore = true}) {
    if (!mounted) return;
    setState(() => future = widget.api.books());
    if (syncStore) {
      context.read<AppState>().refreshBooks();
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
                  q.isEmpty ||
                  b.title.toLowerCase().contains(q) ||
                  b.author.toLowerCase().contains(q),
            )
            .toList();
        final totalStock = all.fold<int>(0, (s, b) => s + b.stock);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(label: 'Kitob', value: '${all.length}'),
                      _MiniStat(label: 'Ombor', value: '$totalStock dona'),
                      _MiniStat(
                        label: 'Rasmli',
                        value:
                            '${all.where((b) => b.imageUrl.isNotEmpty).length}',
                      ),
                      _MiniStat(
                        label: 'Kam qolgan',
                        value: '${all.where((b) => b.stock <= 2).length}',
                      ),
                    ],
                  ),
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
            if (snap.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (snap.hasError)
              Expanded(child: Center(child: Text('Xatolik: ${snap.error}')))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = books[i];
                    return Card(
                      child: ListTile(
                        leading: _AdminBookThumb(url: b.imageUrl),
                        title: Text(
                          b.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${b.author} • ${b.stock} dona • ${_won(b.currentPrice)}${b.isActive ? '' : ' • Yashirilgan'}',
                        ),
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

class _AdminBookThumb extends StatelessWidget {
  const _AdminBookThumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: 48,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.menu_book_rounded, color: _navy),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 48,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 48,
          height: 64,
          alignment: Alignment.center,
          color: const Color(0xFFF2F3F5),
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE7E9ED)),
    ),
    child: Text(
      '$label: $value',
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

class _BookForm extends StatefulWidget {
  const _BookForm({required this.api, this.book});
  final _AdminApi api;
  final Book? book;

  @override
  State<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<_BookForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController author;
  late final TextEditingController category;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController stock;
  late final TextEditingController discount;
  late final TextEditingController image;
  late final TextEditingController cost;
  final picker = ImagePicker();
  String cover = 'Ko‘rsatilmagan';
  bool active = true;
  bool recommended = false;
  bool saving = false;
  bool uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    title = TextEditingController(text: b?.title ?? '');
    author = TextEditingController(
      text: b?.author == 'Ko‘rsatilmagan' ? '' : b?.author ?? '',
    );
    category = TextEditingController(text: b?.category ?? 'Boshqalar');
    description = TextEditingController(text: b?.description ?? '');
    price = TextEditingController(text: b == null ? '' : '${b.price}');
    stock = TextEditingController(text: b == null ? '' : '${b.stock}');
    discount = TextEditingController(
      text: b == null ? '0' : '${b.discountPercent}',
    );
    image = TextEditingController(text: b?.imageUrl ?? '');
    cost = TextEditingController(
      text: b == null || b.costPrice == 0 ? '' : '${b.costPrice}',
    );
    cover = b?.coverType ?? 'Ko‘rsatilmagan';
    active = b?.isActive ?? true;
    recommended = b?.recommended ?? false;
    image.addListener(_imageChanged);
  }

  void _imageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    image.removeListener(_imageChanged);
    for (final c in [
      title,
      author,
      category,
      description,
      price,
      stock,
      discount,
      image,
      cost,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController c,
    String label, {
    bool number = false,
    bool required = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: TextFormField(
      controller: c,
      minLines: lines > 1 ? 4 : 1,
      maxLines: lines,
      keyboardType: number
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      textInputAction: number
          ? TextInputAction.next
          : lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      enableSuggestions: !number,
      autocorrect: !number,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Majburiy' : null
          : null,
    ),
  );

  Future<void> _pasteDescription() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text ?? '';
    if (pasted.isEmpty) return;

    final source = description.text;
    final selection = description.selection;
    final rawStart = selection.isValid ? selection.start : source.length;
    final rawEnd = selection.isValid ? selection.end : source.length;
    final start = rawStart.clamp(0, source.length).toInt();
    final end = rawEnd.clamp(start, source.length).toInt();
    final next = source.replaceRange(start, end, pasted);

    description.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + pasted.length),
    );
    if (mounted) setState(() {});
  }

  Future<void> _copyDescription() async {
    final text = description.text;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Tavsif nusxalandi ✅')));
  }

  void _clearDescription() {
    description.clear();
    setState(() {});
  }

  Widget _descriptionEditor() => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: description,
          minLines: 6,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          enableInteractiveSelection: true,
          enableSuggestions: true,
          autocorrect: true,
          decoration: const InputDecoration(
            labelText: 'Tavsif',
            alignLabelWithHint: true,
            hintText: 'Kitob haqida tavsifni yozing yoki pastdagi “Qo‘yish” tugmasidan foydalaning.',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _pasteDescription,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: const Text('Qo‘yish'),
            ),
            OutlinedButton.icon(
              onPressed: description.text.isEmpty ? null : _copyDescription,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Nusxa olish'),
            ),
            TextButton.icon(
              onPressed: description.text.isEmpty ? null : _clearDescription,
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: const Text('Tozalash'),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          '“Qo‘yish” clipboarddagi matnni aynan kursor turgan joyga qo‘shadi.',
          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    ),
  );

  Future<void> pickAndUploadImage() async {
    if (uploadingImage) return;
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (picked == null) return;
      setState(() => uploadingImage = true);
      final url = await widget.api.uploadCover(picked);
      if (!mounted) return;
      image.text = url;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kitob rasmi yuklandi ✅')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rasm yuklashda xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => uploadingImage = false);
    }
  }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    final p = int.tryParse(price.text.trim()) ?? -1;
    final s = int.tryParse(stock.text.trim()) ?? -1;
    final d = int.tryParse(discount.text.trim()) ?? 0;
    final c = int.tryParse(cost.text.trim()) ?? 0;
    if (p < 0 || s < 0 || d < 0 || d > 99 || c < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Narx, ombor yoki chegirma qiymatini tekshiring.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.api.saveBook(
        Book(
          id: widget.book?.id ?? '',
          legacyId: widget.book?.legacyId,
          title: title.text.trim(),
          author: author.text.trim().isEmpty
              ? 'Ko‘rsatilmagan'
              : author.text.trim(),
          category: category.text.trim().isEmpty
              ? 'Boshqalar'
              : category.text.trim(),
          description: description.text.trim().isEmpty
              ? 'Ma’lumot kiritilmagan.'
              : description.text.trim(),
          price: p,
          stock: s,
          discountPercent: d,
          imageUrl: image.text.trim(),
          isActive: active,
          coverType: cover,
          costPrice: c,
          recommended: recommended,
          createdAt: widget.book?.createdAt,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saqlashda xatolik: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = image.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book == null ? 'Kitob qo‘shish' : 'Kitobni tahrirlash',
        ),
      ),
      body: Form(
        key: key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 150,
                height: 210,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E6EA)),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isEmpty
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 46,
                            color: _navy,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Rasm yo‘q',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 44),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: uploadingImage ? null : pickAndUploadImage,
                icon: uploadingImage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  uploadingImage
                      ? 'Yuklanmoqda...'
                      : imageUrl.isEmpty
                      ? 'Rasm tanlash'
                      : 'Rasmni almashtirish',
                ),
              ),
            ),
            if (imageUrl.isNotEmpty)
              Center(
                child: TextButton.icon(
                  onPressed: uploadingImage ? null : () => image.clear(),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Rasmni olib tashlash'),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Telefon galereyasidan JPG, PNG yoki WEBP rasm tanlang. Maksimal hajm: 7 MB.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            field(title, 'Kitob nomi', required: true),
            field(author, 'Muallif'),
            field(category, 'Kategoriya'),
            _descriptionEditor(),
            Row(
              children: [
                Expanded(
                  child: field(
                    price,
                    'Asl narx (₩)',
                    number: true,
                    required: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: field(stock, 'Ombor', number: true, required: true),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: field(discount, 'Chegirma %', number: true)),
                const SizedBox(width: 8),
                Expanded(child: field(cost, 'Tannarx (₩)', number: true)),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Rasm URL (ixtiyoriy)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Odatda yuqoridagi “Rasm tanlash” tugmasi yetadi.',
              ),
              children: [field(image, 'Muqova rasm URL')],
            ),
            DropdownButtonFormField<String>(
              initialValue:
                  [
                    'Qattiq',
                    'Yumshoq',
                    'Flexible',
                    'Ko‘rsatilmagan',
                  ].contains(cover)
                  ? cover
                  : 'Ko‘rsatilmagan',
              decoration: const InputDecoration(labelText: 'Muqova turi'),
              items: const [
                DropdownMenuItem(
                  value: 'Ko‘rsatilmagan',
                  child: Text('Ko‘rsatilmagan'),
                ),
                DropdownMenuItem(value: 'Qattiq', child: Text('Qattiq')),
                DropdownMenuItem(value: 'Yumshoq', child: Text('Yumshoq')),
                DropdownMenuItem(value: 'Flexible', child: Text('Flexible')),
              ],
              onChanged: (v) => cover = v ?? cover,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: active,
              onChanged: (v) => setState(() => active = v),
              title: const Text('Sotuvda ko‘rsatish'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: recommended,
              onChanged: (v) => setState(() => recommended = v),
              title: const Text('Tavsiya etilgan kitob'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving || uploadingImage ? null : save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersAdmin extends StatefulWidget {
  const _OrdersAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_OrdersAdmin> createState() => _OrdersAdminState();
}

class _OrdersAdminState extends State<_OrdersAdmin> {
  late Future<List<ShopOrder>> future;
  String filter = 'all';
  String query = '';
  final Set<String> busy = {};

  @override
  void initState() {
    super.initState();
    future = widget.api.orders();
  }

  void reload() {
    if (mounted) setState(() => future = widget.api.orders());
  }

  Future<void> changeStatus(ShopOrder order, String status) async {
    if (busy.contains(order.id)) return;
    if (status == 'accepted') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(
            Icons.inventory_2_rounded,
            color: Color(0xFF138A4B),
            size: 44,
          ),
          title: const Text('Buyurtmani qabul qilasizmi?'),
          content: const Text(
            'Qabul qilinganda buyurtmadagi kitoblar ombordagi qoldiqdan avtomatik ayriladi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Yo‘q'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Qabul qilish'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    if (status == 'cancelled') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Buyurtmani bekor qilish'),
          content: Text(
            order.stockReserved
                ? 'Bu buyurtma ombordan ajratilgan. Bekor qilsangiz kitoblar omborga avtomatik qaytariladi.'
                : 'Buyurtma bekor qilinsinmi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Yo‘q'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bekor qilish'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }

    setState(() => busy.add(order.id));
    try {
      await widget.api.updateOrderStatus(order.id, status);
      await context.read<AppState>().refreshBooks();
      if (mounted) {
        reload();
        final message = status == 'accepted'
            ? 'Buyurtma qabul qilindi. Ombor avtomatik kamaydi ✅'
            : status == 'cancelled'
            ? 'Buyurtma bekor qilindi.'
            : 'Buyurtma holati yangilandi.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    } finally {
      if (mounted) setState(() => busy.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopOrder>>(
      future: future,
      builder: (context, snap) {
        final all = snap.data ?? const <ShopOrder>[];
        final q = query.trim().toLowerCase();
        final orders = all.where((o) {
          final matchStatus = filter == 'all' || o.status == filter;
          final matchQuery =
              q.isEmpty ||
              o.customerName.toLowerCase().contains(q) ||
              o.phone.toLowerCase().contains(q) ||
              o.id.toLowerCase().contains(q);
          return matchStatus && matchQuery;
        }).toList();
        final newCount = all.where((o) => o.status == 'new').length;
        final proofCount = all
            .where((o) => o.status == 'new' && o.hasPaymentProof)
            .length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Buyurtmalar',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Badge(
                        isLabelVisible: newCount > 0,
                        label: Text('$newCount'),
                        child: IconButton.filledTonal(
                          onPressed: reload,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => query = v),
                          decoration: const InputDecoration(
                            hintText: 'Mijoz, telefon yoki buyurtma ID...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: proofCount > 0
                              ? const Color(0xFFEAF7EF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE6E8EC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_outlined,
                              size: 18,
                              color: Color(0xFF138A4B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$proofCount chek',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _OrderFilterChip(
                          label: 'Barchasi',
                          value: 'all',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Yangi',
                          value: 'new',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Qabul qilingan',
                          value: 'accepted',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Jo‘natilgan',
                          value: 'shipping',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Yakunlangan',
                          value: 'done',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Bekor',
                          value: 'cancelled',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (snap.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (snap.hasError)
              Expanded(child: Center(child: Text('Xatolik: ${snap.error}')))
            else if (orders.isEmpty)
              const Expanded(
                child: Center(child: Text('Bu bo‘limda buyurtma yo‘q')),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ProfessionalOrderCard(
                    order: orders[i],
                    api: widget.api,
                    loading: busy.contains(orders[i].id),
                    onStatus: (status) => changeStatus(orders[i], status),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrderFilterChip extends StatelessWidget {
  const _OrderFilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onTap(value),
    ),
  );
}

class _ProfessionalOrderCard extends StatelessWidget {
  const _ProfessionalOrderCard({
    required this.order,
    required this.api,
    required this.loading,
    required this.onStatus,
  });
  final ShopOrder order;
  final _AdminApi api;
  final bool loading;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _navy.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.receipt_long_rounded, color: _navy),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _AdminOrderStatusChip(status: order.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                _won(order.total),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Text(' • '),
              Expanded(
                child: Text(
                  order.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (order.hasPaymentProof)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.receipt_rounded,
                    size: 17,
                    color: Color(0xFF138A4B),
                  ),
                ),
            ],
          ),
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '№ ${order.id}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ),
              Text(
                DateFormat('yyyy.MM.dd HH:mm').format(order.createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '📱 ${order.phone}\n📍 ${order.address}\n🚚 ${order.deliveryType} • ${_won(order.deliveryFee)}',
              style: const TextStyle(height: 1.55),
            ),
          ),
          const SizedBox(height: 12),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['title']} × ${item['quantity']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    _won((item['line_total'] as num?)?.toInt() ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Text('Jami', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                _won(order.total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _navy,
                ),
              ),
            ],
          ),
          if (order.hasPaymentProof) ...[
            const SizedBox(height: 12),
            _PaymentProofPanel(api: api, path: order.paymentProofPath),
          ],
          const SizedBox(height: 14),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _OrderActions(order: order, onStatus: onStatus),
        ],
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({required this.order, required this.onStatus});
  final ShopOrder order;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    if (order.status == 'cancelled' || order.status == 'done')
      return const SizedBox.shrink();
    String? primaryStatus;
    String? primaryLabel;
    IconData? primaryIcon;
    if (order.status == 'new') {
      primaryStatus = 'accepted';
      primaryLabel = 'Qabul qilish';
      primaryIcon = Icons.check_circle_rounded;
    } else if (order.status == 'accepted' || order.status == 'paid') {
      primaryStatus = 'shipping';
      primaryLabel = 'Jo‘natildi';
      primaryIcon = Icons.local_shipping_rounded;
    } else if (order.status == 'shipping') {
      primaryStatus = 'done';
      primaryLabel = 'Yakunlash';
      primaryIcon = Icons.task_alt_rounded;
    }

    return Row(
      children: [
        if (primaryStatus != null)
          Expanded(
            child: FilledButton.icon(
              onPressed: () => onStatus(primaryStatus!),
              icon: Icon(primaryIcon),
              label: Text(primaryLabel!),
            ),
          ),
        if (primaryStatus != null) const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => onStatus('cancelled'),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Bekor'),
        ),
      ],
    );
  }
}

class _AdminOrderStatusChip extends StatelessWidget {
  const _AdminOrderStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, border, icon) = switch (status) {
      'accepted' => (
        'Qabul qilindi',
        AppColors.success,
        AppColors.successSoft,
        const Color(0xFFCDEAD7),
        Icons.inventory_2_rounded,
      ),
      'paid' => (
        'To‘landi',
        AppColors.info,
        AppColors.infoSoft,
        const Color(0xFFCFE0FA),
        Icons.verified_rounded,
      ),
      'shipping' => (
        'Jo‘natildi',
        AppColors.orange,
        const Color(0xFFFFF2E3),
        const Color(0xFFFFD4A3),
        Icons.local_shipping_rounded,
      ),
      'done' => (
        'Yakunlandi',
        AppColors.success,
        AppColors.successSoft,
        const Color(0xFFCDEAD7),
        Icons.task_alt_rounded,
      ),
      'cancelled' => (
        'Bekor',
        AppColors.danger,
        AppColors.dangerSoft,
        const Color(0xFFFFCCD1),
        Icons.cancel_rounded,
      ),
      _ => (
        'Yangi',
        AppColors.navy,
        AppColors.surfaceSoft,
        AppColors.border,
        Icons.new_releases_rounded,
      ),
    };
    return AppInfoPill(
      icon: icon,
      label: label,
      foreground: fg,
      background: bg,
      border: border,
    );
  }
}

class _PaymentProofPanel extends StatelessWidget {
  const _PaymentProofPanel({required this.api, required this.path});
  final _AdminApi api;
  final String path;

  Future<void> openProof(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final url = await api.paymentProofUrl(path);
      if (!context.mounted) return;
      Navigator.pop(context);
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text(
                    'To‘lov cheki',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 4,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Chekni ochishda xatolik: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF7EF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFBDE2C9)),
    ),
    child: Row(
      children: [
        const Icon(Icons.receipt_rounded, color: Color(0xFF138A4B)),
        const SizedBox(width: 9),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To‘lov cheki yuborilgan',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                'Chek maxfiy saqlanadi.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => openProof(context),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Ko‘rish'),
        ),
      ],
    ),
  );
}

class _DiscountAdmin extends StatefulWidget {
  const _DiscountAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_DiscountAdmin> createState() => _DiscountAdminState();
}

class _DiscountAdminState extends State<_DiscountAdmin> {
  final percent = TextEditingController(text: '20');
  bool loading = false;

  @override
  void dispose() {
    percent.dispose();
    super.dispose();
  }

  Future<void> apply() async {
    final p = int.tryParse(percent.text.trim());
    if (p == null || p < 1 || p > 99) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1 dan 99 gacha foiz kiriting.')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      await widget.api.applyDiscount(p);
      await context.read<AppState>().refreshBooks();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$p% chegirma qo‘llandi ✅')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> clear() async {
    setState(() => loading = true);
    try {
      await widget.api.clearDiscounts();
      await context.read<AppState>().refreshBooks();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barcha chegirmalar bekor qilindi.')),
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const AppPageHeading(
          title: 'Chegirma boshqaruvi',
          subtitle:
              'Aksiya foizini bir necha soniyada barcha kitoblarga qo‘llang.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 760;
            final editor = AppSurface(
              shadow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'Yangi aksiya',
                    subtitle: 'Foizni tanlang yoki qo‘lda kiriting',
                    icon: Icons.sell_outlined,
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [10, 15, 20, 25, 30]
                        .map(
                          (v) => ActionChip(
                            label: Text('$v%'),
                            onPressed: loading
                                ? null
                                : () => setState(() => percent.text = '$v'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: percent,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Chegirma foizi',
                      prefixIcon: Icon(Icons.percent_rounded),
                      suffixText: '%',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loading ? null : apply,
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Chegirmani qo‘llash'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : clear,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Barcha chegirmalarni bekor qilish'),
                    ),
                  ),
                ],
              ),
            );
            final guide = AppSurface(
              backgroundColor: AppColors.surfaceSoft,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionHeader(
                    title: 'Aksiya tavsiyasi',
                    subtitle: 'Narxni tushunarli va ishonchli ko‘rsating',
                    icon: Icons.tips_and_updates_outlined,
                  ),
                  SizedBox(height: 14),
                  _DiscountTip(
                    icon: Icons.visibility_outlined,
                    title: 'Eski narx ko‘rinadi',
                    text: 'Chegirma yoqilganda asl narx ustidan chiziq bilan ko‘rsatiladi.',
                  ),
                  SizedBox(height: 10),
                  _DiscountTip(
                    icon: Icons.calculate_outlined,
                    title: 'Yangi narx avtomatik',
                    text: 'Mijozga chegirmadan keyingi yakuniy narx ko‘rsatiladi.',
                  ),
                  SizedBox(height: 10),
                  _DiscountTip(
                    icon: Icons.restart_alt_rounded,
                    title: 'Bir tugmada bekor',
                    text: 'Aksiya tugaganda barcha chegirmalarni birdan o‘chira olasiz.',
                  ),
                ],
              ),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: editor),
                      const SizedBox(width: 14),
                      Expanded(child: guide),
                    ],
                  )
                : Column(children: [editor, const SizedBox(height: 14), guide]);
          },
        ),
      ],
    );
  }
}

class _DiscountTip extends StatelessWidget {
  const _DiscountTip({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 19, color: AppColors.navy),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CustomersAdmin extends StatefulWidget {
  const _CustomersAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_CustomersAdmin> createState() => _CustomersAdminState();
}

class _CustomersAdminState extends State<_CustomersAdmin> {
  late Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> future;
  String query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    future =
        Future.wait<dynamic>([widget.api.userStats(), widget.api.customers()])
            .then(
              (v) => (
                Map<String, dynamic>.from(v[0] as Map),
                (v[1] as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              ),
            );
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse((value ?? '').toString())?.toLocal();
    if (d == null) return '—';
    return DateFormat('yyyy.MM.dd HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Qayta yuklash: ${snapshot.error}'),
            ),
          );
        }
        final stats = snapshot.data?.$1 ?? <String, dynamic>{};
        final all = snapshot.data?.$2 ?? <Map<String, dynamic>>[];
        final q = query.trim().toLowerCase();
        final customers = all.where((c) {
          if (q.isEmpty) return true;
          return (c['full_name'] ?? '').toString().toLowerCase().contains(q) ||
              (c['phone'] ?? '').toString().toLowerCase().contains(q);
        }).toList();

        Widget metric(String label, dynamic value, IconData icon) => Expanded(
          child: AppSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.navy, size: 20),
                const SizedBox(height: 10),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        );

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            setState(() {});
            await future;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
            children: [
              const AppSectionHeader(
                title: 'Mijozlar markazi',
                subtitle: 'Loginlar, faol foydalanuvchilar va xarid tarixi',
                icon: Icons.people_alt_rounded,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  metric(
                    'Ro‘yxatdan o‘tgan',
                    stats['total_users'] ?? 0,
                    Icons.person_add_alt_1_rounded,
                  ),
                  const SizedBox(width: 10),
                  metric(
                    'Bugun faol',
                    stats['active_today'] ?? 0,
                    Icons.bolt_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  metric(
                    'Ilova qurilmalari',
                    stats['total_installs'] ?? 0,
                    Icons.phone_iphone_rounded,
                  ),
                  const SizedBox(width: 10),
                  metric(
                    '7 kunda faol',
                    stats['active_7d'] ?? 0,
                    Icons.calendar_view_week_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppSurface(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ochiq buyurtmalar: ${stats['open_orders'] ?? 0} • Yakunlangan: ${stats['completed_orders'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      _won((stats['completed_revenue'] as num?)?.toInt() ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  hintText: 'Ism yoki telefon bo‘yicha qidirish...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (customers.isEmpty)
                const AppSurface(
                  child: Text('Hozircha ro‘yxatdan o‘tgan mijoz yo‘q.'),
                )
              else
                ...customers.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: AppSurface(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.infoSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (c['full_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty
                                      ? 'Nomsiz mijoz'
                                      : c['full_name'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  (c['phone'] ?? '—').toString(),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    AppInfoPill(
                                      icon: Icons.shopping_bag_outlined,
                                      label:
                                          '${c['order_count'] ?? 0} buyurtma',
                                    ),
                                    AppInfoPill(
                                      icon: Icons.payments_outlined,
                                      label: _won(
                                        (c['spent'] as num?)?.toInt() ?? 0,
                                      ),
                                      foreground: AppColors.success,
                                      background: AppColors.successSoft,
                                      border: const Color(0xFFCDEAD7),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Oxirgi faollik',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _date(c['last_seen_at']),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${c['login_count'] ?? 0} login',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
