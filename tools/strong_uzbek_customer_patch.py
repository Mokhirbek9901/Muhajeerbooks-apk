from pathlib import Path
import re

path = Path('lib/store_ui.dart')
store = path.read_text(encoding='utf-8')


def sub_one(pattern: str, replacement: str, label: str, flags=re.S):
    global store
    updated, count = re.subn(pattern, replacement, store, count=1, flags=flags)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 replacement, got {count}')
    store = updated


# 1) Five-item customer navigation, matching the approved mockup.
old_shell = r'''class _StoreShellState extends State<StoreShell> \{.*?(?=class HomePage)'''
new_shell = r'''class _StoreShellState extends State<StoreShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = [
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
              selectedIcon: Icon(Icons.home_rounded, color: UzbekCustomerColors.goldDeep),
              label: 'Bosh sahifa',
            ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(Icons.grid_view_rounded, color: UzbekCustomerColors.goldDeep),
              label: 'Kategoriya',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: state.cartCount > 0,
                label: Text('${state.cartCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: state.cartCount > 0,
                label: Text('${state.cartCount}'),
                child: const Icon(Icons.shopping_cart_rounded, color: UzbekCustomerColors.goldDeep),
              ),
              label: 'Savatcha',
            ),
            const NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded, color: UzbekCustomerColors.goldDeep),
              label: 'Sevimlilar',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: UzbekCustomerColors.goldDeep),
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
        .map((b) => b.category.trim().isEmpty ? 'Boshqalar' : b.category.trim())
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
              final count = state.books.where((b) => b.isActive && b.category == c).length;
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CategoryBrowsePage(category: c)),
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
  if (v.contains('biznes') || v.contains('moliya')) return Icons.trending_up_rounded;
  if (v.contains('dini')) return Icons.auto_awesome_rounded;
  if (v.contains('bol')) return Icons.child_care_rounded;
  return Icons.auto_stories_rounded;
}

'''
sub_one(old_shell, new_shell, 'store shell')

# 2) Make the quick home category area visually Uzbek and functional.
sub_one(
    r'''const SliverPadding\(\s*padding: EdgeInsets\.fromLTRB\(16, 6, 16, 4\),\s*sliver: SliverToBoxAdapter\(child: _TrustStrip\(\)\),\s*\),''',
    r'''SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 5),
              sliver: SliverToBoxAdapter(
                child: _QuickCategoryStrip(
                  categories: categories,
                  selected: category,
                  onSelected: (value) => setState(() => category = value),
                ),
              ),
            ),''',
    'home quick categories',
)

# Remove duplicate generic category chips lower on the page.
sub_one(
    r'''SliverToBoxAdapter\(\s*child: SizedBox\(\s*height: 46,\s*child: ListView\.separated\(.*?\n\s*\),\s*\),\s*\),''',
    r'''const SliverToBoxAdapter(child: SizedBox(height: 2)),''',
    'duplicate categories',
)

# 3) Header exactly as brand header in the approved visual.
new_header = r'''class _StoreHeader extends StatelessWidget {
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
              IconButton(
                tooltip: 'Bildirishnomalar',
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: UzbekCustomerColors.navy,
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

'''
sub_one(r'''class _StoreHeader extends StatelessWidget \{.*?(?=class _DeliveryPromoCard)''', new_header, 'header')

# 4) Strong premium Uzbek hero like the approved concept.
new_promo = r'''class _DeliveryPromoCard extends StatelessWidget {
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
                    _HeroFact(icon: Icons.local_shipping_rounded, text: '1–3 ish kuni'),
                    _HeroFact(icon: Icons.payments_outlined, text: '택배 ₩4,000'),
                    _HeroFact(icon: Icons.card_giftcard_rounded, text: '4+ kitob — bepul'),
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

'''
sub_one(r'''class _DeliveryPromoCard extends StatelessWidget \{.*?(?=class _HeroFact)''', new_promo, 'hero')

# 5) Visual category strip.
quick_categories = r'''class _QuickCategoryStrip extends StatelessWidget {
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
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
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
                        c == 'Barchasi' ? Icons.grid_view_rounded : _categoryIcon(c),
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
                          fontWeight: active ? FontWeight.w900 : FontWeight.w700,
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

'''
idx = store.index('class _TrustStrip')
store = store[:idx] + quick_categories + store[idx:]

# 6) Recommended books become small vertical editorial cards as in the mockup.
new_featured = r'''class _FeaturedBooksStrip extends StatelessWidget {
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
                  MaterialPageRoute(builder: (_) => BookDetailPage(bookId: b.id)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 126, width: double.infinity, child: _BookCover(book: b)),
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
                                      backgroundColor: UzbekCustomerColors.navy,
                                    ),
                                    onPressed: b.inStock
                                        ? () => context.read<AppState>().addToCart(b)
                                        : null,
                                    child: const Icon(Icons.add_shopping_cart_rounded, size: 16),
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

'''
sub_one(r'''class _FeaturedBooksStrip extends StatelessWidget \{.*?(?=class BookCard)''', new_featured, 'featured books')

# 7) Profile from the approved fourth screen: fixed owner name, no photo.
new_profile = r'''class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final activeBooks = state.books.where((b) => b.isActive).length;
    final availableBooks = state.books.where((b) => b.isActive && b.inStock).length;

    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Profil'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
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
                const UzbekMedallion(size: 58, dark: true),
                const SizedBox(height: 10),
                const Text(
                  'Mohirbek Ismoilov',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.3,
                  ),
                ),
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
              Expanded(child: _ProfileStat(value: '$activeBooks', label: 'Kitoblar')),
              const SizedBox(width: 8),
              Expanded(child: _ProfileStat(value: '$availableBooks', label: 'Mavjud')),
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
                  leading: const _ProfileIcon(icon: Icons.receipt_long_outlined),
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
                  leading: const _ProfileIcon(icon: Icons.favorite_border_rounded),
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
                ListTile(
                  minTileHeight: 68,
                  leading: const _ProfileIcon(icon: Icons.admin_panel_settings_outlined),
                  title: const Text(
                    'Admin paneli',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Kitoblar, ombor, statistika va buyurtmalar'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminGatePage()),
                  ),
                ),
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

'''
sub_one(r'''class ProfilePage extends StatelessWidget \{.*?(?=class _ProfileIcon)''', new_profile, 'profile')

# Stronger profile menu icon colors.
store = store.replace(
    "color: AppColors.surfaceSoft,\n      borderRadius: BorderRadius.circular(13),\n      border: Border.all(color: AppColors.border),",
    "color: UzbekCustomerColors.goldSoft,\n      borderRadius: BorderRadius.circular(13),\n      border: Border.all(color: UzbekCustomerColors.border),",
    1,
)
store = store.replace(
    "child: Icon(icon, color: AppColors.navy, size: 21),",
    "child: Icon(icon, color: UzbekCustomerColors.teal, size: 21),",
    1,
)

path.write_text(store, encoding='utf-8')
print('Strong Uzbek premium customer UI applied.')
