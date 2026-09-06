import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'admin_ui.dart';
import 'app_state.dart';
import 'brand.dart';

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
    final categories = <String>{'Barchasi', ...state.books.where((b) => b.isActive).map((b) => b.category)}.toList();
    if (!categories.contains(category)) category = 'Barchasi';

    final books = state.books.where((book) {
      final q = query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          book.title.toLowerCase().contains(q) ||
          book.author.toLowerCase().contains(q) ||
          book.category.toLowerCase().contains(q);
      final matchesCategory = category == 'Barchasi' || book.category == category;
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
        books.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
                        PopupMenuItem(value: 'new', child: Text('Yangi qo‘shilgan')),
                        PopupMenuItem(value: 'name', child: Text('Nom bo‘yicha')),
                        PopupMenuItem(value: 'price_low', child: Text('Arzonidan')),
                        PopupMenuItem(value: 'price_high', child: Text('Qimmatidan')),
                        PopupMenuItem(value: 'stock', child: Text('Ko‘p qoldiq')),
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
                      query.trim().isEmpty && category == 'Barchasi' ? 'Kitoblar' : 'Natijalar',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text('${books.length} ta', style: const TextStyle(color: Colors.black54)),
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
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
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
                    final count = width >= 1150 ? 5 : width >= 850 ? 4 : width >= 600 ? 3 : 2;
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
    return Row(
      children: [
        const MuhajeerLogoBadge(size: 58, radius: 17),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Muhajeer Books', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 2),
              Text('Koreyadagi o‘zbek kitob do‘koni', style: TextStyle(color: Colors.black54, fontSize: 13)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: state.isOnlineBackend ? const Color(0xFFE8F7EE) : const Color(0xFFFFF4D6),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.isOnlineBackend ? Icons.cloud_done_rounded : Icons.save_rounded,
                size: 15,
                color: state.isOnlineBackend ? _green : const Color(0xFF8A5A00),
              ),
              const SizedBox(width: 4),
              Text(
                state.isOnlineBackend ? 'Onlayn' : 'Saqlanadi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: state.isOnlineBackend ? _green : const Color(0xFF8A5A00),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliveryPromoCard extends StatelessWidget {
  const _DeliveryPromoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_navy, Color(0xFF1A365E)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x1810213D), blurRadius: 16, offset: Offset(0, 7))],
      ),
      child: const Row(
        children: [
          ContainerIcon(icon: Icons.local_shipping_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Koreya bo‘ylab tez yetkazib berish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text('택배 ₩4,000 • 1–3 ish kuni • 4+ kitobda bepul', style: TextStyle(color: Color(0xFFDCE5F2), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContainerIcon extends StatelessWidget {
  const ContainerIcon({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, color: _gold),
      );
}

class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(bookId: book.id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BookCover(book: book),
                  if (book.isDiscounted)
                    Positioned(
                      top: 9,
                      right: 9,
                      child: _Badge(text: '-${book.discountPercent}%', color: const Color(0xFFE63D3D)),
                    ),
                  if (book.recommended)
                    const Positioned(
                      bottom: 8,
                      left: 8,
                      child: _Badge(text: 'Tavsiya', color: _orange),
                    ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => state.toggleFavorite(book),
                      icon: Icon(state.isFavorite(book) ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, height: 1.15)),
                  const SizedBox(height: 4),
                  Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11.5)),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.inStock ? '${book.stock} dona' : 'Mavjud emas',
                          style: TextStyle(color: book.inStock ? _green : Colors.red, fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (book.coverType != 'Ko‘rsatilmagan')
                        Text(book.coverType, style: const TextStyle(color: Colors.black45, fontSize: 10.5)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (book.isDiscounted)
                    Text(won(book.price), style: const TextStyle(color: Colors.black38, decoration: TextDecoration.lineThrough, fontSize: 11)),
                  Text(won(book.currentPrice), style: const TextStyle(color: _navy, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 7),
                  SizedBox(
                    width: double.infinity,
                    height: 39,
                    child: FilledButton.icon(
                      onPressed: book.inStock
                          ? () {
                              state.addToCart(book);
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(content: Text('${book.title} savatga qo‘shildi ✅'), duration: const Duration(milliseconds: 900)));
                            }
                          : null,
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
                      label: Text(book.inStock ? 'Savatga' : 'Tugagan'),
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
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    if (book.imageUrl.isNotEmpty) {
      return Image.network(book.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_cream, Color(0xFFFFE9B0)]),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: .08,
                child: Image.asset('assets/images/muhajeer_logo.png', fit: BoxFit.cover),
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
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
      );
}

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    Book? book;
    for (final b in state.books) {
      if (b.id == bookId) {
        book = b;
        break;
      }
    }
    if (book == null) {
      return const Scaffold(body: SafeArea(child: Center(child: Text('Kitob topilmadi'))));
    }
    final b = book;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitob haqida'),
        actions: [
          IconButton(
            onPressed: () => state.toggleFavorite(b),
            icon: Icon(state.isFavorite(b) ? Icons.favorite_rounded : Icons.favorite_border_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          Center(
            child: Container(
              width: 230,
              height: 320,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 10))]),
              clipBehavior: Clip.antiAlias,
              child: _BookCover(book: b),
            ),
          ),
          const SizedBox(height: 24),
          Text(b.title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, height: 1.12)),
          const SizedBox(height: 6),
          Text(b.author, style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(avatar: const Icon(Icons.category_outlined, size: 17), label: Text(b.category)),
              Chip(avatar: const Icon(Icons.inventory_2_outlined, size: 17), label: Text('Omborda ${b.stock} dona')),
              if (b.coverType != 'Ko‘rsatilmagan') Chip(avatar: const Icon(Icons.book_outlined, size: 17), label: Text(b.coverType)),
            ],
          ),
          const SizedBox(height: 18),
          if (b.description.isNotEmpty && b.description != 'Ma’lumot kiritilmagan.') ...[
            const Text('Kitob haqida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(b.description, style: const TextStyle(height: 1.55, fontSize: 15)),
            const SizedBox(height: 18),
          ],
          if (b.isDiscounted)
            Text(won(b.price), style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.black38, fontSize: 14)),
          Text(won(b.currentPrice), style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: _navy)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 18, offset: Offset(0, -4))]),
          child: FilledButton.icon(
            onPressed: b.inStock
                ? () {
                    state.addToCart(b);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Savatchaga qo‘shildi ✅')));
                  }
                : null,
            icon: const Icon(Icons.shopping_bag_rounded),
            label: Text(b.inStock ? 'Savatchaga qo‘shish' : 'Hozircha mavjud emas'),
          ),
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final books = state.books.where((b) => b.isActive && state.isFavorite(b)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Sevimli kitoblar')),
      body: books.isEmpty
          ? const _EmptyState(icon: Icons.favorite_border_rounded, title: 'Sevimlilar bo‘sh', subtitle: 'Yoqtirgan kitobingizdagi yurakchani bosing.')
          : LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 600 ? 3 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: books.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .60,
                  ),
                  itemBuilder: (_, i) => BookCard(book: books[i]),
                );
              },
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
            TextButton(onPressed: state.clearCart, child: const Text('Tozalash')),
        ],
      ),
      body: lines.isEmpty
          ? const _EmptyState(icon: Icons.shopping_bag_outlined, title: 'Savatcha bo‘sh', subtitle: 'Kitob tanlang va savatchaga qo‘shing.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
              itemCount: lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final line = lines[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(width: 72, height: 98, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _BookCover(book: line.book))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line.book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 5),
                              Text(won(line.book.currentPrice), style: const TextStyle(color: _navy, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  _QtyButton(icon: Icons.remove, onTap: () => state.decrementCart(line.book)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 13),
                                    child: Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                  ),
                                  _QtyButton(
                                    icon: Icons.add,
                                    onTap: line.quantity < line.book.stock ? () => state.addToCart(line.book) : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Text(won(line.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            IconButton(onPressed: () => state.removeFromCart(line.book), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: lines.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 18, offset: Offset(0, -4))]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Kitoblar jami', style: TextStyle(color: Colors.black54)),
                        const Spacer(),
                        Text(won(state.cartSubtotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        state.cartCount >= 4 ? '🎁 4+ kitob: yetkazib berish bepul' : '🚚 택배 ₩4,000 • 4+ kitobda bepul',
                        style: TextStyle(color: state.cartCount >= 4 ? _green : Colors.black54, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage())),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Buyurtma berish'),
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
        child: IconButton.outlined(onPressed: onTap, padding: EdgeInsets.zero, iconSize: 18, icon: Icon(icon)),
      );
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController address;
  String delivery = '택배';
  bool saving = false;

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final deliveryFee = delivery == 'Gyeongsan' || state.cartCount >= 4 ? 0 : AppState.deliveryFee;
    final total = state.cartSubtotal + deliveryFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtmani rasmiylashtirish')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Qabul qiluvchi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            TextFormField(
              controller: name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Ism va familiya', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) => v == null || v.trim().length < 2 ? 'Ismingizni kiriting' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Telefon raqam', hintText: '010-1234-5678', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) => v == null || v.replaceAll(RegExp(r'\D'), '').length < 7 ? 'Telefon raqamni to‘liq kiriting' : null,
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
              validator: (v) => v == null || v.trim().length < 8 ? 'To‘liq manzilni kiriting' : null,
            ),
            const SizedBox(height: 20),
            const Text('Yetkazib berish', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: '택배',
                    groupValue: delivery,
                    onChanged: (v) => setState(() => delivery = v!),
                    title: const Text('Koreya bo‘ylab 택배'),
                    subtitle: Text(state.cartCount >= 4 ? '4+ kitob aksiyasi — BEPUL • 1–3 ish kuni' : '₩4,000 • 1–3 ish kuni'),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    value: 'Gyeongsan',
                    groupValue: delivery,
                    onChanged: (v) => setState(() => delivery = v!),
                    title: const Text('Gyeongsan ichida'),
                    subtitle: const Text('Bepul yetkazib berish'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('To‘lov ma’lumoti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            _PaymentCard(onCopy: _copyAccount),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _priceRow('Kitoblar', state.cartSubtotal),
                    const SizedBox(height: 8),
                    _priceRow('Yetkazib berish', deliveryFee),
                    const Divider(height: 22),
                    _priceRow('Jami', total, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: saving || state.cartLines.isEmpty ? null : () => _submit(state, deliveryFee),
              icon: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Buyurtmani tasdiqlash'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Buyurtma tasdiqlangach savatcha tozalanadi va ombordagi qoldiq yangilanadi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAccount() async {
    await Clipboard.setData(const ClipboardData(text: AppState.bankAccount));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Karta raqami nusxalandi ✅')));
  }

  Future<void> _submit(AppState state, int deliveryFee) async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final orderId = await state.placeOrder(
        customerName: name.text,
        phone: phone.text,
        address: address.text,
        deliveryType: delivery,
        deliveryFee: deliveryFee,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, size: 58, color: _green),
          title: const Text('Buyurtma qabul qilindi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Buyurtma raqami: $orderId', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('To‘lovni quyidagi hisobga yuboring:'),
              const SizedBox(height: 7),
              const SelectableText('${AppState.bankName}\n${AppState.bankAccount}\n${AppState.bankOwner}', textAlign: TextAlign.center),
            ],
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tushunarli'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.onCopy});
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _cream, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFFDB7B))),
        child: Row(
          children: [
            const ContainerIcon(icon: Icons.account_balance_rounded),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppState.bankName, style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  SelectableText(AppState.bankAccount, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: .4)),
                  Text(AppState.bankOwner, style: TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            IconButton(onPressed: onCopy, tooltip: 'Nusxalash', icon: const Icon(Icons.copy_rounded)),
          ],
        ),
      );
}

Widget _priceRow(String label, int value, {bool bold = false}) => Row(
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w500, fontSize: bold ? 17 : 14)),
        const Spacer(),
        Text(won(value), style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, fontSize: bold ? 20 : 14, color: bold ? _navy : null)),
      ],
    );

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final phone = state.savedCustomer['phone'] ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  const MuhajeerLogoCircle(size: 62),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Muhajeer Books', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text('Yaxshi kitob — yaxshi hayot!', style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Mening buyurtmalarim'),
                  subtitle: Text(phone.isEmpty ? 'Buyurtma berganingizdan keyin ko‘rinadi' : phone),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersPage())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(state.isOnlineBackend ? Icons.cloud_done_outlined : Icons.save_outlined),
                  title: const Text('Ma’lumot saqlanishi'),
                  subtitle: Text(state.isOnlineBackend ? 'Onlayn baza ulangan — barcha qurilmalarda bir xil' : 'Hozir o‘zgarishlar shu qurilmada saqlanadi'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Admin paneli'),
                  subtitle: const Text('Kitoblar, ombor, chegirma va buyurtmalar'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminGatePage())),
                ),
              ],
            ),
          ),
          if (!state.isOnlineBackend) ...[
            const SizedBox(height: 12),
            const _InfoBanner(
              icon: Icons.info_outline_rounded,
              text: 'Sinov versiyada qo‘shgan va tahrirlagan kitoblaringiz endi yo‘qolmaydi — shu telefon/brauzerda saqlanadi. Onlayn baza ulangach barcha qurilmalar bir xil ma’lumotni ko‘radi.',
            ),
          ],
        ],
      ),
    );
  }
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
    final state = context.read<AppState>();
    future = state.customerOrdersByPhone(state.savedCustomer['phone'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mening buyurtmalarim')),
      body: FutureBuilder<List<ShopOrder>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data ?? const [];
          if (orders.isEmpty) {
            return const _EmptyState(icon: Icons.receipt_long_outlined, title: 'Buyurtma topilmadi', subtitle: 'Shu qurilmada saqlangan telefon raqamingiz bo‘yicha buyurtmalar ko‘rinadi.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final order = orders[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('№ ${order.id}', style: const TextStyle(fontWeight: FontWeight.w900))),
                          _OrderStatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...order.items.take(4).map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• ${item['title']} × ${item['quantity']}'),
                          )),
                      if (order.items.length > 4) Text('+ yana ${order.items.length - 4} ta'),
                      const Divider(height: 20),
                      Row(children: [Text(DateFormat('yyyy.MM.dd HH:mm').format(order.createdAt), style: const TextStyle(color: Colors.black54, fontSize: 12)), const Spacer(), Text(won(order.total), style: const TextStyle(fontWeight: FontWeight.w900))]),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'paid' => 'To‘landi',
      'shipping' => 'Jo‘natildi',
      'done' => 'Yakunlandi',
      'cancelled' => 'Bekor',
      _ => 'Yangi',
    };
    final color = switch (status) {
      'paid' => Colors.blue,
      'shipping' => _orange,
      'done' => _green,
      'cancelled' => Colors.red,
      _ => _navy,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
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
        decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFFFDF8C))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: const Color(0xFF8A5A00)), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(height: 1.35)))]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
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
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4)),
            ],
          ),
        ),
      );
}
