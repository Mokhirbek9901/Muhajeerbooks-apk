import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_ui.dart';
import 'app_state.dart';
import 'brand.dart';
import 'design_system.dart';
import 'uzbek_customer_style.dart';

const _navy = UzbekCustomerColors.navy;
const _orange = UzbekCustomerColors.goldDeep;
const _gold = UzbekCustomerColors.gold;
const _cream = UzbekCustomerColors.ivory;
const _green = UzbekCustomerColors.success;

final _money = NumberFormat('#,###', 'en_US');
String won(int value) => '₩${_money.format(value)}';

bool _isSupportedCustomerPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);

  // O‘zbekiston: +998 XX XXX XX XX, 998XXXXXXXXX yoki mahalliy 9 raqam.
  if (digits.length == 12 && digits.startsWith('998')) return true;
  if (digits.length == 9 && !digits.startsWith('0')) return true;

  // Koreya: 010-XXXX-XXXX yoki +82 10-XXXX-XXXX.
  if (digits.length == 11 && digits.startsWith('010')) return true;
  if (digits.length == 12 && digits.startsWith('8210')) return true;
  return false;
}

class StoreShell extends StatefulWidget {
  const StoreShell({super.key});

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
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
        if (notice == null || notice['id']?.toString() != latestNoticeId)
          return;
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
    const pages = [
      const HomePage(),
      const CategoriesPage(),
      const CartPage(),
      const FavoritesPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: UzbekCustomerColors.border)),
          boxShadow: [
            BoxShadow(
              color: Color(0x140B2942),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          height: 70,
          backgroundColor: Colors.white,
          indicatorColor: UzbekCustomerColors.goldSoft,
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: UzbekCustomerColors.goldDeep,
              ),
              label: 'Bosh sahifa',
            ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(
                Icons.grid_view_rounded,
                color: UzbekCustomerColors.goldDeep,
              ),
              label: 'Kategoriya',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('${cartCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('${cartCount}'),
                child: const Icon(
                  Icons.shopping_cart_rounded,
                  color: UzbekCustomerColors.goldDeep,
                ),
              ),
              label: 'Savatcha',
            ),
            const NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(
                Icons.favorite_rounded,
                color: UzbekCustomerColors.goldDeep,
              ),
              label: 'Sevimlilar',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: UzbekCustomerColors.goldDeep,
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = state.books
        .where((b) => b.isActive)
        .map(
          (b) => b.category.trim().isEmpty ? 'Boshqalar' : b.category.trim(),
        )
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Kategoriyalar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          const UzbekPatternPanel(
            dark: true,
            strongPattern: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UzbekMiniPill(
                  icon: Icons.auto_stories_rounded,
                  text: 'Muhajeer Books',
                  dark: true,
                ),
                SizedBox(height: 14),
                Text(
                  'O‘zingizga mos kitobni\nkategoriyadan toping',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Badiiy, tarixiy, psixologiya, biznes va boshqa yo‘nalishlar.',
                  style: TextStyle(
                    color: Color(0xFFE6F2EF),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const UzbekSectionTitle(
            title: 'Yo‘nalishlar',
            subtitle: 'Kitoblarni mavzu bo‘yicha ko‘ring',
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, i) {
              final c = categories[i];
              final count = state.books
                  .where((b) => b.isActive && b.category == c)
                  .length;
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryBrowsePage(category: c),
                  ),
                ),
                child: UzbekPatternPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 22,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: UzbekCustomerColors.goldSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: UzbekCustomerColors.border),
                        ),
                        child: Icon(
                          _categoryIcon(c),
                          color: UzbekCustomerColors.teal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: UzbekCustomerColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$count ta kitob',
                              style: const TextStyle(
                                color: UzbekCustomerColors.textMuted,
                                fontSize: 11.5,
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
        ],
      ),
    );
  }
}

class CategoryBrowsePage extends StatelessWidget {
  const CategoryBrowsePage({super.key, required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final books = context
        .watch<AppState>()
        .books
        .where((b) => b.isActive && b.category == category)
        .toList();
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(category),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: books.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .57,
        ),
        itemBuilder: (_, i) => BookCard(book: books[i]),
      ),
    );
  }
}

IconData _categoryIcon(String value) {
  final v = value.toLowerCase();
  if (v.contains('badi')) return Icons.menu_book_rounded;
  if (v.contains('tarix')) return Icons.account_balance_rounded;
  if (v.contains('psix')) return Icons.psychology_alt_rounded;
  if (v.contains('biznes') || v.contains('moliya'))
    return Icons.trending_up_rounded;
  if (v.contains('dini')) return Icons.auto_awesome_rounded;
  if (v.contains('bol')) return Icons.child_care_rounded;
  return Icons.auto_stories_rounded;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String query = '';
  String category = 'Barchasi';
  String sort = 'new';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = <String>{
      'Barchasi',
      ...state.books.where((b) => b.isActive).map((b) => b.category),
    }.toList();
    final featured = state.books
        .where((b) => b.isActive && b.recommended && b.inStock)
        .take(6)
        .toList();
    if (!categories.contains(category)) category = 'Barchasi';

    final books = state.books.where((book) {
      final q = query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          book.title.toLowerCase().contains(q) ||
          book.author.toLowerCase().contains(q) ||
          book.category.toLowerCase().contains(q);
      final matchesCategory =
          category == 'Barchasi' || book.category == category;
      return book.isActive && matchesQuery && matchesCategory;
    }).toList();

    switch (sort) {
      case 'price_low':
        books.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
      case 'price_high':
        books.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
      case 'stock':
        books.sort((a, b) => b.stock.compareTo(a.stock));
      case 'name':
        books.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      default:
        books.sort((a, b) {
          final aa = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bb.compareTo(aa);
        });
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.refreshBooks,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              sliver: SliverToBoxAdapter(child: _StoreHeader(state: state)),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
              sliver: SliverToBoxAdapter(child: _DeliveryPromoCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 5),
              sliver: SliverToBoxAdapter(
                child: _QuickCategoryStrip(
                  categories: categories,
                  selected: category,
                  onSelected: (value) => setState(() => category = value),
                ),
              ),
            ),
            if (featured.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: _FeaturedBooksStrip(books: featured),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => query = value),
                        decoration: const InputDecoration(
                          hintText: 'Kitob yoki muallif qidiring...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Saralash',
                      onSelected: (value) => setState(() => sort = value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'new',
                          child: Text('Yangi qo‘shilgan'),
                        ),
                        PopupMenuItem(
                          value: 'name',
                          child: Text('Nom bo‘yicha'),
                        ),
                        PopupMenuItem(
                          value: 'price_low',
                          child: Text('Arzonidan'),
                        ),
                        PopupMenuItem(
                          value: 'price_high',
                          child: Text('Qimmatidan'),
                        ),
                        PopupMenuItem(
                          value: 'stock',
                          child: Text('Ko‘p qoldiq'),
                        ),
                      ],
                      child: Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE6E8EC)),
                        ),
                        child: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 2)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      query.trim().isEmpty && category == 'Barchasi'
                          ? 'Kitoblar'
                          : 'Natijalar',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${books.length} ta',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            if (state.error != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _InfoBanner(
                    icon: Icons.warning_amber_rounded,
                    text:
                        'Ma’lumotni yangilashda xatolik bo‘ldi. Oxirgi saqlangan ma’lumot ko‘rsatilmoqda.',
                  ),
                ),
              ),
            if (state.loading && state.books.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (books.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Kitob topilmadi',
                  subtitle: 'Qidiruv yoki kategoriyani o‘zgartirib ko‘ring.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final count = width >= 1150
                        ? 5
                        : width >= 850
                            ? 4
                            : width >= 600
                                ? 3
                                : 2;
                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => BookCard(book: books[i]),
                        childCount: books.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: width < 450 ? .57 : .62,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState extends State<CustomerNotificationsPage> {
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

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: UzbekCustomerColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: UzbekCustomerColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const MuhajeerLogoBadge(size: 54, radius: 16),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Muhajeer Books',
                      style: TextStyle(
                        color: UzbekCustomerColors.navy,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Koreyadagi O’zbek kitobxonlari uchun',
                      style: TextStyle(
                        color: UzbekCustomerColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Badge(
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
              ),
            ],
          ),
          const SizedBox(height: 8),
          const UzbekAtlasBand(height: 4),
        ],
      ),
    );
  }
}

class _DeliveryPromoCard extends StatelessWidget {
  const _DeliveryPromoCard();

  @override
  Widget build(BuildContext context) {
    return UzbekPatternPanel(
      dark: true,
      strongPattern: true,
      padding: EdgeInsets.zero,
      radius: 26,
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -22,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 150,
              color: UzbekCustomerColors.gold.withValues(alpha: .22),
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: UzbekMedallion(size: 70, dark: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 118, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UzbekMiniPill(
                  icon: Icons.auto_awesome_rounded,
                  text: 'O‘zbekona ruh',
                  dark: true,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Kitob bilan\nyanada yaqinroq bo‘ling',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bilim har doim siz bilan!',
                  style: TextStyle(
                    color: Color(0xFFF8E6BF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroFact(
                      icon: Icons.local_shipping_rounded,
                      text: '1–3 ish kuni',
                    ),
                    _HeroFact(icon: Icons.payments_outlined, text: '택배 ₩4,000'),
                    _HeroFact(
                      icon: Icons.card_giftcard_rounded,
                      text: '4+ kitob — bepul',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x16FFFFFF),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.gold),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class ContainerIcon extends StatelessWidget {
  const ContainerIcon({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _gold),
      );
}

class _QuickCategoryStrip extends StatelessWidget {
  const _QuickCategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = categories.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UzbekSectionTitle(
          title: 'Kategoriyalar',
          subtitle: 'O‘zingizga mos yo‘nalishni tanlang',
          icon: Icons.grid_view_rounded,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = visible[i];
              final active = c == selected;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onSelected(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 78,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: active ? UzbekCustomerColors.goldSoft : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: active
                          ? UzbekCustomerColors.goldDeep
                          : UzbekCustomerColors.border,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0B0E2B45),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        c == 'Barchasi'
                            ? Icons.grid_view_rounded
                            : _categoryIcon(c),
                        color: active
                            ? UzbekCustomerColors.goldDeep
                            : UzbekCustomerColors.teal,
                        size: 25,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: UzbekCustomerColors.navy,
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w900 : FontWeight.w700,
                        ),
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

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: UzbekCustomerColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: UzbekCustomerColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x09000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          children: [
            Expanded(
              child: _TrustItem(
                icon: Icons.verified_outlined,
                text: 'Ishonchli buyurtma',
              ),
            ),
            _TrustDivider(),
            Expanded(
              child: _TrustItem(
                  icon: Icons.schedule_rounded, text: '1–3 ish kuni'),
            ),
            _TrustDivider(),
            Expanded(
              child: _TrustItem(
                icon: Icons.favorite_border_rounded,
                text: 'Kitobxonga e’tibor',
              ),
            ),
          ],
        ),
      );
}

class _TrustDivider extends StatelessWidget {
  const _TrustDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: UzbekCustomerColors.border);
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: UzbekCustomerColors.teal),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              style:
                  const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _FeaturedBooksStrip extends StatelessWidget {
  const _FeaturedBooksStrip({required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UzbekSectionTitle(
            title: 'Tavsiya etamiz',
            subtitle: 'Muhajeer Books tanlovi',
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 248,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final b = books[i];
                return Container(
                  width: 148,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: UzbekCustomerColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x100E2B45),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookDetailPage(bookId: b.id),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 126,
                          width: double.infinity,
                          child: _BookCover(book: b),
                        ),
                        const UzbekAtlasBand(height: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: UzbekCustomerColors.navy,
                                    fontSize: 12.5,
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  b.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: UzbekCustomerColors.textMuted,
                                    fontSize: 10.5,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        won(b.currentPrice),
                                        style: const TextStyle(
                                          color: UzbekCustomerColors.navy,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(32, 32),
                                          backgroundColor:
                                              UzbekCustomerColors.navy,
                                        ),
                                        onPressed: b.inStock
                                            ? () => context
                                                .read<AppState>()
                                                .addToCart(b)
                                            : null,
                                        child: const Icon(
                                          Icons.add_shopping_cart_rounded,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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

class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final favorite = context.select<AppState, bool>((s) => s.isFavorite(book));
    final state = context.read<AppState>();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: UzbekCustomerColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F4C5C),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailPage(bookId: book.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BookCover(book: book),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: UzbekAccentLine(),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(100),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: () => state.toggleFavorite(book),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: favorite ? AppColors.danger : AppColors.navy,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (book.isDiscounted)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(
                        text: '-${book.discountPercent}%',
                        color: AppColors.danger,
                      ),
                    ),
                  if (book.recommended)
                    const Positioned(
                      bottom: 8,
                      left: 8,
                      child: _Badge(text: 'Tavsiya', color: AppColors.orange),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        book.inStock
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 14,
                        color:
                            book.inStock ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          book.inStock
                              ? '${book.stock} dona mavjud'
                              : 'Hozircha mavjud emas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: book.inStock
                                ? AppColors.success
                                : AppColors.danger,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (book.isDiscounted)
                    Text(
                      won(book.price),
                      style: const TextStyle(
                        color: AppColors.muted,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 10.5,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          won(book.currentPrice),
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: FilledButton(
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    if (book.imageUrl.isNotEmpty) {
      return Image.network(
        book.imageUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_cream, Color(0xFFFFE9B0)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: .08,
                child: Image.asset(
                  'assets/images/muhajeer_logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Icon(Icons.auto_stories_rounded, size: 56, color: _navy),
          ],
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    Book? book;
    for (final item in state.books) {
      if (item.id == bookId) {
        book = item;
        break;
      }
    }
    if (book == null) {
      return const Scaffold(
        backgroundColor: UzbekCustomerColors.background,
        body: SafeArea(child: Center(child: Text('Kitob topilmadi'))),
      );
    }
    final b = book;
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Kitob haqida'),
        actions: [
          IconButton.filledTonal(
            onPressed: () => state.toggleFavorite(b),
            tooltip: 'Sevimlilar',
            icon: Icon(
              state.isFavorite(b)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 760;
          final cover = Container(
            width: desktop ? 300 : 235,
            height: desktop ? 420 : 330,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F172A),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _BookCover(book: b),
          );
          final info = _BookDetailInfo(book: b);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              desktop ? 32 : 18,
              10,
              desktop ? 32 : 18,
              125,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          cover,
                          const SizedBox(width: 34),
                          Expanded(child: info),
                        ],
                      )
                    : Column(
                        children: [cover, const SizedBox(height: 26), info],
                      ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Narxi',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    if (b.isDiscounted)
                      Text(
                        won(b.price),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      won(b.currentPrice),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _BookDetailInfo extends StatelessWidget {
  const _BookDetailInfo({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (book.recommended)
            const AppInfoPill(
              icon: Icons.auto_awesome_rounded,
              label: 'Muhajeer tavsiyasi',
              foreground: AppColors.orange,
              background: Color(0xFFFFF2E3),
              border: Color(0xFFFFD4A3),
            ),
          if (book.recommended) const SizedBox(height: 10),
          Text(book.title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 7),
          Text(
            book.author,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppInfoPill(icon: Icons.category_outlined, label: book.category),
              AppInfoPill(
                icon: Icons.inventory_2_outlined,
                label:
                    book.inStock ? '${book.stock} dona mavjud' : 'Mavjud emas',
                foreground: book.inStock ? AppColors.success : AppColors.danger,
                background:
                    book.inStock ? AppColors.successSoft : AppColors.dangerSoft,
                border: book.inStock
                    ? const Color(0xFFCDEAD7)
                    : const Color(0xFFFFCCD1),
              ),
              if (book.coverType != 'Ko‘rsatilmagan')
                AppInfoPill(icon: Icons.book_outlined, label: book.coverType),
            ],
          ),
          const SizedBox(height: 22),
          AppSurface(
            backgroundColor: AppColors.surfaceSoft,
            child: const Row(
              children: [
                _DetailFact(
                  icon: Icons.local_shipping_outlined,
                  title: 'Yetkazish',
                  value: '1–3 ish kuni',
                ),
                SizedBox(width: 8),
                _DetailFact(
                  icon: Icons.payments_outlined,
                  title: '택배',
                  value: '₩4,000',
                ),
                SizedBox(width: 8),
                _DetailFact(
                  icon: Icons.card_giftcard_outlined,
                  title: '4+ kitob',
                  value: 'Bepul',
                ),
              ],
            ),
          ),
          if (book.description.isNotEmpty &&
              book.description != 'Ma’lumot kiritilmagan.') ...[
            const SizedBox(height: 22),
            const AppSectionHeader(
              title: 'Kitob haqida',
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: 10),
            Text(
              book.description,
              style: const TextStyle(
                height: 1.65,
                fontSize: 15,
                color: AppColors.text,
              ),
            ),
          ],
        ],
      );
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.navy),
            const SizedBox(height: 5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final books =
        state.books.where((b) => b.isActive && state.isFavorite(b)).toList();
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Sevimlilar'),
      ),
      body: books.isEmpty
          ? const _EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Sevimlilar hali bo‘sh',
              subtitle:
                  'Yoqtirgan kitobingizdagi yurakchani bosing — keyin shu yerda tez topasiz.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: AppSectionHeader(
                    title: 'Saqlangan kitoblar',
                    subtitle: 'Tanlaganlaringiz bir joyda',
                    trailing: AppInfoPill(
                      icon: Icons.favorite_rounded,
                      label: '${books.length} ta',
                      foreground: AppColors.danger,
                      background: AppColors.dangerSoft,
                      border: const Color(0xFFFFCCD1),
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final count = constraints.maxWidth >= 1100
                          ? 5
                          : constraints.maxWidth >= 850
                              ? 4
                              : constraints.maxWidth >= 600
                                  ? 3
                                  : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: books.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: count,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio:
                              constraints.maxWidth < 450 ? .57 : .62,
                        ),
                        itemBuilder: (_, i) => BookCard(book: books[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lines = state.cartLines;
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Savatcha'),
        actions: [
          if (lines.isNotEmpty)
            TextButton.icon(
              onPressed: state.clearCart,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Tozalash'),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: lines.isEmpty
          ? const _EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Savatcha bo‘sh',
              subtitle:
                  'Kerakli kitoblarni savatchaga qo‘shing. 4 ta va undan ko‘p kitobda yetkazib berish bepul.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 190),
              children: [
                AppSectionHeader(
                  title: 'Sizning tanlovingiz',
                  subtitle: '${state.cartCount} dona kitob',
                  trailing: AppInfoPill(
                    icon: state.cartCount >= 4
                        ? Icons.card_giftcard_rounded
                        : Icons.local_shipping_outlined,
                    label: state.cartCount >= 4
                        ? 'Yetkazish bepul'
                        : '4+ kitobda bepul',
                    foreground: state.cartCount >= 4
                        ? AppColors.success
                        : AppColors.navy,
                    background: state.cartCount >= 4
                        ? AppColors.successSoft
                        : AppColors.surfaceSoft,
                    border: state.cartCount >= 4
                        ? const Color(0xFFCDEAD7)
                        : AppColors.border,
                  ),
                ),
                const SizedBox(height: 12),
                ...lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppSurface(
                      padding: const EdgeInsets.all(11),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            height: 100,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _BookCover(book: line.book),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  won(line.book.currentPrice),
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _QtyButton(
                                      icon: Icons.remove,
                                      onTap: () =>
                                          state.decrementCart(line.book),
                                    ),
                                    SizedBox(
                                      width: 42,
                                      child: Text(
                                        '${line.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    _QtyButton(
                                      icon: Icons.add,
                                      onTap: line.quantity < line.book.stock
                                          ? () => state.addToCart(line.book)
                                          : null,
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
                              Text(
                                won(line.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 30),
                              IconButton(
                                onPressed: () =>
                                    state.removeFromCart(line.book),
                                tooltip: 'Olib tashlash',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.danger,
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
      bottomNavigationBar: lines.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Kitoblar jami',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          won(state.cartSubtotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 21,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          state.cartCount >= 4
                              ? Icons.check_circle_rounded
                              : Icons.local_shipping_outlined,
                          size: 16,
                          color: state.cartCount >= 4
                              ? AppColors.success
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            state.cartCount >= 4
                                ? 'Yetkazib berish siz uchun bepul'
                                : '택배 ₩4,000 • 4+ kitobda bepul',
                            style: TextStyle(
                              color: state.cartCount >= 4
                                  ? AppColors.success
                                  : AppColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CheckoutPage(),
                          ),
                        ),
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: const Text('Buyurtmani rasmiylashtirish'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 34,
        child: IconButton.outlined(
          onPressed: onTap,
          padding: EdgeInsets.zero,
          iconSize: 18,
          icon: Icon(icon),
        ),
      );
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController address;
  String delivery = '택배';
  bool saving = false;
  bool paymentDone = false;
  XFile? paymentProof;

  @override
  void initState() {
    super.initState();
    final saved = context.read<AppState>().savedCustomer;
    name = TextEditingController(text: saved['name'] ?? '');
    phone = TextEditingController(text: saved['phone'] ?? '');
    address = TextEditingController(text: saved['address'] ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> _pickPaymentProof() async {
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (file == null || !mounted) return;
    setState(() => paymentProof = file);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final deliveryFee = state.cartCount >= 4 ? 0 : AppState.deliveryFee;
    final total = state.cartSubtotal + deliveryFee;

    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Buyurtmani rasmiylashtirish'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const _CheckoutStepHeader(number: '1', title: 'Qabul qiluvchi'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextFormField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Ism va familiya',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => v == null || v.trim().length < 2
                          ? 'Ismingizni kiriting'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Telefon raqam',
                        hintText: '+998 90 123 45 67 yoki 010-1234-5678',
                        helperText:
                            'O‘zbekiston +998 va Koreya 010 / +82 raqamlari qabul qilinadi.',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => !_isSupportedCustomerPhone(v ?? '')
                          ? 'O‘zbekiston (+998) yoki Koreya (010 / +82) raqamini to‘liq kiriting'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: address,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Manzil',
                        alignLabelWithHint: true,
                        helperMaxLines: 3,
                        helperText:
                            'Manzil va xona raqamini to‘liq yozing.\nMasalan: 경상북도 경산시 계양로 37길 7-3, 808호',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => v == null || v.trim().length < 8
                          ? 'To‘liq manzilni kiriting'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _CheckoutStepHeader(number: '2', title: 'Yetkazib berish'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: '택배',
                    groupValue: delivery,
                    onChanged: (v) => setState(() => delivery = v!),
                    title: const Text(
                      'Koreya bo‘ylab 택배',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      state.cartCount >= 4
                          ? '4+ kitob — BEPUL • 1–3 ish kuni'
                          : '₩4,000 • 1–3 ish kuni',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _CheckoutStepHeader(number: '3', title: 'To‘lov va chek'),
            const SizedBox(height: 8),
            _PaymentCard(onCopy: _copyAccount),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: paymentDone,
                      onChanged: (v) => setState(() {
                        paymentDone = v;
                        if (!v) paymentProof = null;
                      }),
                      title: const Text(
                        'To‘lovni amalga oshirdim',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: const Text(
                        'To‘lov qilgan bo‘lsangiz, chek skrinshotini yuboring.',
                      ),
                    ),
                    if (paymentDone) ...[
                      const Divider(height: 20),
                      if (paymentProof == null)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickPaymentProof,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: const Text('Chek skrinshotini tanlash'),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7EF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBDE2C9)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: _green,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  paymentProof!.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _pickPaymentProof,
                                tooltip: 'Almashtirish',
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => paymentProof = null),
                                tooltip: 'Olib tashlash',
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chek maxfiy saqlanadi va faqat admin ko‘ra oladi.',
                        style: TextStyle(fontSize: 11.5, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _CheckoutStepHeader(number: '4', title: 'Buyurtma jami'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _priceRow('Kitoblar', state.cartSubtotal),
                    const SizedBox(height: 8),
                    _priceRow('Yetkazib berish', deliveryFee),
                    const Divider(height: 24),
                    _priceRow('Jami', total, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: _orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buyurtma yuborilganda ombor darhol kamaymaydi. Admin buyurtmani QABUL QILGANDA kitoblar ombordan avtomatik ayriladi.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (paymentDone && paymentProof != null)
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: saving || state.cartLines.isEmpty
                      ? null
                      : () => _submit(state, deliveryFee),
                  icon: saving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    saving ? 'Yuborilmoqda...' : 'Buyurtmani yuborish',
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFDF9B)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: AppColors.warning),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Buyurtmani yuborish tugmasi chek skrinshotini joylaganingizdan keyin ochiladi.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAccount() async {
    await Clipboard.setData(const ClipboardData(text: AppState.bankAccount));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Karta raqami nusxalandi ✅')));
  }

  Future<void> _submit(AppState state, int deliveryFee) async {
    if (!formKey.currentState!.validate()) return;
    if (!paymentDone || paymentProof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('To‘lov qilgan bo‘lsangiz, chek skrinshotini tanlang.'),
        ),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final proof = paymentProof;
      final orderId = await state.placeOrder(
        customerName: name.text,
        phone: phone.text,
        address: address.text,
        deliveryType: delivery,
        deliveryFee: deliveryFee,
        paymentProof: proof,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, size: 58, color: _green),
          title: const Text('Buyurtma yuborildi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Buyurtma raqami:\n$orderId',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                proof != null
                    ? 'To‘lov cheki ham yuborildi. Admin tekshiradi va buyurtmani qabul qiladi.'
                    : 'Admin buyurtmani tekshiradi. To‘lovni amalga oshirgach, kerak bo‘lsa admin bilan bog‘lanishingiz mumkin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 9),
              const Text(
                'Qabul qilingandan keyin ombordagi qoldiq avtomatik yangilanadi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tushunarli'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _CheckoutStepHeader extends StatelessWidget {
  const _CheckoutStepHeader({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: UzbekCustomerColors.teal,
              borderRadius: BorderRadius.circular(11),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1610213D),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.onCopy});
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => UzbekPatternPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_rounded, color: AppColors.navy),
                SizedBox(width: 8),
                Text(
                  'To‘lov rekvizitlari',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppState.bankName,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      SelectableText(
                        AppState.bankAccount,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                          color: AppColors.navy,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        AppState.bankOwner,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('Nusxalash'),
                ),
              ],
            ),
          ],
        ),
      );
}

Widget _priceRow(String label, int value, {bool bold = false}) => Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
            fontSize: bold ? 17 : 14,
          ),
        ),
        const Spacer(),
        Text(
          won(value),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 20 : 14,
            color: bold ? _navy : null,
          ),
        ),
      ],
    );

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final activeBooks = state.books.where((b) => b.isActive).length;
    final availableBooks =
        state.books.where((b) => b.isActive && b.inStock).length;
    final displayName = (state.savedCustomer['name'] ?? '').trim().isNotEmpty
        ? state.savedCustomer['name']!.trim()
        : 'Muhajeer kitobxoni';
    final displayPhone = state.savedCustomer['phone'] ?? '';

    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Profil ma’lumotlarini tozalash',
            onPressed: () async {
              final shouldClear = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Profil ma’lumotlarini tozalash'),
                  content: const Text(
                    'Saqlangan ism, telefon va manzil shu qurilmadan o‘chiriladi. Do‘kondan foydalanishda davom etasiz.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Bekor qilish'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Tozalash'),
                    ),
                  ],
                ),
              );
              if (shouldClear != true || !context.mounted) return;
              await context.read<AppState>().signOutCustomer();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil ma’lumotlari tozalandi.')),
              );
            },
            icon: const Icon(Icons.person_remove_alt_1_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          UzbekPatternPanel(
            dark: true,
            strongPattern: true,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminGatePage()),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                ),
                if (displayPhone.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    displayPhone,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE5F1EE),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                const Text(
                  'Muhajeer Books',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF8E6BF),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const UzbekOrnamentDivider(),
                const SizedBox(height: 10),
                const Text(
                  'Koreyadagi O’zbek kitobxonlari uchun',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE5F1EE),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProfileStat(value: '$activeBooks', label: 'Kitoblar'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileStat(value: '$availableBooks', label: 'Mavjud'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileStat(
                  value: state.isOnlineBackend ? 'Onlayn' : 'Local',
                  label: 'Tizim',
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          const UzbekSectionTitle(
            title: 'Hisob va xizmatlar',
            subtitle: 'Buyurtmalar va do‘kon xizmatlari',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),
          AppSurface(
            padding: EdgeInsets.zero,
            borderColor: UzbekCustomerColors.border,
            child: Column(
              children: [
                ListTile(
                  minTileHeight: 68,
                  leading: const _ProfileIcon(
                    icon: Icons.receipt_long_outlined,
                  ),
                  title: const Text(
                    'Mening buyurtmalarim',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Holatini kuzatish va tarixni ko‘rish'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                  ),
                ),
                const Divider(),
                ListTile(
                  minTileHeight: 68,
                  leading: const _ProfileIcon(
                    icon: Icons.favorite_border_rounded,
                  ),
                  title: const Text(
                    'Sevimli kitoblar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Saqlab qo‘yilgan kitoblarni ko‘ring'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesPage()),
                  ),
                ),
                const Divider(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          UzbekPatternPanel(
            strongPattern: true,
            padding: const EdgeInsets.all(16),
            child: const Column(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: UzbekCustomerColors.goldDeep,
                  size: 28,
                ),
                SizedBox(height: 8),
                Text(
                  '“Kitob o‘qigan millat hech qachon yutqazmaydi.”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: UzbekCustomerColors.navy,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: UzbekCustomerColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: UzbekCustomerColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: UzbekCustomerColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: UzbekCustomerColors.goldSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: UzbekCustomerColors.border),
        ),
        child: Icon(icon, color: UzbekCustomerColors.teal, size: 21),
      );
}

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  late Future<List<ShopOrder>> future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final state = context.read<AppState>();
    future = state.customerOrdersByPhone(state.savedCustomer['phone'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Mening buyurtmalarim'),
        actions: [
          IconButton(
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<ShopOrder>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data ?? const [];
          if (orders.isEmpty) {
            return const _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Buyurtma topilmadi',
              subtitle:
                  'Buyurtma berganingizdan keyin uning holati va tarixi shu yerda ko‘rinadi.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final order = orders[i];
              return AppSurface(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buyurtma № ${order.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                DateFormat('yyyy.MM.dd • HH:mm')
                                    .format(order.createdAt),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _OrderStatusChip(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _OrderProgress(status: order.status),
                    const SizedBox(height: 14),
                    ...order.items.take(4).map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_stories_outlined,
                                  size: 15,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    '${item['title']} × ${item['quantity']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (order.items.length > 4)
                      Text(
                        '+ yana ${order.items.length - 4} ta',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    if (order.hasPaymentProof) ...[
                      const SizedBox(height: 8),
                      const AppInfoPill(
                        icon: Icons.receipt_rounded,
                        label: 'To‘lov cheki yuborilgan',
                        foreground: AppColors.success,
                        background: AppColors.successSoft,
                        border: Color(0xFFCDEAD7),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        const Text(
                          'Jami',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          won(order.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return const AppInfoPill(
        icon: Icons.cancel_rounded,
        label: 'Buyurtma bekor qilingan',
        foreground: AppColors.danger,
        background: AppColors.dangerSoft,
        border: Color(0xFFFFCCD1),
      );
    }
    final level = switch (status) {
      'accepted' || 'paid' => 1,
      'shipping' => 2,
      'done' => 3,
      _ => 0,
    };
    const labels = ['Yuborildi', 'Qabul qilindi', 'Jo‘natildi', 'Yakunlandi'];
    const icons = [
      Icons.outbox_rounded,
      Icons.inventory_2_rounded,
      Icons.local_shipping_rounded,
      Icons.task_alt_rounded,
    ];
    return Row(
      children: List.generate(labels.length, (i) {
        final done = i <= level;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color:
                            i <= level ? AppColors.success : AppColors.border,
                      ),
                    ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: done ? AppColors.success : AppColors.surfaceSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? AppColors.success : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      icons[i],
                      size: 15,
                      color: done ? Colors.white : AppColors.muted,
                    ),
                  ),
                  if (i < labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < level ? AppColors.success : AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: done ? FontWeight.w800 : FontWeight.w600,
                  color: done ? AppColors.text : AppColors.muted,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'accepted' => 'Qabul qilindi',
      'paid' => 'To‘landi',
      'shipping' => 'Jo‘natildi',
      'done' => 'Yakunlandi',
      'cancelled' => 'Bekor',
      _ => 'Yangi',
    };
    final color = switch (status) {
      'accepted' => _green,
      'paid' => Colors.blue,
      'shipping' => _orange,
      'done' => _green,
      'cancelled' => Colors.red,
      _ => _navy,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4D6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFFFDF8C)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF8A5A00)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 62, color: Colors.black26),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      );
}
