part of 'admin_ui.dart';

/// The compact admin landing page. Existing operational pages are kept intact
/// and remain reachable from these six topic-based menus.
class _AdminCommandCenter extends StatefulWidget {
  const _AdminCommandCenter({
    super.key,
    required this.api,
    required this.onOpenTab,
    required this.onPushSettings,
  });
  final _AdminApi api;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onPushSettings;

  @override
  State<_AdminCommandCenter> createState() => _AdminCommandCenterState();
}

class _AdminHomeData {
  const _AdminHomeData({
    required this.books,
    required this.orders,
    required this.todayRevenue,
    required this.newOrders,
    required this.soldOutCount,
    this.preorderCount,
  });
  final List<Book> books;
  final List<ShopOrder> orders;
  final int todayRevenue;
  final int newOrders;
  final int soldOutCount;
  final int? preorderCount;
}

class _AdminMenuAction {
  const _AdminMenuAction(this.title, this.subtitle, this.icon, this.open);
  final String title;
  final String subtitle;
  final IconData icon;
  final void Function(BuildContext) open;
}

class _AdminSectionPage extends StatelessWidget {
  const _AdminSectionPage({
    required this.title,
    required this.subtitle,
    required this.actions,
  });
  final String title;
  final String subtitle;
  final List<_AdminMenuAction> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      backgroundColor: UzbekCustomerColors.background,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            itemCount: actions.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
                  child: Text(subtitle, style: const TextStyle(
                    color: AppColors.muted, height: 1.4, fontSize: 13)),
                );
              }
              final action = actions[index - 1];
              return Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF4F1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(action.icon, color: AppColors.navy),
                  ),
                  title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(action.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                  onTap: () => action.open(context),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _AdminCommandCenterState extends State<_AdminCommandCenter> {
  late Future<_AdminHomeData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_AdminHomeData> load() async {
    // Fetch in parallel to keep the landing screen responsive on mobile.
    final booksFuture = widget.api.books();
    final ordersFuture = widget.api.orders();
    final books = await booksFuture;
    final orders = await ordersFuture;
    final now = DateTime.now();
    final todayRevenue = orders.where((order) =>
      order.createdAt.year == now.year &&
      order.createdAt.month == now.month &&
      order.createdAt.day == now.day &&
      (order.status == 'shipping' ||
        (order.isApp && const {'accepted','paid'}.contains(order.status))))
      .fold<int>(0, (total, order) => total + order.total);
    final newOrders = orders.where((order) => order.status == 'new').length;
    final soldOutCount = books.where((book) =>
      book.isActive && book.stock == 0).length;

    // The metric is shown only when every relevant source answers. A failed
    // endpoint must not silently be counted as zero customer orders.
    int? preorderCount;
    try {
      final insight = await widget.api.merchandisingInsights()
          .timeout(const Duration(seconds: 4));
      final nativeRows = insight['preorders'] as List?;
      if (nativeRows != null) {
        if (webPreordersAvailable) {
          final webRows = await WebPreorderApi().admin(widget.api.secret, 'list')
              .timeout(const Duration(seconds: 4));
          if (webRows is List) preorderCount = nativeRows.length + webRows.length;
        } else {
          preorderCount = nativeRows.length;
        }
      }
    } catch (_) {
      preorderCount = null;
    }
    return _AdminHomeData(
      books: books, orders: orders, todayRevenue: todayRevenue,
      newOrders: newOrders, soldOutCount: soldOutCount,
      preorderCount: preorderCount,
    );
  }

  void reload() {
    if (mounted) setState(() => future = load());
  }

  Future<void> reloadQuietly() async {
    try {
      final updated = await load();
      if (mounted) setState(() => future = Future.value(updated));
    } catch (_) {
      // Keep last successfully loaded data on a temporary network failure.
    }
  }

  void _goToTab(BuildContext sectionContext, int tab) {
    Navigator.of(sectionContext).pop();
    widget.onOpenTab(tab);
  }

  void _pushPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showSection(int index, _AdminHomeData data) {
    final List<_AdminMenuAction> actions;
    final String title;
    final String subtitle;
    switch (index) {
      case 0:
        title = 'Pochta va jo‘natmalar';
        subtitle = 'Buyurtmalar pastki menyuda; bu yerda pochta ro‘yxati va kuzatuv ma’lumotlarini boshqaring.';
        actions = [
          _AdminMenuAction('Pochta zakaslari', 'Ism, telefon, manzil va tracking',
            Icons.local_shipping_outlined, (ctx) => _pushPage(ctx,
              Scaffold(appBar: AppBar(title: const Text('Pochta zakaslari')),
                body: _ShippingQueueAdmin(api: widget.api)))),
        ];
      case 1:
        title = 'Ombor va katalog sozlamalari';
        subtitle = 'Kitoblar pastki menyuda; bu yerda qoldiq, partiyalar va tartibni boshqaring.';
        actions = [
          _AdminMenuAction('Ombor va qoldiqlar', 'Kirgan va sotilgan kitoblar',
            Icons.inventory_2_outlined, (ctx) => _goToTab(ctx, 2)),
          _AdminMenuAction('Tugagan kitoblar', 'Omborda 0 dona qolgan kitoblar',
            Icons.inventory_2_outlined, (ctx) => _pushPage(ctx, _AdminBookListPage(
              title: 'Tugagan kitoblar',
              books: data.books.where((b) => b.isActive && b.stock == 0).toList()))),
          _AdminMenuAction('Katalog tartibi', 'Eng tepada chiqadigan kitoblarni belgilang',
            Icons.vertical_align_top_rounded, (ctx) => _pushPage(ctx,
              _CatalogPinsAdminPage(api: widget.api))),
          if (_enhancedAdminUi)
            _AdminMenuAction('Biznes asboblari', 'Tan narx, partiyalar va taqqoslash',
              Icons.calculate_outlined, (ctx) => _pushPage(ctx,
                WebAdminToolsPage(secret: widget.api.secret, books: data.books))),
        ];
      case 2:
        title = 'Oldindan buyurtmalar';
        subtitle = 'Tugagan kitoblar uchun qabulni boshqarish va maxsus oldindan sotuvlar.';
        actions = [
          _AdminMenuAction('Oldindan sotuvdagi kitoblar', 'Kitoblar, kelish muddati va avanslar',
            Icons.event_available_outlined, (ctx) => _pushPage(ctx,
              _PreorderAdminPage(api: widget.api))),
          if (webPreordersAvailable)
            _AdminMenuAction('Buyurtmalar va sozlamalar', 'Qabulni ochish/yopish, mijoz so‘rovlari',
              Icons.fact_check_outlined, (ctx) => _pushPage(ctx,
                WebPreorderAdminPage(secret: widget.api.secret))),
        ];
      case 3:
        title = 'Batafsil hisobotlar';
        subtitle = 'Asosiy moliya pastki menyuda; qo‘shimcha ko‘rsatkichlar shu yerda.';
        actions = [
          _AdminMenuAction('Batafsil statistika', 'Avvalgi barcha hisob va ko‘rsatkichlar saqlangan',
            Icons.insights_outlined, (ctx) => _pushPage(ctx, Scaffold(
              appBar: AppBar(title: const Text('Batafsil statistika')),
              body: _OverviewAdmin(api: widget.api,
                onOpenTab: (tab) {
                  // Close details and the topic menu before changing the
                  // underlying dashboard tab; otherwise the menu masks it.
                  Navigator.of(ctx).pop();
                  Navigator.of(ctx).pop();
                  widget.onOpenTab(tab);
                }),
            ))),
        ];
      case 4:
        title = 'Marketing va mijozlar';
        subtitle = 'Mijozlar, chegirmalar, bildirishnomalar va savdo imkoniyatlari.';
        actions = [
          _AdminMenuAction('Mijozlar', 'Ro‘yxatlar, aloqalar va statistika',
            Icons.people_alt_outlined, (ctx) => _goToTab(ctx, 5)),
          _AdminMenuAction('Savdo imkoniyatlari', 'Chegirmalar, kutayotganlar va xabarlar',
            Icons.campaign_outlined, (ctx) => _pushPage(ctx,
              _MerchandisingAdminPage(api: widget.api))),
          _AdminMenuAction('Muhim e’lon', 'Mijozlarga ko‘rinadigan do‘kon e’loni',
            Icons.notifications_active_outlined, (ctx) => _pushPage(ctx,
              _EmergencyNoticeAdmin(api: widget.api))),
          _AdminMenuAction('Admin AI', 'Kitob va biznes bo‘yicha AI vositalar',
            Icons.auto_awesome_outlined, (ctx) => _goToTab(ctx, 7)),
        ];
      default:
        title = 'Sozlamalar';
        subtitle = 'Admin bildirishnomalari, katalog ko‘rinishi va qo‘shimcha vositalar.';
        actions = [
          _AdminMenuAction('Admin bildirishnomalari', 'Yangi buyurtmalar uchun push xabarlar',
            Icons.notifications_outlined, (_) => widget.onPushSettings()),
        ];
    }
    _pushPage(context, _AdminSectionPage(
      title: title, subtitle: subtitle, actions: actions));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_AdminHomeData>(
    future: future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.danger),
              const SizedBox(height: 12),
              const Text('Boshqaruv ma’lumotlari yuklanmadi.'),
              const SizedBox(height: 10),
              FilledButton.icon(onPressed: reload, icon: const Icon(Icons.refresh),
                label: const Text('Qayta urinish')),
            ]),
          ));
        }
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      const sections = [
        ('Pochta va jo‘natmalar','Pochta ro‘yxati • tracking', Icons.local_shipping_outlined),
        ('Ombor va katalog sozlamalari','Qoldiq • partiyalar • tartib', Icons.inventory_2_outlined),
        ('Oldindan buyurtmalar','Tugagan kitoblar • avans • qabul', Icons.event_available_outlined),
        ('Batafsil hisobotlar','Qo‘shimcha statistika va hisobotlar', Icons.bar_chart_rounded),
        ('Marketing va mijozlar','Bildirishnomalar • chegirmalar • mijozlar', Icons.campaign_outlined),
        ('Sozlamalar','Xabarnomalar • ilova boshqaruvi • xavfsizlik', Icons.settings_outlined),
      ];
      return RefreshIndicator(
        onRefresh: reloadQuietly,
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D4549), Color(0xFF116B64)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(children: [
                  const MuhajeerLogoBadge(size: 46, radius: 12, showShadow: false),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MUHAJEER BOOKS', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                    SizedBox(height: 3),
                    Text('Boshqaruv paneli', style: TextStyle(color: Color(0xFFE7F3F1))),
                  ])),
                  IconButton(
                    onPressed: reload,
                    tooltip: 'Yangilash',
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              const Text('Bugungi holat', style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.navy)),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (ctx, size) {
                final columns = size.maxWidth >= 720 ? 4 : 2;
                final gap = 10.0;
                final width = (size.maxWidth - gap * (columns - 1)) / columns;
                final metrics = [
                  ('Bugungi savdo', _won(data.todayRevenue), Icons.payments_outlined),
                  ('Yangi buyurtmalar', '${data.newOrders} ta', Icons.shopping_cart_outlined),
                  ('Tugagan kitoblar', '${data.soldOutCount} ta', Icons.inventory_2_outlined),
                  ('Oldindan zakazlar', data.preorderCount == null
                    ? '—' : '${data.preorderCount} ta', Icons.event_available_outlined),
                ];
                return Wrap(spacing: gap, runSpacing: gap, children: [
                  for (var i = 0; i < metrics.length; i++)
                    SizedBox(width: width, child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                          constraints: const BoxConstraints(minHeight: 108),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(metrics[i].$3, size: 21, color: AppColors.success),
                            const SizedBox(height: 6),
                            Text(metrics[i].$1, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.muted,
                                fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(metrics[i].$2, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18,
                                fontWeight: FontWeight.w900, color: AppColors.navy)),
                          ]),
                        ),
                    )),
                ]);
              }),
              const SizedBox(height: 22),
              const Text('Boshqaruv bo‘limlari', style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.navy)),
              const SizedBox(height: 11),
              for (var i = 0; i < sections.length; i++) ...[
                Card(
                  margin: EdgeInsets.zero, elevation: 0, color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    leading: Container(
                      width: 45, height: 45,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4F1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(sections[i].$3, color: AppColors.navy),
                    ),
                    title: Text(sections[i].$1,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    subtitle: Text(sections[i].$2,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    onTap: () => _showSection(i, data),
                  ),
                ),
                const SizedBox(height: 9),
              ],
            ],
          ),
        )),
      );
    },
  );
}
