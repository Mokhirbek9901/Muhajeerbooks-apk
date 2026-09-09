from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / 'lib' / 'store_ui.dart'
DESIGN = ROOT / 'lib' / 'design_system.dart'


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    out, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 replacement, got {count}')
    return out


store = STORE.read_text(encoding='utf-8')

store_shell = r'''class _StoreShellState extends State<StoreShell> {
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
                [
                  (notice['title'] ?? 'Buyurtma yangilandi').toString(),
                  (notice['message'] ?? '').toString(),
                ].where((value) => value.trim().isNotEmpty).join('\n'),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
      });
    }
    const pages = [
      HomePage(),
      CategoriesPage(),
      CartPage(),
      FavoritesPage(),
      ProfilePage(),
    ];
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: UzbekCustomerColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: UzbekCustomerColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26082F49),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UzbekAtlasBand(height: 5),
              NavigationBar(
                height: 68,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: UzbekCustomerColors.goldSoft,
                selectedIndex: index,
                onDestinationSelected: (value) => setState(() => index = value),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(
                      Icons.home_rounded,
                      color: UzbekCustomerColors.teal,
                    ),
                    label: 'Bosh sahifa',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.grid_view_rounded),
                    selectedIcon: Icon(
                      Icons.grid_view_rounded,
                      color: UzbekCustomerColors.teal,
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
                        color: UzbekCustomerColors.teal,
                      ),
                    ),
                    label: 'Savatcha',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.favorite_border_rounded),
                    selectedIcon: Icon(
                      Icons.favorite_rounded,
                      color: UzbekCustomerColors.teal,
                    ),
                    label: 'Sevimlilar',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(
                      Icons.person_rounded,
                      color: UzbekCustomerColors.teal,
                    ),
                    label: 'Profil',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoriesPage'''

store = replace_once(
    store,
    r'class _StoreShellState extends State<StoreShell> \{.*?\n\}\n\nclass CategoriesPage',
    store_shell,
    'store shell',
)

store_header = r'''class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return UzbekPatternPanel(
      strongPattern: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(12, 11, 11, 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  UzbekCustomerColors.navy,
                  UzbekCustomerColors.teal,
                ],
              ),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: UzbekCustomerColors.gold),
            ),
            child: const MuhajeerLogoBadge(size: 52, radius: 17),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 3),
                const Text(
                  'Koreyadagi O’zbek kitobxonlari uchun',
                  style: TextStyle(
                    color: UzbekCustomerColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                const SizedBox(width: 94, child: UzbekAtlasBand(height: 4)),
              ],
            ),
          ),
          Badge(
            isLabelVisible: state.unreadCustomerNoticeCount > 0,
            label: Text('${state.unreadCustomerNoticeCount}'),
            child: Container(
              decoration: BoxDecoration(
                color: UzbekCustomerColors.goldSoft,
                shape: BoxShape.circle,
                border: Border.all(color: UzbekCustomerColors.gold),
              ),
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
          ),
        ],
      ),
    );
  }
}

class _DeliveryPromoCard'''

store = replace_once(
    store,
    r'class _StoreHeader extends StatelessWidget \{.*?\n\}\n\nclass _DeliveryPromoCard',
    store_header,
    'store header',
)

book_card = r'''class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final favorite = context.select<AppState, bool>((s) => s.isFavorite(book));
    final state = context.read<AppState>();
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [UzbekCustomerColors.surface, UzbekCustomerColors.ivory],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: UzbekCustomerColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18082F49),
            blurRadius: 22,
            offset: Offset(0, 9),
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(21),
                    bottom: Radius.circular(13),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _BookCover(book: book),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: UzbekCustomerColors.gold.withValues(
                                  alpha: .34,
                                ),
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(21),
                                bottom: Radius.circular(13),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Material(
                          color: UzbekCustomerColors.surface.withValues(
                            alpha: .94,
                          ),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => state.toggleFavorite(book),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: favorite
                                    ? AppColors.danger
                                    : UzbekCustomerColors.navy,
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
                          child: _Badge(
                            text: 'Tavsiya',
                            color: UzbekCustomerColors.teal,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: UzbekAccentLine(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: UzbekCustomerColors.navy,
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
                      color: UzbekCustomerColors.textMuted,
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
                  const SizedBox(height: 7),
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
                            color: UzbekCustomerColors.navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
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
                            minimumSize: const Size(40, 40),
                            backgroundColor: UzbekCustomerColors.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                color: UzbekCustomerColors.gold,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 18,
                            color: UzbekCustomerColors.goldSoft,
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

class _BookCover'''

store = replace_once(
    store,
    r'class BookCard extends StatelessWidget \{.*?\n\}\n\nclass _BookCover',
    book_card,
    'book card',
)

STORE.write_text(store, encoding='utf-8')

design = DESIGN.read_text(encoding='utf-8')
colors = r'''abstract final class AppColors {
  static const navy = Color(0xFF082F49);
  static const navy2 = Color(0xFF0C4A6E);
  static const orange = Color(0xFFB7791F);
  static const gold = Color(0xFFD9A441);
  static const background = Color(0xFFF4EBDD);
  static const surface = Color(0xFFFFFCF6);
  static const surfaceSoft = Color(0xFFFFF7E7);
  static const border = Color(0xFFD8C3A3);
  static const text = Color(0xFF172A38);
  static const muted = Color(0xFF74695D);
  static const success = Color(0xFF2E7D5B);
  static const successSoft = Color(0xFFE8F3EC);
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFF8E7BE);
  static const danger = Color(0xFFB85042);
  static const dangerSoft = Color(0xFFF8E8E4);
  static const info = Color(0xFF0F766E);
  static const infoSoft = Color(0xFFE5F4F1);
}'''

design = replace_once(
    design,
    r'abstract final class AppColors \{.*?\n\}',
    colors,
    'app colors',
)
design = design.replace('seedColor: AppColors.orange,', 'seedColor: AppColors.navy,')
design = design.replace('static const large = 22.0;', 'static const large = 24.0;')
design = design.replace('static const xl = 28.0;', 'static const xl = 30.0;')
design = design.replace('indicatorColor: const Color(0xFFFFE8CF),', 'indicatorColor: AppColors.warningSoft,')
design = design.replace('indicatorColor: Color(0xFFFFE8CF),', 'indicatorColor: AppColors.warningSoft,')
design = design.replace('selectedColor: const Color(0xFFFFE8CF),', 'selectedColor: AppColors.warningSoft,')
design = design.replace('color: const Color(0xFFFFF1E2),', 'color: AppColors.warningSoft,')
design = design.replace('child: Icon(icon, color: AppColors.orange, size: 20),', 'child: Icon(icon, color: AppColors.navy, size: 20),')
design = design.replace('color: AppColors.orange,\n      ),', 'color: AppColors.gold,\n      ),')
DESIGN.write_text(design, encoding='utf-8')

print('Uzbek customer redesign applied without changing customer-facing copy.')
