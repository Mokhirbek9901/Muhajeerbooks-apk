import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'admin_ui.dart';
import 'app_state.dart';

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
            selectedIcon: Icon(Icons.home),
            label: 'Bosh sahifa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Sevimli',
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
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Savat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = <String>{'Barchasi', ...state.books.map((b) => b.category)}.toList();
    final books = state.books.where((book) {
      final q = query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          book.title.toLowerCase().contains(q) ||
          book.author.toLowerCase().contains(q);
      final matchesCategory = category == 'Barchasi' || book.category == category;
      return book.isActive && matchesQuery && matchesCategory;
    }).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.refreshBooks,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF176B45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text('📚', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Muhajeer Books',
                              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                          Text('Koreyadagi o‘zbek kitob do‘koni',
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!state.backendConfigured)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                sliver: SliverToBoxAdapter(
                  child: _InfoBanner(
                    icon: Icons.cloud_off_outlined,
                    text: 'Hozir demo rejim. Supabase ulangach kitoblar va buyurtmalar onlayn ishlaydi.',
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'Kitob yoki muallif bo‘yicha qidirish...',
                    prefixIcon: Icon(Icons.search),
                  ),
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
            if (state.loading && state.books.isEmpty)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (books.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Kitob topilmadi')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final count = width >= 1050 ? 5 : width >= 760 ? 4 : width >= 520 ? 3 : 2;
                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => BookCard(book: books[i]),
                        childCount: books.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: .60,
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

class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
        ),
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
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('-${book.discountPercent}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => state.toggleFavorite(book),
                      icon: Icon(state.isFavorite(book) ? Icons.favorite : Icons.favorite_border),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 7),
                  if (book.isDiscounted)
                    Text(won(book.price),
                        style: const TextStyle(
                          color: Colors.black45,
                          decoration: TextDecoration.lineThrough,
                          fontSize: 12,
                        )),
                  Text(won(book.currentPrice),
                      style: const TextStyle(
                        color: Color(0xFF0A7A3B),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      )),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: book.inStock ? () => state.addToCart(book) : null,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: Text(book.inStock ? 'Savatga' : 'Mavjud emas'),
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
      return Image.network(
        book.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFEFF4F1),
        alignment: Alignment.center,
        child: const Icon(Icons.menu_book_rounded, size: 58, color: Color(0xFF176B45)),
      );
}

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kitob haqida')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SizedBox(
              width: 230,
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _BookCover(book: book),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(book.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(book.author, style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(book.category)),
              Chip(label: Text('Omborda: ${book.stock} dona')),
            ],
          ),
          const SizedBox(height: 12),
          if (book.description.isNotEmpty) Text(book.description, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 20),
          if (book.isDiscounted)
            Text(won(book.price),
                style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.black45)),
          Text(won(book.currentPrice),
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: Color(0xFF0A7A3B))),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: book.inStock ? () => state.addToCart(book) : null,
            icon: const Icon(Icons.shopping_cart_checkout),
            label: Text(book.inStock ? 'Savatga qo‘shish' : 'Hozircha mavjud emas'),
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
    final books = state.books.where(state.isFavorite).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Sevimli kitoblar')),
      body: books.isEmpty
          ? const Center(child: Text('Hali sevimli kitob yo‘q'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: books.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .60,
              ),
              itemBuilder: (_, i) => BookCard(book: books[i]),
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
      appBar: AppBar(title: const Text('Savatcha')),
      body: lines.isEmpty
          ? const Center(child: Text('Savatcha bo‘sh'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final line = lines[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(width: 64, height: 88, child: ClipRRect(
                          borderRadius: BorderRadius.circular(10), child: _BookCover(book: line.book))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line.book.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text(won(line.book.currentPrice),
                                  style: const TextStyle(color: Color(0xFF0A7A3B), fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  IconButton.outlined(
                                    onPressed: () => state.decrementCart(line.book),
                                    icon: const Icon(Icons.remove),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                  IconButton.outlined(
                                    onPressed: line.quantity < line.book.stock
                                        ? () => state.addToCart(line.book)
                                        : null,
                                    icon: const Icon(Icons.add),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => state.removeFromCart(line.book),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [
                  BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, -4)),
                ]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jami:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(won(state.cartSubtotal),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0A7A3B))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CheckoutPage()),
                        ),
                        icon: const Icon(Icons.payment),
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

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  String delivery = '택배';
  bool saving = false;

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
    final deliveryFee = delivery == 'Gyeongsan' ? 0 : 4000;
    final total = state.cartSubtotal + deliveryFee;
    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtmani rasmiylashtirish')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Ism va familiya', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v == null || v.trim().length < 2 ? 'Ismingizni kiriting' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon raqam', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) => v == null || v.trim().length < 7 ? 'Telefon raqamni kiriting' : null,
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
            const SizedBox(height: 18),
            const Text('Yetkazib berish', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            RadioListTile<String>(
              value: '택배',
              groupValue: delivery,
              onChanged: (v) => setState(() => delivery = v!),
              title: const Text('Koreya bo‘ylab 택배'),
              subtitle: const Text('₩4,000 • odatda 1–3 ish kuni'),
            ),
            RadioListTile<String>(
              value: 'Gyeongsan',
              groupValue: delivery,
              onChanged: (v) => setState(() => delivery = v!),
              title: const Text('Gyeongsan ichida'),
              subtitle: const Text('Bepul yetkazib berish'),
            ),
            const Divider(height: 28),
            _priceRow('Kitoblar', state.cartSubtotal),
            _priceRow('Yetkazib berish', deliveryFee),
            const SizedBox(height: 8),
            _priceRow('Jami', total, bold: true),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving ? null : () => _submit(state, deliveryFee, total),
              icon: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Buyurtmani tasdiqlash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, int value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w500)),
            Text(won(value), style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 20 : 15)),
          ],
        ),
      );

  Future<void> _submit(AppState state, int deliveryFee, int total) async {
    if (!formKey.currentState!.validate()) return;
    if (state.cartLines.isEmpty) return;
    setState(() => saving = true);
    try {
      String orderId = 'DEMO-${DateTime.now().millisecondsSinceEpoch}';
      if (state.backend != null) {
        orderId = await state.backend!.createOrder(
          customerName: name.text,
          phone: phone.text,
          address: address.text,
          deliveryType: delivery,
          deliveryFee: deliveryFee,
          subtotal: state.cartSubtotal,
          total: total,
          lines: state.cartLines,
        );
      }
      if (!mounted) return;
      state.clearCart();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Buyurtma qabul qilindi ✅'),
          content: Text('Buyurtma raqami: $orderId\n\nAdmin buyurtmani ko‘rib, keyingi ma’lumotni sizga yuboradi.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Yopish'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('MB')),
              title: Text('Muhajeer Books', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Yaxshi kitob — yaxshi hayot!'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Admin paneli'),
                  subtitle: const Text('Kitoblar, ombor, chegirma va buyurtmalar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminGatePage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(state.backendConfigured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
                  title: const Text('Server holati'),
                  subtitle: Text(state.backendConfigured ? 'Supabase ulangan' : 'Demo rejim'),
                ),
              ],
            ),
          ),
        ],
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
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Text(text))]),
      );
}
