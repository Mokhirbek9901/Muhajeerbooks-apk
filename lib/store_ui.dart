import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'admin_ui.dart';
import 'app_state.dart';
import 'brand.dart';
import 'design_system.dart';

const _navy = Color(0xFF10213D);
const _orange = Color(0xFFFF8A00);
const _gold = Color(0xFFFFC928);
const _cream = Color(0xFFFFFBF1);
const _green = Color(0xFF138A4B);

final _money = NumberFormat('#,###', 'en_US');
String won(int value) => '₩${_money.format(value)}';

class StoreShell extends StatefulWidget {
  const StoreShell({super.key});

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = [
      const HomePage(),
      const FavoritesPage(),
      const CartPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Bosh sahifa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Sevimli',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: state.cartCount > 0,
              label: Text('${state.cartCount}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: state.cartCount > 0,
              label: Text('${state.cartCount}'),
              child: const Icon(Icons.shopping_bag_rounded),
            ),
            label: 'Savat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
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
      final matchesQuery =
          q.isEmpty ||
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
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
              sliver: SliverToBoxAdapter(child: _TrustStrip()),
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
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = categories[i];
                    return ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      onSelected: (_) => setState(() => category = c),
                    );
                  },
                ),
              ),
            ),
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
                    text: 'Ma’lumotni yangilashda xatolik bo‘ldi. Oxirgi saqlangan ma’lumot ko‘rsatilmoqda.',
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

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final active = state.books.where((b) => b.isActive).length;
    final available = state.books.where((b) => b.isActive && b.inStock).length;
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      shadow: true,
      child: Row(
        children: [
          const MuhajeerLogoBadge(size: 58, radius: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Muhajeer Books',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Koreyadagi O’zbek kitobxonlari uchun',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppInfoPill(
                      icon: Icons.auto_stories_outlined,
                      label: '$active kitob',
                    ),
                    AppInfoPill(
                      icon: Icons.inventory_2_outlined,
                      label: '$available mavjud',
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
          AppInfoPill(
            icon: state.isOnlineBackend
                ? Icons.cloud_done_rounded
                : Icons.save_rounded,
            label: state.isOnlineBackend ? 'Onlayn' : 'Saqlanadi',
            foreground: state.isOnlineBackend
                ? AppColors.success
                : AppColors.warning,
            background: state.isOnlineBackend
                ? AppColors.successSoft
                : AppColors.warningSoft,
            border: state.isOnlineBackend
                ? const Color(0xFFCDEAD7)
                : const Color(0xFFFFDCA0),
          ),
        ],
      ),
    );
  }
}

class _DeliveryPromoCard extends StatelessWidget {
  const _DeliveryPromoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navy2],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2610213D),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -42,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Color(0x16FFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 55,
            bottom: -55,
            child: Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Color(0x10FFC928),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppInfoPill(
                icon: Icons.local_shipping_rounded,
                label: 'Koreya bo‘ylab yetkazib berish',
                foreground: Colors.white,
                background: Color(0x1FFFFFFF),
                border: Color(0x30FFFFFF),
              ),
              const SizedBox(height: 14),
              const Text(
                'Kitobingizni qulay buyurtma qiling,\nqolganini biz hal qilamiz.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.16,
                ),
              ),
              const SizedBox(height: 13),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroFact(icon: Icons.payments_outlined, text: '택배 ₩4,000'),
                  _HeroFact(icon: Icons.schedule_rounded, text: '1–3 ish kuni'),
                  _HeroFact(
                    icon: Icons.card_giftcard_rounded,
                    text: '4+ kitob — bepul',
                  ),
                ],
              ),
            ],
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

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE7E9ED)),
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
          child: _TrustItem(icon: Icons.schedule_rounded, text: '1–3 ish kuni'),
        ),
        _TrustDivider(),
        Expanded(
          child: _TrustItem(
            icon: Icons.support_agent_rounded,
            text: 'Yordam mavjud',
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
      Container(width: 1, height: 30, color: const Color(0xFFE7E9ED));
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
        Icon(icon, size: 18, color: _navy),
        const SizedBox(height: 4),
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
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
      const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: _orange, size: 20),
          SizedBox(width: 7),
          Text(
            'Tavsiya etamiz',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      const SizedBox(height: 9),
      SizedBox(
        height: 176,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: books.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final b = books[i];
            return SizedBox(
              width: 265,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookDetailPage(bookId: b.id),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 108,
                        height: double.infinity,
                        child: _BookCover(book: b),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                b.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                b.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                won(b.currentPrice),
                                style: const TextStyle(
                                  color: _navy,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${b.stock} dona mavjud',
                                style: const TextStyle(
                                  color: _green,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
    final state = context.watch<AppState>();
    final favorite = state.isFavorite(book);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B0F172A),
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
                        color: book.inStock
                            ? AppColors.success
                            : AppColors.danger,
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
        body: SafeArea(child: Center(child: Text('Kitob topilmadi'))),
      );
    }
    final b = book;
    return Scaffold(
      appBar: AppBar(
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
            label: book.inStock ? '${book.stock} dona mavjud' : 'Mavjud emas',
            foreground: book.inStock ? AppColors.success : AppColors.danger,
            background: book.inStock
                ? AppColors.successSoft
                : AppColors.dangerSoft,
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
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
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
    final books = state.books
        .where((b) => b.isActive && state.isFavorite(b))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Sevimlilar')),
      body: books.isEmpty
          ? const _EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Sevimlilar hali bo‘sh',
              subtitle: 'Yoqtirgan kitobingizdagi yurakchani bosing — keyin shu yerda tez topasiz.',
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
                          childAspectRatio: constraints.maxWidth < 450
                              ? .57
                              : .62,
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
      appBar: AppBar(
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
              subtitle: 'Kerakli kitoblarni savatchaga qo‘shing. 4 ta va undan ko‘p kitobda yetkazib berish bepul.',
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
    final deliveryFee = delivery == 'Gyeongsan' || state.cartCount >= 4
        ? 0
        : AppState.deliveryFee;
    final total = state.cartSubtotal + deliveryFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtmani rasmiylashtirish')),
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
                        hintText: '010-1234-5678',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) =>
                          v == null ||
                              v.replaceAll(RegExp(r'\D'), '').length < 7
                          ? 'Telefon raqamni to‘liq kiriting'
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
                        helperText: 'Manzil va xona raqamini to‘liq yozing.\nMasalan: 경상북도 경산시 계양로 37길 7-3, 808호',
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
                  const Divider(height: 1),
                  RadioListTile<String>(
                    value: 'Gyeongsan',
                    groupValue: delivery,
                    onChanged: (v) => setState(() => delivery = v!),
                    title: const Text(
                      'Gyeongsan ichida',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Bepul yetkazib berish'),
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
                label: Text(saving ? 'Yuborilmoqda...' : 'Buyurtmani yuborish'),
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
    if (paymentDone && paymentProof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('To‘lov qilgan bo‘lsangiz, chek skrinshotini tanlang.'),
        ),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final proof = paymentDone ? paymentProof : null;
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
          color: AppColors.navy,
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFBF1), Color(0xFFFFF2D2)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFFFD88A)),
    ),
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
    final name = state.savedCustomer['name'] ?? '';
    final phone = state.savedCustomer['phone'] ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navy2],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2510213D),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const MuhajeerLogoCircle(size: 68),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.trim().isEmpty
                            ? 'Muhajeer Books mijoz'
                            : name.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone.trim().isEmpty
                            ? 'Yaxshi kitob — yaxshi hayot!'
                            : phone,
                        style: const TextStyle(
                          color: Color(0xFFDCE5F2),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 9),
                      AppInfoPill(
                        icon: state.isOnlineBackend
                            ? Icons.cloud_done_rounded
                            : Icons.save_rounded,
                        label: state.isOnlineBackend
                            ? 'Onlayn hisob'
                            : 'Qurilmada saqlanadi',
                        foreground: Colors.white,
                        background: const Color(0x18FFFFFF),
                        border: const Color(0x2FFFFFFF),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AppSectionHeader(
            title: 'Hisob va xizmatlar',
            subtitle: 'Buyurtmalar va do‘kon boshqaruvi',
          ),
          const SizedBox(height: 10),
          AppSurface(
            padding: EdgeInsets.zero,
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
                  subtitle: Text(
                    phone.isEmpty
                        ? 'Buyurtma berganingizdan keyin ko‘rinadi'
                        : 'Holatini kuzatish va tarixni ko‘rish',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                  ),
                ),
                const Divider(),
                ListTile(
                  minTileHeight: 68,
                  leading: _ProfileIcon(
                    icon: state.isOnlineBackend
                        ? Icons.cloud_done_outlined
                        : Icons.save_outlined,
                  ),
                  title: const Text(
                    'Ma’lumotlar holati',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    state.isOnlineBackend
                        ? 'Barcha qurilmalarda sinxron ishlaydi'
                        : 'Hozir shu qurilmada saqlanadi',
                  ),
                ),
                const Divider(),
                ListTile(
                  minTileHeight: 68,
                  leading: const _ProfileIcon(
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                  title: const Text(
                    'Admin paneli',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Kitoblar, ombor, chegirma va buyurtmalar',
                  ),
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
          AppSurface(
            backgroundColor: AppColors.surfaceSoft,
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.success),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buyurtma, manzil va to‘lov cheki faqat buyurtmani bajarish uchun ishlatiladi. To‘lov cheki maxfiy saqlanadi.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
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

class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.border),
    ),
    child: Icon(icon, color: AppColors.navy, size: 21),
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
      appBar: AppBar(
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
              subtitle: 'Buyurtma berganingizdan keyin uning holati va tarixi shu yerda ko‘rinadi.',
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
                    ...order.items
                        .take(4)
                        .map(
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
                        color: i <= level
                            ? AppColors.success
                            : AppColors.border,
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
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
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
