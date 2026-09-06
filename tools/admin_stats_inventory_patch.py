from pathlib import Path
import re

store_path = Path('lib/store_ui.dart')
admin_path = Path('lib/admin_ui.dart')
pubspec_path = Path('pubspec.yaml')

store = store_path.read_text()
old_tagline = "'Koreyadagi o‘zbek kitob do‘koni'"
new_tagline = "'Koreyadagi O’zbek kitobxonlari uchun'"
if old_tagline not in store:
    raise SystemExit('Store tagline marker not found')
store = store.replace(old_tagline, new_tagline, 1)
store_path.write_text(store)

admin = admin_path.read_text()

calc_marker = """      final recent = orders.take(5).toList();
"""
calc_insert = """      final recent = orders.take(5).toList();
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
      final todayRevenue = orders.where((o) {
        return o.createdAt.year == now.year &&
            o.createdAt.month == now.month &&
            o.createdAt.day == now.day &&
            activeStatuses.contains(o.status);
      }).fold<int>(0, (sum, o) => sum + o.total);
      final averageOrder = activeOrders.isEmpty
          ? 0
          : activeRevenue ~/ activeOrders.length;
      final acceptedOrders = orders.where((o) => o.status == 'accepted').length;
      final shippingOrders = orders.where((o) => o.status == 'shipping').length;
      final doneOrders = orders.where((o) => o.status == 'done').length;
      final cancelledOrders = orders.where((o) => o.status == 'cancelled').length;
      final outOfStock = books.where((b) => b.stock == 0).length;
      final completionRate = orders.isEmpty
          ? 0
          : ((doneOrders / orders.length) * 100).round();
      final cancelRate = orders.isEmpty
          ? 0
          : ((cancelledOrders / orders.length) * 100).round();
"""
if calc_marker not in admin:
    raise SystemExit('Overview calculation marker not found')
admin = admin.replace(calc_marker, calc_insert, 1)

cards_marker = """                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.warning_amber_rounded,
                        label: 'Kam qolgan kitob',
                        value: '${lowStock.length}',
                        accent: AppColors.warning,
                        note: '2 dona yoki undan kam',
                      ),
                    ),
"""
cards_insert = cards_marker + """                    SizedBox(
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
"""
if cards_marker not in admin:
    raise SystemExit('Metric cards marker not found')
admin = admin.replace(cards_marker, cards_insert, 1)

section_marker = """            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
"""
statistics_section = """            const SizedBox(height: 20),
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
"""
if section_marker not in admin:
    raise SystemExit('Statistics insertion marker not found')
admin = admin.replace(section_marker, statistics_section, 1)

progress_widget_marker = """class _AdminStatCard extends StatelessWidget {
"""
progress_widget = """class _AdminProgressStat extends StatelessWidget {
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
"""
if progress_widget_marker not in admin:
    raise SystemExit('Progress widget marker not found')
admin = admin.replace(progress_widget_marker, progress_widget, 1)

inventory_pattern = re.compile(
    r"class _InventoryAdminState extends State<_InventoryAdmin> \{.*?\n\}\n\nclass _BooksAdmin extends StatefulWidget \{",
    re.S,
)
new_inventory = r'''class _InventoryAdminState extends State<_InventoryAdmin> {
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

  Future<void> _load() async {
    if (mounted) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ombor xatosi: $e')),
      );
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
                subtitle:
                    'Qoldiqni tez o‘zgartiring. +/− bosilganda kitob joyi o‘zgarmaydi.',
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
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_won(b.currentPrice)} • ${b.stock == 0 ? 'Tugagan' : b.stock <= 2 ? 'Kam qolgan' : 'Qoldiq yaxshi'}',
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
                                PopupMenuItem(value: 10, child: Text('+10 dona')),
                                PopupMenuItem(value: 20, child: Text('+20 dona')),
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

class _BooksAdmin extends StatefulWidget {'''
admin, count = inventory_pattern.subn(new_inventory, admin, count=1)
if count != 1:
    raise SystemExit(f'Inventory class replacement failed: {count}')

admin_path.write_text(admin)

pubspec = pubspec_path.read_text()
if 'version: 2.2.0+4' not in pubspec:
    raise SystemExit('Version marker not found')
pubspec = pubspec.replace('version: 2.2.0+4', 'version: 2.3.0+5', 1)
pubspec_path.write_text(pubspec)

print('Admin stats, stable inventory controls, and storefront tagline patched.')
