from pathlib import Path


def replace_between(text: str, start: str, end: str, new: str, label: str) -> str:
    i = text.find(start)
    if i < 0:
        raise SystemExit(f"Start marker not found: {label}")
    j = text.find(end, i)
    if j < 0:
        raise SystemExit(f"End marker not found: {label}")
    return text[:i] + new.rstrip() + "\n\n" + text[j:]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Pattern not found: {label}")
    return text.replace(old, new, 1)


# -------------------------
# MAIN THEME
# -------------------------
p = Path('lib/main.dart')
text = p.read_text(encoding='utf-8')
if "import 'design_system.dart';" not in text:
    text = text.replace("import 'app_state.dart';\n", "import 'app_state.dart';\nimport 'design_system.dart';\n", 1)
start = text.find('        theme: ThemeData(')
end = text.find('        home: const StoreShell(),', start)
if start < 0 or end < 0:
    raise SystemExit('Theme block not found')
text = text[:start] + '        theme: MuhajeerDesign.theme,\n' + text[end:]
p.write_text(text, encoding='utf-8')


# -------------------------
# STOREFRONT
# -------------------------
p = Path('lib/store_ui.dart')
text = p.read_text(encoding='utf-8')
if "import 'design_system.dart';" not in text:
    text = text.replace("import 'brand.dart';\n", "import 'brand.dart';\nimport 'design_system.dart';\n", 1)
text = text.replace("assets/images/muhajeer_logo.png", "assets/images/muhajeer_logo.jpg")

store_header = r'''class _StoreHeader extends StatelessWidget {
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
                Text('Muhajeer Books', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                const Text(
                  'Koreyadagi o‘zbek kitob do‘koni',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
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
            icon: state.isOnlineBackend ? Icons.cloud_done_rounded : Icons.save_rounded,
            label: state.isOnlineBackend ? 'Onlayn' : 'Saqlanadi',
            foreground: state.isOnlineBackend ? AppColors.success : AppColors.warning,
            background: state.isOnlineBackend ? AppColors.successSoft : AppColors.warningSoft,
            border: state.isOnlineBackend ? const Color(0xFFCDEAD7) : const Color(0xFFFFDCA0),
          ),
        ],
      ),
    );
  }
}'''
text = replace_between(text, 'class _StoreHeader extends StatelessWidget {', 'class _DeliveryPromoCard extends StatelessWidget {', store_header, 'store header')

promo = r'''class _DeliveryPromoCard extends StatelessWidget {
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
          BoxShadow(color: Color(0x2610213D), blurRadius: 28, offset: Offset(0, 12)),
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
              decoration: const BoxDecoration(color: Color(0x16FFFFFF), shape: BoxShape.circle),
            ),
          ),
          Positioned(
            right: 55,
            bottom: -55,
            child: Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(color: Color(0x10FFC928), shape: BoxShape.circle),
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
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.16),
              ),
              const SizedBox(height: 13),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroFact(icon: Icons.payments_outlined, text: '택배 ₩4,000'),
                  _HeroFact(icon: Icons.schedule_rounded, text: '1–3 ish kuni'),
                  _HeroFact(icon: Icons.card_giftcard_rounded, text: '4+ kitob — bepul'),
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
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}'''
text = replace_between(text, 'class _DeliveryPromoCard extends StatelessWidget {', 'class ContainerIcon extends StatelessWidget {', promo, 'delivery promo')

book_card = r'''class BookCard extends StatelessWidget {
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
          BoxShadow(color: Color(0x0B0F172A), blurRadius: 18, offset: Offset(0, 7)),
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
                            favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
                      child: _Badge(text: '-${book.discountPercent}%', color: AppColors.danger),
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
                    style: const TextStyle(fontWeight: FontWeight.w900, height: 1.15, fontSize: 14.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        book.inStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 14,
                        color: book.inStock ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          book.inStock ? '${book.stock} dona mavjud' : 'Hozircha mavjud emas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: book.inStock ? AppColors.success : AppColors.danger,
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
                      style: const TextStyle(color: AppColors.muted, decoration: TextDecoration.lineThrough, fontSize: 10.5),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          won(book.currentPrice),
                          style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 16.5),
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
                                    ..showSnackBar(SnackBar(content: Text('${book.title} savatga qo‘shildi ✅'), duration: const Duration(milliseconds: 900)));
                                }
                              : null,
                          style: FilledButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(38, 38)),
                          child: const Icon(Icons.add_shopping_cart_rounded, size: 18),
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
}'''
text = replace_between(text, 'class BookCard extends StatelessWidget {', 'class _BookCover extends StatelessWidget {', book_card, 'book card')

book_detail = r'''class BookDetailPage extends StatelessWidget {
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
      return const Scaffold(body: SafeArea(child: Center(child: Text('Kitob topilmadi'))));
    }
    final b = book;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitob haqida'),
        actions: [
          IconButton.filledTonal(
            onPressed: () => state.toggleFavorite(b),
            tooltip: 'Sevimlilar',
            icon: Icon(state.isFavorite(b) ? Icons.favorite_rounded : Icons.favorite_border_rounded),
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
              boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 28, offset: Offset(0, 14))],
            ),
            clipBehavior: Clip.antiAlias,
            child: _BookCover(book: b),
          );
          final info = _BookDetailInfo(book: b);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(desktop ? 32 : 18, 10, desktop ? 32 : 18, 125),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [cover, const SizedBox(width: 34), Expanded(child: info)],
                      )
                    : Column(children: [cover, const SizedBox(height: 26), info]),
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
            boxShadow: [BoxShadow(color: Color(0x120F172A), blurRadius: 20, offset: Offset(0, -5))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Narxi', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    if (b.isDiscounted)
                      Text(won(b.price), style: const TextStyle(fontSize: 10.5, color: AppColors.muted, decoration: TextDecoration.lineThrough)),
                    Text(won(b.currentPrice), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.navy)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: b.inStock
                    ? () {
                        state.addToCart(b);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Savatchaga qo‘shildi ✅')));
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
          Text(book.author, style: const TextStyle(fontSize: 16, color: AppColors.muted, fontWeight: FontWeight.w600)),
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
                background: book.inStock ? AppColors.successSoft : AppColors.dangerSoft,
                border: book.inStock ? const Color(0xFFCDEAD7) : const Color(0xFFFFCCD1),
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
                _DetailFact(icon: Icons.local_shipping_outlined, title: 'Yetkazish', value: '1–3 ish kuni'),
                SizedBox(width: 8),
                _DetailFact(icon: Icons.payments_outlined, title: '택배', value: '₩4,000'),
                SizedBox(width: 8),
                _DetailFact(icon: Icons.card_giftcard_outlined, title: '4+ kitob', value: 'Bepul'),
              ],
            ),
          ),
          if (book.description.isNotEmpty && book.description != 'Ma’lumot kiritilmagan.') ...[
            const SizedBox(height: 22),
            const AppSectionHeader(title: 'Kitob haqida', icon: Icons.notes_rounded),
            const SizedBox(height: 10),
            Text(book.description, style: const TextStyle(height: 1.65, fontSize: 15, color: AppColors.text)),
          ],
        ],
      );
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.navy),
            const SizedBox(height: 5),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}'''
text = replace_between(text, 'class BookDetailPage extends StatelessWidget {', 'class FavoritesPage extends StatelessWidget {', book_detail, 'book detail')

favorites = r'''class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final books = state.books.where((b) => b.isActive && state.isFavorite(b)).toList();
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
                    trailing: AppInfoPill(icon: Icons.favorite_rounded, label: '${books.length} ta', foreground: AppColors.danger, background: AppColors.dangerSoft, border: const Color(0xFFFFCCD1)),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final count = constraints.maxWidth >= 1100 ? 5 : constraints.maxWidth >= 850 ? 4 : constraints.maxWidth >= 600 ? 3 : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: books.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: count,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: constraints.maxWidth < 450 ? .57 : .62,
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
}'''
text = replace_between(text, 'class FavoritesPage extends StatelessWidget {', 'class CartPage extends StatelessWidget {', favorites, 'favorites page')

cart = r'''class CartPage extends StatelessWidget {
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
                    icon: state.cartCount >= 4 ? Icons.card_giftcard_rounded : Icons.local_shipping_outlined,
                    label: state.cartCount >= 4 ? 'Yetkazish bepul' : '4+ kitobda bepul',
                    foreground: state.cartCount >= 4 ? AppColors.success : AppColors.navy,
                    background: state.cartCount >= 4 ? AppColors.successSoft : AppColors.surfaceSoft,
                    border: state.cartCount >= 4 ? const Color(0xFFCDEAD7) : AppColors.border,
                  ),
                ),
                const SizedBox(height: 12),
                ...lines.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppSurface(
                        padding: const EdgeInsets.all(11),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              height: 100,
                              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _BookCover(book: line.book)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, height: 1.2)),
                                  const SizedBox(height: 5),
                                  Text(won(line.book.currentPrice), style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _QtyButton(icon: Icons.remove, onTap: () => state.decrementCart(line.book)),
                                      SizedBox(width: 42, child: Text('${line.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                                      _QtyButton(icon: Icons.add, onTap: line.quantity < line.book.stock ? () => state.addToCart(line.book) : null),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(won(line.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                const SizedBox(height: 30),
                                IconButton(
                                  onPressed: () => state.removeFromCart(line.book),
                                  tooltip: 'Olib tashlash',
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
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
                  boxShadow: [BoxShadow(color: Color(0x120F172A), blurRadius: 20, offset: Offset(0, -5))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Kitoblar jami', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(won(state.cartSubtotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21, color: AppColors.navy)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(state.cartCount >= 4 ? Icons.check_circle_rounded : Icons.local_shipping_outlined, size: 16, color: state.cartCount >= 4 ? AppColors.success : AppColors.muted),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            state.cartCount >= 4 ? 'Yetkazib berish siz uchun bepul' : '택배 ₩4,000 • 4+ kitobda bepul',
                            style: TextStyle(color: state.cartCount >= 4 ? AppColors.success : AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage())),
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
}'''
text = replace_between(text, 'class CartPage extends StatelessWidget {', 'class _QtyButton extends StatelessWidget {', cart, 'cart page')

checkout_header = r'''class _CheckoutStepHeader extends StatelessWidget {
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
              boxShadow: const [BoxShadow(color: Color(0x1610213D), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      );
}'''
text = replace_between(text, 'class _CheckoutStepHeader extends StatelessWidget {', 'class _PaymentCard extends StatelessWidget {', checkout_header, 'checkout step header')

payment_card = r'''class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.onCopy});
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFFBF1), Color(0xFFFFF2D2)]),
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
                Text('To‘lov rekvizitlari', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppState.bankName, style: TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      SizedBox(height: 3),
                      SelectableText(AppState.bankAccount, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: .5, color: AppColors.navy)),
                      SizedBox(height: 3),
                      Text(AppState.bankOwner, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(onPressed: onCopy, icon: const Icon(Icons.copy_rounded, size: 17), label: const Text('Nusxalash')),
              ],
            ),
          ],
        ),
      );
}'''
text = replace_between(text, 'class _PaymentCard extends StatelessWidget {', 'Widget _priceRow(', payment_card, 'payment card')

profile_orders = r'''class ProfilePage extends StatelessWidget {
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
              gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navy2]),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x2510213D), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Row(
              children: [
                const MuhajeerLogoCircle(size: 68),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.trim().isEmpty ? 'Muhajeer Books mijoz' : name.trim(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(phone.trim().isEmpty ? 'Yaxshi kitob — yaxshi hayot!' : phone, style: const TextStyle(color: Color(0xFFDCE5F2), fontSize: 12.5)),
                      const SizedBox(height: 9),
                      AppInfoPill(
                        icon: state.isOnlineBackend ? Icons.cloud_done_rounded : Icons.save_rounded,
                        label: state.isOnlineBackend ? 'Onlayn hisob' : 'Qurilmada saqlanadi',
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
          const AppSectionHeader(title: 'Hisob va xizmatlar', subtitle: 'Buyurtmalar va do‘kon boshqaruvi'),
          const SizedBox(height: 10),
          AppSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  minTileHeight: 68,
                  leading: const _ProfileIcon(icon: Icons.receipt_long_outlined),
                  title: const Text('Mening buyurtmalarim', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(phone.isEmpty ? 'Buyurtma berganingizdan keyin ko‘rinadi' : 'Holatini kuzatish va tarixni ko‘rish'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersPage())),
                ),
                const Divider(),
                ListTile(
                  minTileHeight: 68,
                  leading: _ProfileIcon(icon: state.isOnlineBackend ? Icons.cloud_done_outlined : Icons.save_outlined),
                  title: const Text('Ma’lumotlar holati', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(state.isOnlineBackend ? 'Barcha qurilmalarda sinxron ishlaydi' : 'Hozir shu qurilmada saqlanadi'),
                ),
                const Divider(),
                ListTile(
                  minTileHeight: 68,
                  leading: const _ProfileIcon(icon: Icons.admin_panel_settings_outlined),
                  title: const Text('Admin paneli', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Kitoblar, ombor, chegirma va buyurtmalar'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminGatePage())),
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
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.muted),
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
        decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
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
          IconButton(onPressed: () => setState(_reload), icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<ShopOrder>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
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
                              Text('Buyurtma № ${order.id}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 3),
                              Text(DateFormat('yyyy.MM.dd • HH:mm').format(order.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        _OrderStatusChip(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _OrderProgress(status: order.status),
                    const SizedBox(height: 14),
                    ...order.items.take(4).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_stories_outlined, size: 15, color: AppColors.muted),
                              const SizedBox(width: 7),
                              Expanded(child: Text('${item['title']} × ${item['quantity']}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        )),
                    if (order.items.length > 4) Text('+ yana ${order.items.length - 4} ta', style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                    if (order.hasPaymentProof) ...[
                      const SizedBox(height: 8),
                      const AppInfoPill(icon: Icons.receipt_rounded, label: 'To‘lov cheki yuborilgan', foreground: AppColors.success, background: AppColors.successSoft, border: Color(0xFFCDEAD7)),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        const Text('Jami', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(won(order.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.navy)),
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
      return const AppInfoPill(icon: Icons.cancel_rounded, label: 'Buyurtma bekor qilingan', foreground: AppColors.danger, background: AppColors.dangerSoft, border: Color(0xFFFFCCD1));
    }
    final level = switch (status) {
      'accepted' || 'paid' => 1,
      'shipping' => 2,
      'done' => 3,
      _ => 0,
    };
    const labels = ['Yuborildi', 'Qabul qilindi', 'Jo‘natildi', 'Yakunlandi'];
    const icons = [Icons.outbox_rounded, Icons.inventory_2_rounded, Icons.local_shipping_rounded, Icons.task_alt_rounded];
    return Row(
      children: List.generate(labels.length, (i) {
        final done = i <= level;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0) Expanded(child: Container(height: 2, color: i <= level ? AppColors.success : AppColors.border)),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: done ? AppColors.success : AppColors.surfaceSoft, shape: BoxShape.circle, border: Border.all(color: done ? AppColors.success : AppColors.border)),
                    child: Icon(icons[i], size: 15, color: done ? Colors.white : AppColors.muted),
                  ),
                  if (i < labels.length - 1) Expanded(child: Container(height: 2, color: i < level ? AppColors.success : AppColors.border)),
                ],
              ),
              const SizedBox(height: 5),
              Text(labels[i], textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 9.5, fontWeight: done ? FontWeight.w800 : FontWeight.w600, color: done ? AppColors.text : AppColors.muted)),
            ],
          ),
        );
      }),
    );
  }
}'''
text = replace_between(text, 'class ProfilePage extends StatelessWidget {', 'class _OrderStatusChip extends StatelessWidget {', profile_orders, 'profile and orders')

p.write_text(text, encoding='utf-8')


# -------------------------
# ADMIN
# -------------------------
p = Path('lib/admin_ui.dart')
text = p.read_text(encoding='utf-8')
if "import 'design_system.dart';" not in text:
    text = text.replace("import 'brand.dart';\n", "import 'brand.dart';\nimport 'design_system.dart';\n", 1)

admin_gate = r'''class AdminGatePage extends StatefulWidget {
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
    setState(() { loading = true; error = null; });
    try {
      final api = _AdminApi(value);
      if (!await api.verify()) {
        if (mounted) setState(() => error = 'Admin kodi noto‘g‘ri.');
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboardPage(secret: value)));
    } catch (_) {
      if (mounted) setState(() => error = 'Kirishda xatolik. Internetni tekshiring.');
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
                    Text('Muhajeer Books Admin', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
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
                          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      AppInfoPill(icon: Icons.error_outline_rounded, label: error!, foreground: AppColors.danger, background: AppColors.dangerSoft, border: const Color(0xFFFFCCD1)),
                    ],
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: loading ? null : _login,
                        icon: loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.login_rounded),
                        label: Text(loading ? 'Tekshirilmoqda...' : 'Boshqaruv paneliga kirish'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 15, color: AppColors.success),
                        SizedBox(width: 5),
                        Text('Himoyalangan admin kirishi', style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
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
}'''
text = replace_between(text, 'class AdminGatePage extends StatefulWidget {', 'class AdminDashboardPage extends StatefulWidget {', admin_gate, 'admin gate')

admin_dashboard = r'''class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.secret});
  final String secret;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int tab = 0;
  late final _AdminApi api;

  static const titles = ['Boshqaruv markazi', 'Kitoblar', 'Ombor', 'Buyurtmalar', 'Chegirmalar'];
  static const icons = [Icons.dashboard_rounded, Icons.menu_book_rounded, Icons.inventory_2_rounded, Icons.receipt_long_rounded, Icons.percent_rounded];

  @override
  void initState() {
    super.initState();
    api = _AdminApi(widget.secret);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OverviewAdmin(api: api),
      _BooksAdmin(api: api),
      _InventoryAdmin(api: api),
      _OrdersAdmin(api: api),
      _DiscountAdmin(api: api),
    ];
    const railDestinations = [
      NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: Text('Bosh sahifa')),
      NavigationRailDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: Text('Kitoblar')),
      NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: Text('Ombor')),
      NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: Text('Buyurtmalar')),
      NavigationRailDestination(icon: Icon(Icons.percent_rounded), label: Text('Chegirma')),
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
                  const MuhajeerLogoBadge(size: 36, radius: 10, showShadow: false),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titles[tab], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const Text('Muhajeer Books boshqaruvi', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 14),
                child: AppInfoPill(icon: Icons.cloud_done_rounded, label: 'Onlayn', foreground: AppColors.success, background: AppColors.successSoft, border: Color(0xFFCDEAD7)),
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
                      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
                      groupAlignment: -.72,
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 20),
                        child: extended
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MuhajeerLogoBadge(size: 46, radius: 13, showShadow: false),
                                  SizedBox(width: 10),
                                  Text('Muhajeer\nBooks', style: TextStyle(fontWeight: FontWeight.w900, height: 1.05)),
                                ],
                              )
                            : const MuhajeerLogoBadge(size: 46, radius: 13, showShadow: false),
                      ),
                      destinations: railDestinations,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: pages[tab]),
                  ],
                )
              : pages[tab],
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (v) => setState(() => tab = v),
                  labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                  destinations: List.generate(titles.length, (i) => NavigationDestination(icon: Icon(icons[i]), label: i == 0 ? 'Bosh' : titles[i])),
                ),
        );
      },
    );
  }
}'''
text = replace_between(text, 'class AdminDashboardPage extends StatefulWidget {', 'class _OverviewData {', admin_dashboard, 'admin dashboard')

overview = r'''class _OverviewAdmin extends StatefulWidget {
  const _OverviewAdmin({required this.api});
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

  Future<_OverviewData> load() async => _OverviewData(await widget.api.books(), await widget.api.orders());
  void reload() => setState(() => future = load());

  @override
  Widget build(BuildContext context) => FutureBuilder<_OverviewData>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return Center(
              child: AppSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.danger),
                    const SizedBox(height: 10),
                    const Text('Ma’lumotni yuklab bo‘lmadi', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(onPressed: reload, icon: const Icon(Icons.refresh_rounded), label: const Text('Qayta urinish')),
                  ],
                ),
              ),
            );
          }
          final data = snap.data ?? const _OverviewData([], []);
          final books = data.books;
          final orders = data.orders;
          final now = DateTime.now();
          final todayOrders = orders.where((o) => o.createdAt.year == now.year && o.createdAt.month == now.month && o.createdAt.day == now.day).length;
          final newOrders = orders.where((o) => o.status == 'new').length;
          final proofOrders = orders.where((o) => o.status == 'new' && o.hasPaymentProof).length;
          final activeRevenue = orders.where((o) => ['accepted', 'paid', 'shipping', 'done'].contains(o.status)).fold<int>(0, (sum, o) => sum + o.total);
          final completedRevenue = orders.where((o) => o.status == 'done').fold<int>(0, (sum, o) => sum + o.total);
          final totalStock = books.fold<int>(0, (sum, b) => sum + b.stock);
          final lowStock = books.where((b) => b.stock <= 2).toList()..sort((a, b) => a.stock.compareTo(b.stock));
          final recent = orders.take(5).toList();

          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                AppPageHeading(
                  title: 'Boshqaruv markazi',
                  subtitle: 'Savdo, buyurtmalar va ombor holati real vaqtga yaqin ko‘rinishda.',
                  trailing: IconButton.filledTonal(onPressed: reload, tooltip: 'Yangilash', icon: const Icon(Icons.refresh_rounded)),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, c) {
                    final cardWidth = c.maxWidth >= 1200 ? (c.maxWidth - 36) / 4 : c.maxWidth >= 760 ? (c.maxWidth - 24) / 3 : c.maxWidth >= 480 ? (c.maxWidth - 12) / 2 : c.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(width: cardWidth, child: AppMetricCard(icon: Icons.new_releases_outlined, label: 'Yangi buyurtmalar', value: '$newOrders', accent: AppColors.orange, note: proofOrders > 0 ? '$proofOrders ta chek kutilmoqda' : 'Tekshirish navbati')),
                        SizedBox(width: cardWidth, child: AppMetricCard(icon: Icons.today_outlined, label: 'Bugungi buyurtma', value: '$todayOrders', accent: AppColors.info, note: DateFormat('yyyy.MM.dd').format(now))),
                        SizedBox(width: cardWidth, child: AppMetricCard(icon: Icons.inventory_2_outlined, label: 'Ombordagi dona', value: '$totalStock', accent: const Color(0xFF6B5DD3), note: '${books.length} xil kitob')),
                        SizedBox(width: cardWidth, child: AppMetricCard(icon: Icons.payments_outlined, label: 'Faol savdo', value: _won(activeRevenue), accent: AppColors.success, note: 'Qabul qilingan buyurtmalar')),
                        SizedBox(width: cardWidth, child: AppMetricCard(icon: Icons.task_alt_rounded, label: 'Yakunlangan savdo', value: _won(completedRevenue), accent: AppColors.navy, note: 'Yakunlangan buyurtmalar')),
                        SizedBox(width: cardWidth, child: AppMetricCard(icon: Icons.warning_amber_rounded, label: 'Kam qolgan kitob', value: '${lowStock.length}', accent: AppColors.warning, note: '2 dona yoki undan kam')),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 900;
                    final lowCard = AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSectionHeader(title: 'Ombor nazorati', subtitle: 'Eng avval e’tibor beriladigan qoldiqlar', icon: Icons.warning_amber_rounded, trailing: AppInfoPill(label: '${lowStock.length} ta')),
                          const SizedBox(height: 12),
                          if (lowStock.isEmpty)
                            const AppInfoPill(icon: Icons.check_circle_rounded, label: 'Hamma qoldiq yaxshi', foreground: AppColors.success, background: AppColors.successSoft, border: Color(0xFFCDEAD7))
                          else
                            ...lowStock.take(6).map((b) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: _AdminBookThumb(url: b.imageUrl),
                                  title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text(_won(b.currentPrice), style: const TextStyle(fontSize: 11.5)),
                                  trailing: AppInfoPill(label: '${b.stock} dona', foreground: b.stock == 0 ? AppColors.danger : AppColors.warning, background: b.stock == 0 ? AppColors.dangerSoft : AppColors.warningSoft, border: b.stock == 0 ? const Color(0xFFFFCCD1) : const Color(0xFFFFDCA0)),
                                )),
                        ],
                      ),
                    );
                    final recentCard = AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSectionHeader(title: 'So‘nggi buyurtmalar', subtitle: 'Yaqinda kelgan mijoz buyurtmalari', icon: Icons.receipt_long_outlined, trailing: AppInfoPill(label: '${orders.length} ta')),
                          const SizedBox(height: 12),
                          if (recent.isEmpty)
                            const Text('Hozircha buyurtma yo‘q.', style: TextStyle(color: AppColors.muted))
                          else
                            ...recent.map((o) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: const Icon(Icons.person_outline_rounded, size: 19)),
                                  title: Text(o.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text(DateFormat('MM.dd • HH:mm').format(o.createdAt), style: const TextStyle(fontSize: 11.5)),
                                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [_AdminOrderStatusChip(status: o.status), const SizedBox(height: 3), Text(_won(o.total), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))]),
                                )),
                        ],
                      ),
                    );
                    if (!wide) return Column(children: [recentCard, const SizedBox(height: 12), lowCard]);
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: recentCard), const SizedBox(width: 12), Expanded(child: lowCard)]);
                  },
                ),
              ],
            ),
          );
        },
      );
}'''
text = replace_between(text, 'class _OverviewAdmin extends StatefulWidget {', 'class _AdminStatCard extends StatelessWidget {', overview, 'overview')

admin_status = r'''class _AdminOrderStatusChip extends StatelessWidget {
  const _AdminOrderStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, border, icon) = switch (status) {
      'accepted' => ('Qabul qilindi', AppColors.success, AppColors.successSoft, const Color(0xFFCDEAD7), Icons.inventory_2_rounded),
      'paid' => ('To‘landi', AppColors.info, AppColors.infoSoft, const Color(0xFFCFE0FA), Icons.verified_rounded),
      'shipping' => ('Jo‘natildi', AppColors.orange, const Color(0xFFFFF2E3), const Color(0xFFFFD4A3), Icons.local_shipping_rounded),
      'done' => ('Yakunlandi', AppColors.success, AppColors.successSoft, const Color(0xFFCDEAD7), Icons.task_alt_rounded),
      'cancelled' => ('Bekor', AppColors.danger, AppColors.dangerSoft, const Color(0xFFFFCCD1), Icons.cancel_rounded),
      _ => ('Yangi', AppColors.navy, AppColors.surfaceSoft, AppColors.border, Icons.new_releases_rounded),
    };
    return AppInfoPill(icon: icon, label: label, foreground: fg, background: bg, border: border);
  }
}'''
text = replace_between(text, 'class _AdminOrderStatusChip extends StatelessWidget {', 'class _PaymentProofPanel extends StatelessWidget {', admin_status, 'admin order status chip')

discount = r'''class _DiscountAdmin extends StatefulWidget {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1 dan 99 gacha foiz kiriting.')));
      return;
    }
    setState(() => loading = true);
    try {
      await widget.api.applyDiscount(p);
      await context.read<AppState>().refreshBooks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$p% chegirma qo‘llandi ✅')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> clear() async {
    setState(() => loading = true);
    try {
      await widget.api.clearDiscounts();
      await context.read<AppState>().refreshBooks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barcha chegirmalar bekor qilindi.')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const AppPageHeading(title: 'Chegirma boshqaruvi', subtitle: 'Aksiya foizini bir necha soniyada barcha kitoblarga qo‘llang.'),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 760;
            final editor = AppSurface(
              shadow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(title: 'Yangi aksiya', subtitle: 'Foizni tanlang yoki qo‘lda kiriting', icon: Icons.sell_outlined),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [10, 15, 20, 25, 30].map((v) => ActionChip(label: Text('$v%'), onPressed: loading ? null : () => setState(() => percent.text = '$v'))).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: percent,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Chegirma foizi', prefixIcon: Icon(Icons.percent_rounded), suffixText: '%'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: loading ? null : apply, icon: const Icon(Icons.campaign_outlined), label: const Text('Chegirmani qo‘llash'))),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: loading ? null : clear, icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Barcha chegirmalarni bekor qilish'))),
                ],
              ),
            );
            final guide = AppSurface(
              backgroundColor: AppColors.surfaceSoft,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionHeader(title: 'Aksiya tavsiyasi', subtitle: 'Narxni tushunarli va ishonchli ko‘rsating', icon: Icons.tips_and_updates_outlined),
                  SizedBox(height: 14),
                  _DiscountTip(icon: Icons.visibility_outlined, title: 'Eski narx ko‘rinadi', text: 'Chegirma yoqilganda asl narx ustidan chiziq bilan ko‘rsatiladi.'),
                  SizedBox(height: 10),
                  _DiscountTip(icon: Icons.calculate_outlined, title: 'Yangi narx avtomatik', text: 'Mijozga chegirmadan keyingi yakuniy narx ko‘rsatiladi.'),
                  SizedBox(height: 10),
                  _DiscountTip(icon: Icons.restart_alt_rounded, title: 'Bir tugmada bekor', text: 'Aksiya tugaganda barcha chegirmalarni birdan o‘chira olasiz.'),
                ],
              ),
            );
            return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: editor), const SizedBox(width: 14), Expanded(child: guide)]) : Column(children: [editor, const SizedBox(height: 14), guide]);
          },
        ),
      ],
    );
  }
}

class _DiscountTip extends StatelessWidget {
  const _DiscountTip({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Icon(icon, size: 19, color: AppColors.navy)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4))])),
        ],
      );
}'''
start = text.find('class _DiscountAdmin extends StatefulWidget {')
if start < 0:
    raise SystemExit('discount admin start not found')
text = text[:start] + discount.rstrip() + '\n'
p.write_text(text, encoding='utf-8')


# -------------------------
# VERSION
# -------------------------
p = Path('pubspec.yaml')
text = p.read_text(encoding='utf-8')
text = text.replace('version: 2.1.0+3', 'version: 2.2.0+4')
p.write_text(text, encoding='utf-8')

print('Premium polish applied successfully.')
