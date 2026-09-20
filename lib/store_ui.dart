import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_ui.dart';
import 'app_state.dart';
import 'brand.dart';
import 'book_links.dart';
import 'book_story_page.dart';
import 'book_share_platform.dart';
import 'catalog_resume.dart';
import 'book_image_viewer.dart';
import 'design_system.dart';
import 'uzbek_customer_style.dart';

const _navy = UzbekCustomerColors.navy;
const _orange = UzbekCustomerColors.goldDeep;
const _gold = UzbekCustomerColors.gold;
const _cream = UzbekCustomerColors.ivory;
const _green = UzbekCustomerColors.success;

final _money = NumberFormat('#,###', 'en_US');
String won(int value) => '₩${_money.format(value)}';

final Map<String, double> _scrollMemory = <String, double>{};
final Future<SharedPreferences> _uiPrefs = SharedPreferences.getInstance();

/// iPhone/Safari browser-back yoki web sahifa qayta tiklanganda foydalanuvchini
/// ro‘yxat boshiga tashlamaydi. Xotirada darhol, SharedPreferences'da esa
/// reload'lar orasida scroll joyini saqlaydi.
class _PersistentScrollController extends ScrollController {
  _PersistentScrollController(this.storageKey)
    : super(
        initialScrollOffset: _scrollMemory[storageKey] ?? 0,
        keepScrollOffset: false,
      ) {
    addListener(_capture);
    CatalogResume.instance.addListener(_resetAfterAbsence);
    unawaited(_loadSaved());
  }

  final String storageKey;
  Timer? _saveTimer;
  double? _pendingRestore;
  int _restoreAttempts = 0;
  bool _restoring = false;
  bool _userMoved = false;
  bool _disposed = false;

  void _resetAfterAbsence() {
    _saveTimer?.cancel();
    _pendingRestore = null;
    _userMoved = true;
    _scrollMemory.clear();
    if (hasClients) {
      _restoring = true;
      for (final position in positions) {
        position.jumpTo(0);
      }
      _restoring = false;
    }
  }

  void _capture() {
    if (_disposed || _restoring || !hasClients) return;
    final value = offset < 0 ? 0.0 : offset;
    _userMoved = true;
    _scrollMemory[storageKey] = value;
  }

  void _persistWhenIdle() {
    if (_disposed || !hasClients) return;
    if (positions.any((p) => p.isScrollingNotifier.value)) return;
    final latest = _scrollMemory[storageKey];
    if (latest != null) unawaited(_write(latest));
  }

  Future<void> _write(double value) async {
    try {
      final prefs = await _uiPrefs;
      await prefs.setDouble('scroll:$storageKey', value);
    } catch (_) {
      // Scroll xotirasi asosiy ilovani bloklamaydi.
    }
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await _uiPrefs;
      final saved = prefs.getDouble('scroll:$storageKey');
      if (_disposed || _userMoved || saved == null || saved <= 0) return;
      _scrollMemory[storageKey] = saved;
      _pendingRestore = saved;
      _scheduleRestore();
    } catch (_) {
      // Browser storage ishlamasa in-memory holatning o‘zi ishlaydi.
    }
  }

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    position.isScrollingNotifier.addListener(_persistWhenIdle);
    _scheduleRestore();
  }

  @override
  void detach(ScrollPosition position) {
    position.isScrollingNotifier.removeListener(_persistWhenIdle);
    super.detach(position);
  }

  void _scheduleRestore() {
    if (_disposed || _pendingRestore == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _pendingRestore == null) return;
      if (!hasClients || !position.hasContentDimensions) {
        _retryRestore();
        return;
      }

      final target = _pendingRestore!;
      final max = position.maxScrollExtent;
      // Katalog hali fon rejimida kelayotgan bo‘lsa, kontent yetarlicha
      // uzunlashguncha tepaga clamp qilib yubormasdan biroz kutamiz.
      if (max + 4 < target && _restoreAttempts < 30) {
        _retryRestore();
        return;
      }

      _restoring = true;
      jumpTo(target.clamp(0.0, max).toDouble());
      _restoring = false;
      _pendingRestore = null;
      _restoreAttempts = 0;
    });
  }

  void _retryRestore() {
    if (_disposed || _pendingRestore == null || _restoreAttempts++ >= 30) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 100), _scheduleRestore);
  }

  @override
  void dispose() {
    CatalogResume.instance.removeListener(_resetAfterAbsence);
    _disposed = true;
    if (hasClients) {
      final value = offset < 0 ? 0.0 : offset;
      _scrollMemory[storageKey] = value;
      unawaited(_write(value));
    }
    removeListener(_capture);
    super.dispose();
  }
}

Future<void> _openBookDetail(BuildContext context, Book book) async {
  await Navigator.push<void>(
    context,
    muhajeerPageRoute<void>(
      settings: RouteSettings(name: 'mb:book:${book.id}'),
      builder: (_) => BookDetailPage(bookId: book.id),
    ),
  );
}

Future<void> _openTelegramRestock(BuildContext context, Book book) async {
  final telegramId = book.legacyId;
  if (telegramId == null || telegramId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bu kitob uchun Telegram xabari hali ulanmagan.'),
      ),
    );
    return;
  }

  final uri = Uri.parse(
    'https://t.me/muhajeerbooks_bot?start=restock_$telegramId',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted) return;
  if (!opened) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Telegram ochilmadi. @muhajeerbooks_bot orqali kirishingiz mumkin.',
        ),
      ),
    );
  }
}

bool _isSupportedCustomerPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length == 11 && digits.startsWith('010');
}

String isGyeongsanPickupAddress(String rawAddress, String deliveryType) {
  final value = rawAddress.trim();
  if (deliveryType == '경산 직접수령' && value.isEmpty) {
    return '경산 직접수령';
  }
  return value;
}

final ValueNotifier<int?> storefrontTabRequest = ValueNotifier<int?>(null);

class StoreShell extends StatefulWidget {
  const StoreShell({super.key});

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int index = 0;
  String? _lastPresentedNoticeId;

  @override
  void initState() {
    super.initState();
    storefrontTabRequest.addListener(_handleTabRequest);
  }

  void _handleTabRequest() {
    final requested = storefrontTabRequest.value;
    if (!mounted || requested == null || requested == index) return;
    setState(() => index = requested.clamp(0, 4));
  }

  @override
  void dispose() {
    storefrontTabRequest.removeListener(_handleTabRequest);
    super.dispose();
  }

  void showHome() {
    if (!mounted || index == 0) return;
    setState(() => index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<AppState, int>((s) => s.cartDisplayCount);
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
    final pages = [
      const HomePage(),
      const CategoriesPage(),
      CartPage(onContinueShopping: showHome),
      const FavoritesPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [UzbekCustomerColors.navy, UzbekCustomerColors.tealDark],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: UzbekCustomerColors.gold, width: 1.05),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33113D43),
              blurRadius: 24,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: NavigationBar(
          height: 72,
          backgroundColor: Colors.transparent,
          indicatorColor: UzbekCustomerColors.gold,
          selectedIndex: index,
          onDestinationSelected: (value) {
            storefrontTabRequest.value = value;
            if (value != index) setState(() => index = value);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: UzbekCustomerColors.navy,
              ),
              label: 'Bosh sahifa',
            ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(
                Icons.grid_view_rounded,
                color: UzbekCustomerColors.navy,
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
                  color: UzbekCustomerColors.navy,
                ),
              ),
              label: 'Savatcha',
            ),
            const NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(
                Icons.favorite_rounded,
                color: UzbekCustomerColors.navy,
              ),
              label: 'Sevimlilar',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: UzbekCustomerColors.navy,
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
    final categories =
        state.books
            .where((b) => b.isActive)
            .map(
              (b) =>
                  b.category.trim().isEmpty ? 'Boshqalar' : b.category.trim(),
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
            itemCount: categories.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, i) {
              final isPublishers = i == 0;
              final c = isPublishers ? 'Nashriyotlar' : categories[i - 1];
              final count = state.books
                  .where((b) => b.isActive && b.category == c)
                  .length;
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.push(
                  context,
                  muhajeerPageRoute(
                    settings: RouteSettings(
                      name: isPublishers ? 'mb:publishers' : 'mb:category:$c',
                    ),
                    builder: (_) => isPublishers
                        ? const PublishersPage()
                        : CategoryBrowsePage(category: c),
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
                              isPublishers
                                  ? '${bookPublishers(state.books).length} ta nashriyot'
                                  : '$count ta kitob',
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

class BookBundlesPage extends StatefulWidget {
  const BookBundlesPage({super.key});

  @override
  State<BookBundlesPage> createState() => _BookBundlesPageState();
}

class _BookBundlesPageState extends State<BookBundlesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AppState>().refreshBundles());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bundles = state.bundles;
    return Scaffold(
      appBar: AppBar(title: const Text('Kitob setlari')),
      body: RefreshIndicator(
        onRefresh: state.refreshBundles,
        child: bundles.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.auto_awesome_mosaic_rounded,
                      size: 58, color: AppColors.muted),
                  SizedBox(height: 14),
                  Text(
                    'Hozircha faol kitob seti yo‘q.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: bundles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final bundle = bundles[index];
                  final items = ((bundle['items'] as List?) ?? const [])
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                  var liveTotal = 0;
                  var available = true;
                  for (final item in items) {
                    final id = (item['book_id'] ?? '').toString();
                    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                    Book? book;
                    for (final candidate in state.books) {
                      if (candidate.id == id) {
                        book = candidate;
                        break;
                      }
                    }
                    if (book == null || book.stock < qty) {
                      available = false;
                    } else {
                      liveTotal += book.currentPrice * qty;
                    }
                  }
                  return AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: UzbekCustomerColors.goldSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_mosaic_rounded,
                                color: UzbekCustomerColors.navy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (bundle['title'] ?? 'Kitob seti').toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if ((bundle['description'] ?? '').toString().trim().isNotEmpty)
                                    Text(
                                      bundle['description'].toString(),
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.menu_book_rounded, size: 16),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      (item['title'] ?? 'Kitob').toString(),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text('×${(item['quantity'] as num?)?.toInt() ?? 1}'),
                                ],
                              ),
                            )),
                        const Divider(height: 24),
                        Builder(
                          builder: (context) {
                            final setPrice =
                                (bundle['price'] as num?)?.toInt() ?? liveTotal;
                            final saving =
                                (liveTotal - setPrice).clamp(0, liveTotal).toInt();
                            final percent = liveTotal > 0
                                ? ((saving * 100) / liveTotal).round()
                                : 0;
                            final deliveryIncluded =
                                bundle['delivery_included'] == true;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (saving > 0)
                                  Row(
                                    children: [
                                      Text(
                                        won(liveTotal),
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          decoration: TextDecoration.lineThrough,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AppInfoPill(
                                        icon: Icons.sell_rounded,
                                        label: '-$percent% • ${won(saving)} tejaysiz',
                                        foreground: AppColors.success,
                                        background: AppColors.successSoft,
                                      ),
                                    ],
                                  ),
                                if (saving > 0) const SizedBox(height: 7),
                                Row(
                                  children: [
                                    Text(
                                      won(setPrice),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      deliveryIncluded
                                          ? 'pochta bilan'
                                          : 'pochta alohida',
                                      style: TextStyle(
                                        color: deliveryIncluded
                                            ? AppColors.success
                                            : AppColors.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    FilledButton.icon(
                              onPressed: available
                                  ? () {
                                      final message = state.addBundleToCart(bundle);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(message)),
                                      );
                                    }
                                  : null,
                              icon: const Icon(Icons.add_shopping_cart_rounded),
                              label: Text(available ? 'Setni savatga' : 'To‘liq mavjud emas'),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class PublishersPage extends StatelessWidget {
  const PublishersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final books = context.watch<AppState>().books;
    final publishers = bookPublishers(books);
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(title: const Text('Nashriyotlar')),
      body: publishers.isEmpty
          ? const Center(child: Text('Hozircha nashriyotlar kiritilmagan.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: publishers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final name = publishers[index];
                final count = books
                    .where(
                      (b) =>
                          b.isActive &&
                          publisherKey(b.publisher) == publisherKey(name),
                    )
                    .length;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text(name),
                    subtitle: Text('$count ta kitob'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      muhajeerPageRoute(
                        settings: RouteSettings(name: 'mb:publisher:$name'),
                        builder: (_) =>
                            CategoryBrowsePage(category: name, publisher: name),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class CategoryBrowsePage extends StatelessWidget {
  const CategoryBrowsePage({super.key, required this.category, this.publisher});
  final String category;
  final String? publisher;

  @override
  Widget build(BuildContext context) {
    final books = context
        .watch<AppState>()
        .books
        .where(
          (b) =>
              b.isActive &&
              (publisher == null
                  ? b.category == category
                  : publisherKey(b.publisher) == publisherKey(publisher!)),
        )
        .toList();
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(category),
      ),
      body: books.isEmpty
          ? const Center(child: Text('Hozircha kitoblar mavjud emas.'))
          : _PersistentBookGrid(
              storageKey: 'browse:${publisher ?? category}',
              books: books,
            ),
    );
  }
}

class _PersistentBookGrid extends StatefulWidget {
  const _PersistentBookGrid({required this.storageKey, required this.books});

  final String storageKey;
  final List<Book> books;

  @override
  State<_PersistentBookGrid> createState() => _PersistentBookGridState();
}

class _PersistentBookGridState extends State<_PersistentBookGrid> {
  late final ScrollController _controller = _PersistentScrollController(
    widget.storageKey,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GridView.builder(
    controller: _controller,
    key: PageStorageKey<String>('grid:${widget.storageKey}'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    addAutomaticKeepAlives: false,
    addRepaintBoundaries: true,
    itemCount: widget.books.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: .57,
    ),
    itemBuilder: (_, i) => BookCard(
      book: widget.books[i],
      sharpCover: true,
    ),
  );
}

IconData _categoryIcon(String value) {
  if (value == 'Nashriyotlar') return Icons.business_outlined;
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

  final ScrollController _scrollController = _PersistentScrollController(
    'home',
  );
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchMissTimer;
  String _lastLoggedMiss = '';

  void _searchChanged(String value) {
    setState(() => query = value);
    _searchMissTimer?.cancel();
    final clean = value.trim();
    if (clean.length < 2) return;
    _searchMissTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _searchController.text.trim() != clean) return;
      final state = context.read<AppState>();
      final q = clean.toLowerCase();
      final found = state.books.any(
        (book) =>
            book.isActive &&
            (book.title.toLowerCase().contains(q) ||
                book.author.toLowerCase().contains(q) ||
                book.publisher.toLowerCase().contains(q) ||
                book.category.toLowerCase().contains(q)),
      );
      if (!found && _lastLoggedMiss != q) {
        _lastLoggedMiss = q;
        unawaited(state.recordSearchMiss(clean));
      }
    });
  }

  void _showAllBooks() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      query = '';
      category = 'Barchasi';
    });
  }

  @override
  void dispose() {
    _searchMissTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = context.select<
      AppState,
      ({int catalogRevision, bool loading, String? error})
    >(
      (s) => (
        catalogRevision: s.catalogRevision,
        loading: s.loading,
        error: s.error,
      ),
    );
    final state = context.read<AppState>();
    final categories = <String>{
      'Barchasi',
      'Nashriyotlar',
      'Kitob setlari',
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
          book.publisher.toLowerCase().contains(q) ||
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
          controller: _scrollController,
          key: const PageStorageKey<String>('muhajeer-home-scroll-v2'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              sliver: const SliverToBoxAdapter(child: _StoreHeader()),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
              sliver: SliverToBoxAdapter(
                child: RepaintBoundary(child: _DeliveryPromoCard()),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 5, 16, 5),
              sliver: SliverToBoxAdapter(child: _DiscountCountdownBanner()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 5),
              sliver: SliverToBoxAdapter(
                child: _QuickCategoryStrip(
                  categories: categories,
                  selected: category,
                  onSelected: (value) {
                    if (value == 'Nashriyotlar') {
                      Navigator.push(
                        context,
                        muhajeerPageRoute(
                          settings: const RouteSettings(name: 'mb:publishers'),
                          builder: (_) => const PublishersPage(),
                        ),
                      );
                    } else if (value == 'Kitob setlari') {
                      Navigator.push(
                        context,
                        muhajeerPageRoute(
                          settings: const RouteSettings(name: 'mb:bundles'),
                          builder: (_) => const BookBundlesPage(),
                        ),
                      );
                    } else {
                      setState(() => category = value);
                    }
                  },
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
                        controller: _searchController,
                        onChanged: _searchChanged,
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
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              UzbekCustomerColors.navy,
                              UzbekCustomerColors.tealDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: UzbekCustomerColors.gold),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22173F4A),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: UzbekCustomerColors.goldSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (query.trim().isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: UzbekCustomerColors.ivory,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: UzbekCustomerColors.gold),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '“${query.trim()}” bo‘yicha ${books.length} ta kitob topildi',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _showAllBooks,
                          icon: const Icon(Icons.apps_rounded),
                          label: const Text('Barcha kitoblarni ko‘rish'),
                        ),
                      ],
                    ),
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
            if (homeState.error != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _InfoBanner(
                    icon: Icons.warning_amber_rounded,
                    text: 'Ma’lumotni yangilashda xatolik bo‘ldi. Oxirgi saqlangan ma’lumot ko‘rsatilmoqda.',
                  ),
                ),
              ),
            if (homeState.loading && state.books.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (books.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 58, color: AppColors.muted),
                      const SizedBox(height: 14),
                      const Text('Kitob topilmadi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text('Bizda yo‘q kitobni so‘rov qilib qoldirishingiz mumkin.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: query.trim().length < 2 ? null : () async {
                          final message = await state.requestMissingBook(query);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                        },
                        icon: const Icon(Icons.library_add_rounded),
                        label: const Text('Shu kitob kerak'),
                      ),
                    ],
                  ),
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
                        (context, i) => BookCard(
                          book: books[i],
                          sharpCover: category != 'Barchasi',
                        ),
                        childCount: books.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: width < 450 ? .60 : .66,
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

class _DiscountCountdownBanner extends StatefulWidget {
  const _DiscountCountdownBanner();

  @override
  State<_DiscountCountdownBanner> createState() =>
      _DiscountCountdownBannerState();
}

class _DiscountCountdownBannerState extends State<_DiscountCountdownBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _remainingText(Duration remaining) {
    final totalSeconds = remaining.inSeconds.clamp(0, 1 << 31);
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (days > 0) return '${days} kun ${hours} soat qoldi';
    if (hours > 0) return '${hours} soat ${minutes} daqiqa qoldi';
    if (minutes > 0) return '${minutes} daqiqa ${seconds} soniya qoldi';
    return '${seconds} soniya qoldi';
  }

  @override
  Widget build(BuildContext context) {
    final discount = context.select<AppState, ({DateTime? end, int percent, bool blocksFreeDelivery})>(
      (s) => (
        end: s.activeDiscountEndsAt,
        percent: s.activeGlobalDiscountPercent,
        blocksFreeDelivery: s.discountBlocksFourPlusFreeDelivery,
      ),
    );
    final end = discount.end;
    if (end == null || discount.percent <= 0) return const SizedBox.shrink();

    final remaining = end.difference(DateTime.now());
    if (remaining <= Duration.zero) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: UzbekCustomerColors.goldSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UzbekCustomerColors.gold),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: UzbekCustomerColors.navy,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: UzbekCustomerColors.goldSoft,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔥 ${discount.percent}% chegirma — ${_remainingText(remaining)}',
                  style: const TextStyle(
                    color: UzbekCustomerColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Aksiya ${DateFormat('yyyy.MM.dd HH:mm').format(end)} da avtomatik tugaydi.',
                  style: const TextStyle(
                    color: UzbekCustomerColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (discount.blocksFreeDelivery) ...[
                  const SizedBox(height: 7),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Chegirma davrida 4+ kitobda yetkazib berish bepul aksiyasi amal qilmaydi.',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
  const _StoreHeader();

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.select<AppState, int>(
      (s) => s.unreadCustomerNoticeCount,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 10),
      decoration: BoxDecoration(
        color: UzbekCustomerColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: UzbekCustomerColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10173F4A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
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
                isLabelVisible: unreadCount > 0,
                label: Text('${unreadCount}'),
                child: IconButton(
                  tooltip: 'Bildirishnomalar',
                  onPressed: () => Navigator.push(
                    context,
                    muhajeerPageRoute(
                      settings: const RouteSettings(name: 'mb:notifications'),
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
    return Container(
      height: 350,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF043F3A), Color(0xFF075B52), Color(0xFF0B7063)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: UzbekCustomerColors.gold.withValues(alpha: .88),
          width: 1.35,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CustomPaint(
                    painter: _RegistanNightPainter(),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xD608443E),
                          Color(0xA808443E),
                          Color(0x5008443E),
                          Color(0x1808443E),
                        ],
                        stops: [0, .40, .70, 1],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x16000000),
                          Color(0x00000000),
                          Color(0x4A002C29),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -30,
            top: -32,
            child: IgnorePointer(
              child: Opacity(
                opacity: .92,
                child: UzbekMedallion(size: 118, dark: true),
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: -34,
            child: IgnorePointer(
              child: Opacity(
                opacity: .94,
                child: UzbekMedallion(size: 126, dark: true),
              ),
            ),
          ),
          const Positioned(
            right: 9,
            bottom: 7,
            child: IgnorePointer(child: _ApprovedOrnateBooks()),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: UzbekAtlasBand(height: 5)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UzbekMiniPill(
                  icon: Icons.auto_awesome_rounded,
                  text: 'O‘zbekona ruh',
                  dark: true,
                ),
                const SizedBox(height: 14),
                const SizedBox(
                  width: 278,
                  child: Text(
                    'Kitob tanlash endi\nyanada oson',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.45,
                      shadows: [
                        Shadow(
                          color: Color(0x24000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Koreya bo‘ylab tez va qulay buyurtma.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .88),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _HeroFact(
                      icon: Icons.local_shipping_rounded,
                      text: '1–3 ish kuni',
                    ),
                    _HeroFact(
                      icon: Icons.payments_outlined,
                      text: '택배 ₩4,000',
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(
                  width: 190,
                  child: Text(
                    'Kitobdan bebahra millat\nkelajaksizdir',
                    style: TextStyle(
                      color: UzbekCustomerColors.goldSoft,
                      fontFamily: 'Times New Roman',
                      fontSize: 10.8,
                      height: 1.30,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic,
                      letterSpacing: .15,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 86,
                  height: 1,
                  color: UzbekCustomerColors.gold.withValues(alpha: .75),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            bottom: 82,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0x26000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: UzbekCustomerColors.gold.withValues(alpha: .72),
                  width: 1.1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_shipping_rounded,
                    size: 18,
                    color: AppColors.gold,
                  ),
                  SizedBox(width: 7),
                  Text(
                    '4+ kitobda — pochta bepul',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: .13)),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFFFFF0C9),
                size: 29,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistanNightPainter extends CustomPainter {
  const _RegistanNightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF08766C), Color(0xFF075B52), Color(0xFF043F3A)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final moon = Paint()..color = const Color(0xFFFFE4A5).withValues(alpha: .88);
    canvas.drawCircle(Offset(size.width * .78, size.height * .19), size.width * .055, moon);

    final cloud = Paint()..color = const Color(0xFFBFD2B7).withValues(alpha: .16);
    for (final p in <Offset>[
      Offset(size.width*.57,size.height*.14), Offset(size.width*.63,size.height*.12),
      Offset(size.width*.69,size.height*.15), Offset(size.width*.48,size.height*.18)
    ]) {
      canvas.drawOval(Rect.fromCenter(center:p,width:size.width*.16,height:size.height*.07),cloud);
    }

    final silhouette = Paint()..color = const Color(0xFF063F3B).withValues(alpha:.78);
    final line = Paint()
      ..color = const Color(0xFFC89A4B).withValues(alpha:.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;

    final baseY=size.height*.72;
    final gate=Rect.fromLTWH(size.width*.55,size.height*.35,size.width*.25,size.height*.37);
    canvas.drawRect(gate,silhouette);
    canvas.drawRect(gate,line);
    final arch=Path()
      ..moveTo(size.width*.595,baseY)
      ..lineTo(size.width*.595,size.height*.49)
      ..quadraticBezierTo(size.width*.675,size.height*.39,size.width*.755,size.height*.49)
      ..lineTo(size.width*.755,baseY);
    canvas.drawPath(arch,line);

    void minaret(double x,double top,double w) {
      final r=Rect.fromLTWH(x,top,w,baseY-top);
      canvas.drawRect(r,silhouette); canvas.drawRect(r,line);
      canvas.drawOval(Rect.fromLTWH(x-w*.12,top-w*.35,w*1.24,w*.45),silhouette);
      canvas.drawLine(Offset(x+w*.5,top-w*.35),Offset(x+w*.5,top-w*.72),line);
      for(double y=top+w*.6;y<baseY;y+=w*.9) {
        canvas.drawLine(Offset(x,y),Offset(x+w,y),line);
      }
    }
    minaret(size.width*.47,size.height*.29,size.width*.045);
    minaret(size.width*.84,size.height*.27,size.width*.045);
    minaret(size.width*.38,size.height*.42,size.width*.035);

    void dome(double cx,double y,double r) {
      final p=Path()
        ..moveTo(cx-r,y+r)
        ..quadraticBezierTo(cx,y-r*.9,cx+r,y+r)
        ..close();
      canvas.drawPath(p,silhouette); canvas.drawPath(p,line);
      canvas.drawLine(Offset(cx,y-r*.65),Offset(cx,y-r*1.05),line);
    }
    dome(size.width*.43,size.height*.46,size.width*.065);
    dome(size.width*.82,size.height*.48,size.width*.055);

    // Keep the lower part of the hero continuous and smooth.
    // No separate ground rectangle or reflection lines: they caused visible seams/banding.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ApprovedOrnateBooks extends StatelessWidget {
  const _ApprovedOrnateBooks();

  @override
  Widget build(BuildContext context) {
    Widget book(String title, Color color, double w, double h) {
      return Container(
        width: w,
        height: h,
        margin: const EdgeInsets.only(left: 2.5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          border: Border.all(
            color: const Color(0xFFFFD47A),
            width: .7,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 3,
              top: 4,
              bottom: 4,
              child: Container(
                width: 1,
                color: UzbekCustomerColors.gold.withValues(alpha: .8),
              ),
            ),
            Positioned(
              right: 3,
              top: 4,
              bottom: 4,
              child: Container(
                width: 1,
                color: UzbekCustomerColors.gold.withValues(alpha: .55),
              ),
            ),
            Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: UzbekCustomerColors.goldSoft,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 155,
      height: 122,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                book('O‘TKAN KUNLAR', const Color(0xFF7A4B25), 29, 100),
                book('KECHA VA KUNDUZ', const Color(0xFF123D5B), 31, 110),
                book('IKKI ESHIK ORASI', const Color(0xFF3D3026), 31, 104),
                book('HALQA', const Color(0xFF0B6B5D), 29, 108),
                
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
          height: 78,
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
                  width: 86,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? UzbekCustomerColors.navy
                        : UzbekCustomerColors.surface,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: active
                          ? UzbekCustomerColors.navy
                          : UzbekCustomerColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        c == 'Barchasi'
                            ? Icons.grid_view_rounded
                            : _categoryIcon(c),
                        color: active
                            ? UzbekCustomerColors.gold
                            : UzbekCustomerColors.teal,
                        size: 23,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : UzbekCustomerColors.navy,
                          fontSize: 10.5,
                          fontWeight: active
                              ? FontWeight.w900
                              : FontWeight.w700,
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
          child: _TrustItem(icon: Icons.schedule_rounded, text: '1–3 ish kuni'),
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
                onTap: () => _openBookDetail(context, b),
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
                                      backgroundColor: UzbekCustomerColors.navy,
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
  const BookCard({
    super.key,
    required this.book,
    this.sharpCover = false,
  });
  final Book book;
  final bool sharpCover;

  @override
  Widget build(BuildContext context) {
    final favorite = context.select<AppState, bool>((s) => s.isFavorite(book));
    final restockSubscribed = context.select<AppState, bool>(
      (s) => s.isRestockSubscribed(book),
    );
    final state = context.read<AppState>();
    return Container(
      decoration: BoxDecoration(
        color: UzbekCustomerColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UzbekCustomerColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => _openBookDetail(context, book),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BookCover(book: book, sharp: sharpCover),
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
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
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
                              : () async {
                                  final message = await state
                                      .toggleRestockNotification(book);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                },
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(38, 38),
                          ),
                          child: Icon(
                            book.inStock
                                ? Icons.add_shopping_cart_rounded
                                : restockSubscribed
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded,
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
  const _BookCover({required this.book, this.sharp = false});
  final Book book;
  final bool sharp;

  @override
  Widget build(BuildContext context) {
    // Use the optimized full cover everywhere in the customer catalog.
    // Existing thumbnails are only ~360px and look soft on high-DPI phones.
    // The grid is lazy, and cacheWidth limits decode memory so scrolling stays
    // responsive instead of decoding full-resolution images in RAM.
    final originalUrl = book.imageUrl.trim();
    final previewUrl = book.previewImageUrl;
    final displayUrl = originalUrl.isNotEmpty ? originalUrl : previewUrl;
    if (displayUrl.isEmpty) return _placeholder();

    return Image.network(
      displayUrl,
      fit: BoxFit.cover,
      cacheWidth: 640,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return _placeholder();
      },
      errorBuilder: (_, __, ___) {
        if (previewUrl.isNotEmpty && previewUrl != displayUrl) {
          return Image.network(
            previewUrl,
            fit: BoxFit.cover,
            cacheWidth: 480,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        }
        return _placeholder();
      },
    );
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

Future<void> _shareBook(BuildContext context, Book book) async {
  final link = bookShareLink(book.id).toString();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                book.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Havolani ochgan odam aynan shu kitobni ko‘radi.'),
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text('Instagram story tayyorlash'),
                subtitle: const Text('Kitob rasmi, narxi va buyurtma havolasi'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    muhajeerPageRoute<void>(
                      builder: (_) => BookStoryPage(book: book),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Havolani nusxalash'),
                onTap: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kitob havolasi nusxalandi'),
                        ),
                      );
                  } catch (_) {
                    if (sheetContext.mounted) {
                      await showDialog<void>(
                        context: sheetContext,
                        builder: (_) => AlertDialog(
                          title: const Text('Kitob havolasi'),
                          content: SelectableText(link),
                        ),
                      );
                    }
                  }
                },
              ),
              if (nativeBookShareAvailable)
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('Ulashish'),
                  onTap: () async {
                    try {
                      await nativeBookShare(book.title, link);
                    } catch (_) {
                      // Cancellation leaves the copy option available.
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.send_rounded),
                title: const Text('Telegram orqali yuborish'),
                onTap: () async {
                  final uri = Uri.https('t.me', '/share/url', {
                    'url': link,
                    'text': book.title,
                  });
                  try {
                    final opened = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened) throw StateError('not opened');
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Havolani nusxalab, Telegram orqali yuboring.',
                          ),
                        ),
                      );
                  }
                },
              ),
            ],
          ),
        ),
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
      return Scaffold(
        backgroundColor: UzbekCustomerColors.background,
        appBar: AppBar(title: const Text('Kitob haqida')),
        body: SafeArea(
          child: Center(
            child: state.loading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Kitob topilmadi yoki katalogdan olib tashlangan.',
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Katalogga qaytish'),
                      ),
                    ],
                  ),
          ),
        ),
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
          IconButton(
            onPressed: () => _shareBook(context, b),
            tooltip: 'Kitobni ulashish',
            icon: const Icon(Icons.ios_share_rounded),
          ),
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
          final cover = _BookGallery(book: b, desktop: desktop);
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Narxi',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(width: 10),
                  if (b.isDiscounted) ...[
                    Text(
                      won(b.price),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      won(b.currentPrice),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              if (b.inStock)
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(58),
                          ),
                          onPressed: () {
                            state.addToCart(b);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Savatchaga qo‘shildi ✅'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text('Savatga solish'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(58),
                          ),
                          onPressed: () {
                            state.addToCart(b);
                            Navigator.push<void>(
                              context,
                              muhajeerPageRoute<void>(
                                settings: const RouteSettings(
                                  name: 'mb:cart-direct',
                                ),
                                builder: (_) => const CartPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.flash_on_rounded),
                          label: const Text('Zakaz qilish'),
                        ),
                      ),
                    ],
                  ),
                )
              else if (b.preorderEnabled)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
                    onPressed: () async {
                      final message = await state.submitPreorder(b);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                    },
                    icon: const Icon(Icons.event_available_rounded),
                    label: const Text('Pre-order qoldirish'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final message = await state.toggleRestockNotification(
                            b,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(message)));
                        },
                        icon: Icon(
                          state.isRestockSubscribed(b)
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                        ),
                        label: Text(
                          state.isRestockSubscribed(b)
                              ? 'Xabar beramiz ✅'
                              : 'Kelganda xabar berish',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (b.legacyId != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openTelegramRestock(context, b),
                          icon: const Icon(Icons.send_rounded),
                          label: const Text(
                            'Telegramda xabar olish',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookGallery extends StatefulWidget {
  const _BookGallery({required this.book, required this.desktop});
  final Book book;
  final bool desktop;

  @override
  State<_BookGallery> createState() => _BookGalleryState();
}

class _BookGalleryState extends State<_BookGallery> {
  late final PageController controller;
  int index = 0;

  @override
  void initState() {
    super.initState();
    controller = PageController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.book.galleryImages;
    final width = widget.desktop ? 300.0 : 235.0;
    final coverHeight = widget.desktop ? 420.0 : 330.0;
    if (images.isEmpty) {
      return SizedBox(
        width: width,
        height: coverHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: _BookCover(book: widget.book),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        children: [
          Container(
            width: width,
            height: coverHeight,
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
            child: PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (_, i) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  muhajeerPageRoute(
                    settings: RouteSettings(
                      name: 'mb:image:${widget.book.id}:$i',
                    ),
                    builder: (_) => BookImageViewerPage(
                      images: images,
                      initialIndex: i,
                      title: widget.book.title,
                    ),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      cacheWidth: widget.desktop ? 900 : 700,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) =>
                          _BookCover(book: widget.book),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Icon(
                          Icons.zoom_out_map_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    width: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: i == index
                            ? UzbekCustomerColors.goldDeep
                            : UzbekCustomerColors.border,
                        width: i == index ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      widget.book.galleryThumbnailUrlAt(i),
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${index + 1}/${images.length} • Kattalashtirish uchun rasmni bosing',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
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
          if (book.publisher.isNotEmpty)
            AppInfoPill(
              icon: Icons.business_outlined,
              label: 'Nashriyot: ${book.publisher}',
            ),
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
        child: Row(
          children: [
            const _DetailFact(
              icon: Icons.local_shipping_outlined,
              title: 'Yetkazish',
              value: '1–3 ish kuni',
            ),
            const SizedBox(width: 8),
            const _DetailFact(
              icon: Icons.payments_outlined,
              title: '택배',
              value: '₩4,000',
            ),
            const SizedBox(width: 8),
            _DetailFact(
              icon: Icons.card_giftcard_outlined,
              title: '4+ kitob',
              value: context.watch<AppState>().fourPlusFreeDeliveryEnabled
                  ? 'Bepul'
                  : 'Chegirmada yo‘q',
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
  const CartPage({super.key, this.onContinueShopping});

  final VoidCallback? onContinueShopping;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lines = state.cartStandaloneLines;
    final bundles = state.cartBundles;
    final hasItems = state.cartDisplayCount > 0;
    final deliveryFee = state.cartBundleDeliveryIncluded ||
            (state.cartDisplayCount >= 4 && state.fourPlusFreeDeliveryEnabled)
        ? 0
        : AppState.deliveryFee;
    final grandTotal = state.cartSubtotal + deliveryFee;
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Savatcha'),
        actions: [
          if (hasItems)
            TextButton.icon(
              onPressed: state.clearCart,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Tozalash'),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: !hasItems
          ? _EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Savatcha bo‘sh',
              subtitle: state.discountBlocksFourPlusFreeDelivery
                  ? 'Hozir chegirma amalda. Chegirma davrida 4+ kitobda yetkazib berish bepul aksiyasi amal qilmaydi.'
                  : 'Kerakli kitoblarni savatchaga qo‘shing. 4 ta va undan ko‘p kitobda yetkazib berish bepul.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 190),
              children: [
                AppSectionHeader(
                  title: 'Sizning tanlovingiz',
                  subtitle: '${state.cartDisplayCount} ta mahsulot',
                  trailing: AppInfoPill(
                    icon: state.discountBlocksFourPlusFreeDelivery
                        ? Icons.local_shipping_outlined
                        : (state.cartDisplayCount >= 4
                            ? Icons.card_giftcard_rounded
                            : Icons.local_shipping_outlined),
                    label: state.discountBlocksFourPlusFreeDelivery
                        ? 'Chegirmada ₩4,000'
                        : (state.cartDisplayCount >= 4
                            ? 'Yetkazish bepul'
                            : '4+ kitobda bepul'),
                    foreground: !state.discountBlocksFourPlusFreeDelivery &&
                            state.cartDisplayCount >= 4
                        ? AppColors.success
                        : AppColors.navy,
                    background: !state.discountBlocksFourPlusFreeDelivery &&
                            state.cartDisplayCount >= 4
                        ? AppColors.successSoft
                        : AppColors.surfaceSoft,
                    border: !state.discountBlocksFourPlusFreeDelivery &&
                            state.cartDisplayCount >= 4
                        ? const Color(0xFFCDEAD7)
                        : AppColors.border,
                  ),
                ),
                if (state.discountBlocksFourPlusFreeDelivery) ...[
                  const _DiscountShippingWarning(),
                  const SizedBox(height: 10),
                ],
                ...bundles.map(
                  (bundle) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BundleCartCard(
                      bundle: bundle,
                      state: state,
                    ),
                  ),
                ),
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
      bottomNavigationBar: !hasItems
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
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final callback = onContinueShopping;
                          if (callback != null) {
                            callback();
                            return;
                          }

                          storefrontTabRequest.value = 0;
                          final navigator = Navigator.of(context);
                          if (navigator.canPop()) {
                            navigator.popUntil((route) => route.isFirst);
                          }
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Yana kitob qo‘shish'),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                          won(grandTotal),
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
                          (state.cartBundleDeliveryIncluded ||
                                  (state.cartDisplayCount >= 4 &&
                                      state.fourPlusFreeDeliveryEnabled))
                              ? Icons.check_circle_rounded
                              : Icons.local_shipping_outlined,
                          size: 16,
                          color: (state.cartBundleDeliveryIncluded ||
                                  (state.cartDisplayCount >= 4 &&
                                      state.fourPlusFreeDeliveryEnabled))
                              ? AppColors.success
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            state.cartBundleDeliveryIncluded
                                ? 'Set narxiga pochta ham kiritilgan'
                                : (state.discountBlocksFourPlusFreeDelivery
                                    ? 'Chegirma davrida 택배 ₩4,000'
                                    : (state.cartDisplayCount >= 4
                                        ? 'Yetkazib berish siz uchun bepul'
                                        : '택배 ₩4,000 • 4+ kitobda bepul')),
                            style: TextStyle(
                              color: (state.cartBundleDeliveryIncluded ||
                                      (state.cartDisplayCount >= 4 &&
                                          state.fourPlusFreeDeliveryEnabled))
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
                          muhajeerPageRoute(
                            settings: const RouteSettings(name: 'mb:checkout'),
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

class _BundleCartCard extends StatelessWidget {
  const _BundleCartCard({
    required this.bundle,
    required this.state,
  });

  final Map<String, dynamic> bundle;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final items = ((bundle['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final books = <Book>[];
    var bookCount = 0;
    for (final item in items) {
      bookCount += (item['quantity'] as num?)?.toInt() ?? 1;
      final id = (item['book_id'] ?? '').toString();
      for (final book in state.books) {
        if (book.id == id) {
          books.add(book);
          break;
        }
      }
    }
    final setPrice = (bundle['price'] as num?)?.toInt() ?? 0;
    final regular = (bundle['regular_total'] as num?)?.toInt() ?? 0;
    final saving = (regular - setPrice).clamp(0, regular).toInt();
    final deliveryIncluded = bundle['delivery_included'] == true;

    return AppSurface(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < books.take(3).length; i++)
                  Positioned(
                    left: 5.0 + i * 18,
                    top: i == 1 ? 2 : 9,
                    child: Transform.rotate(
                      angle: (i - 1) * 0.055,
                      child: Container(
                        width: 54,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: _BookCover(book: books[i]),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 4,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'SET',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (bundle['title'] ?? 'Kitoblar seti').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Savatchada 1 ta • ichida $bookCount ta kitob',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      won(setPrice),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (saving > 0) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          '${won(saving)} tejaysiz',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  deliveryIncluded
                      ? 'Pochta set narxiga kiritilgan'
                      : 'Pochta alohida',
                  style: TextStyle(
                    color: deliveryIncluded
                        ? AppColors.success
                        : AppColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => state.removeBundleFromCart(bundle),
            tooltip: 'Setni olib tashlash',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
          ),
        ],
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

class _DiscountShippingWarning extends StatelessWidget {
  const _DiscountShippingWarning();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F2),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFFCDD2)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.local_shipping_outlined,
          size: 20,
          color: AppColors.danger,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Chegirma davrida 4+ kitobda yetkazib berish bepul aksiyasi amal qilmaydi.',
            style: TextStyle(
              color: AppColors.danger,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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
    final savedPhone = (saved['phone'] ?? '').replaceAll(RegExp(r'\D'), '');
    phone = TextEditingController(
      text: _isSupportedCustomerPhone(savedPhone) ? savedPhone : '',
    );
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
    // To‘lov skrinshotini tanlash paytida avtomatik yengillashtiramiz.
    // Matn o‘qiladigan darajada qoladi, lekin odatiy telefon skrinshotlari
    // 7 MB yuklash limitidan ancha past bo‘lib qoladi.
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 76,
      maxWidth: 1440,
      maxHeight: 2400,
    );
    if (file == null || !mounted) return;
    setState(() => paymentProof = file);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isGyeongsanPickup = delivery == '경산 직접수령';
    final deliveryFee = isGyeongsanPickup
        ? 0
        : (state.cartBundleDeliveryIncluded ||
                (state.cartDisplayCount >= 4 && state.fourPlusFreeDeliveryEnabled)
            ? 0
            : AppState.deliveryFee);
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Telefon raqam',
                        hintText: 'Masalan: 01024338600',
                        helperText:
                            'Koreya raqamini 010 bilan 11 ta raqamda kiriting.',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => !_isSupportedCustomerPhone(v ?? '')
                          ? 'Koreya 010 raqamini to‘liq kiriting. Masalan: 01024338600'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: address,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: isGyeongsanPickup
                            ? 'Manzil (ixtiyoriy)'
                            : 'Manzil',
                        alignLabelWithHint: true,
                        helperMaxLines: 3,
                        helperText: isGyeongsanPickup
                            ? '경산da o‘zingiz olib ketsangiz, to‘liq manzil kiritish shart emas.'
                            : 'Manzil va xona raqamini to‘liq yozing.\nMasalan: 경상북도 경산시 계양로 37길 7-3, 808호',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => isGyeongsanPickup
                          ? null
                          : (v == null || v.trim().length < 8
                                ? 'To‘liq manzilni kiriting'
                                : null),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _CheckoutStepHeader(number: '2', title: 'Yetkazib berish'),
            const SizedBox(height: 8),
            if (state.discountBlocksFourPlusFreeDelivery) ...[
              const _DiscountShippingWarning(),
              const SizedBox(height: 10),
            ],
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: '택배',
                    groupValue: delivery,
                    onChanged: (v) => setState(() => delivery = v!),
                    title: const Text(
                      'Koreya bo‘ylab pochta (택배)',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      state.discountBlocksFourPlusFreeDelivery
                          ? 'Chegirma davrida ₩4,000 • 1–3 ish kuni'
                          : (state.cartDisplayCount >= 4
                              ? '4+ kitob — BEPUL • 1–3 ish kuni'
                              : '₩4,000 • 1–3 ish kuni'),
                    ),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    value: '경산 직접수령',
                    groupValue: delivery,
                    onChanged: (v) => setState(() => delivery = v!),
                    title: const Text(
                      '경산 (Gyeongsan) — o‘zim olib ketaman',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('BEPUL • Pochta puli olinmaydi'),
                    secondary: const Icon(Icons.storefront_outlined),
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
                    _priceRow(
                      state.cartBundleDiscount > 0
                          ? 'Kitoblar (set narxida)'
                          : 'Kitoblar',
                      state.cartSubtotal,
                    ),
                    if (state.cartBundleDiscount > 0) ...[
                      const SizedBox(height: 8),
                      _priceRow('Set orqali tejash', -state.cartBundleDiscount),
                    ],
                    const SizedBox(height: 8),
                    _priceRow(
                      state.cartBundleDeliveryIncluded
                          ? 'Yetkazib berish (set ichida)'
                          : 'Yetkazib berish',
                      deliveryFee,
                    ),
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
                      'Buyurtma yuborilganda kitoblar ombordan darhol band qilinadi. Buyurtma bekor qilinsa, omborga avtomatik qaytadi.',
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

  String _shortOrderNumber(AppState state, String orderId) {
    for (final order in state.localOrders) {
      if (order.id == orderId && order.displayOrderNumber > 0) {
        return order.displayOrderNumber.toString().padLeft(4, '0');
      }
    }
    return orderId;
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
        address: isGyeongsanPickupAddress(address.text, delivery),
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
                'Buyurtma raqami:\n${_shortOrderNumber(state, orderId)}',
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

class _ProfileMosaicPainter extends CustomPainter {
  const _ProfileMosaicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = const Color(0xBFE8C66A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;
    final teal = Paint()
      ..color = const Color(0x8059B7C3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    final center = Offset(size.width * .5, size.height * .49);

    // Dark central medallion exactly like the supplied reference.
    final medallion = Rect.fromCenter(
      center: center,
      width: size.width * .52,
      height: size.height * .98,
    );
    canvas.drawOval(
      medallion,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xF5052C45), Color(0xEB07344D), Color(0xB0052943), Color(0x00052943)],
          stops: [0, .58, .82, 1],
        ).createShader(medallion),
    );

    // Concentric Uzbek/Islamic arches around the central medallion.
    void arch(double inset, Paint paint) {
      final left = size.width * inset;
      final right = size.width * (1 - inset);
      final bottom = size.height * .98;
      final shoulder = size.height * .37;
      final top = size.height * .015;
      final path = Path()
        ..moveTo(left, bottom)
        ..lineTo(left, shoulder)
        ..quadraticBezierTo(left, size.height * .12, center.dx, top)
        ..quadraticBezierTo(right, size.height * .12, right, shoulder)
        ..lineTo(right, bottom);
      canvas.drawPath(path, paint);
    }

    arch(.035, gold);
    arch(.085, teal);
    arch(.135, gold);
    arch(.19, teal);
    arch(.245, gold);

    // Fine geometric diamonds on both sides.
    for (var y = 12.0; y < size.height - 8; y += 22) {
      for (final x in [size.width * .055, size.width * .945]) {
        final d = Path()
          ..moveTo(x, y - 5)
          ..lineTo(x + 5, y)
          ..lineTo(x, y + 5)
          ..lineTo(x - 5, y)
          ..close();
        canvas.drawPath(d, gold);
        canvas.drawCircle(Offset(x, y), 1.1, teal);
      }
    }

    // Subtle central rosette behind the customer's name.
    for (var i = 0; i < 16; i++) {
      final aa = i * 3.141592653589793 / 8;
      final p1 = center + Offset(
        size.width * .12 * MathCos.cos(aa),
        size.height * .23 * MathCos.sin(aa),
      );
      final p2 = center + Offset(
        size.width * .205 * MathCos.cos(aa),
        size.height * .40 * MathCos.sin(aa),
      );
      canvas.drawLine(p1, p2, i.isEven ? gold : teal);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * .34,
        height: size.height * .70,
      ),
      teal,
    );

    // Small star points like the reference.
    final star = Paint()..color = const Color(0xBFFFF2B5);
    for (var i = 0; i < 38; i++) {
      final x = ((i * 83) % 997) / 997 * size.width;
      final y = ((i * 47) % 311) / 311 * size.height * .72;
      if ((x - center.dx).abs() < size.width * .27) continue;
      canvas.drawCircle(Offset(x, y), i % 6 == 0 ? 1.15 : .55, star);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MathCos {
  static double cos(double x) => _sin(x + 1.5707963267948966);
  static double sin(double x) => _sin(x);
  static double _sin(double x) {
    const pi = 3.141592653589793;
    while (x > pi) x -= 2 * pi;
    while (x < -pi) x += 2 * pi;
    final x2 = x * x;
    return x * (1 - x2 / 6 + x2 * x2 / 120 - x2 * x2 * x2 / 5040 + x2 * x2 * x2 * x2 / 362880);
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final activeBooks = state.books.where((b) => b.isActive).length;
    final availableBooks = state.books
        .where((b) => b.isActive && b.inStock)
        .length;
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
                    muhajeerPageRoute(
                      settings: const RouteSettings(name: 'mb:admin'),
                      builder: (_) => const AdminGatePage(),
                    ),
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
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book_rounded, color: Color(0xFFF3D58B), size: 17),
                    SizedBox(width: 7),
                    Text(
                      'Muhajeer Books',
                      style: TextStyle(
                        color: Color(0xFFF8E6BF),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const UzbekOrnamentDivider(),
                const SizedBox(height: 10),
                const Text(
                  'Koreyadagi O‘zbek kitobxonlari uchun',
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
                    muhajeerPageRoute(
                      settings: const RouteSettings(name: 'mb:orders'),
                      builder: (_) => const MyOrdersPage(),
                    ),
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
                    muhajeerPageRoute(
                      settings: const RouteSettings(name: 'mb:favorites'),
                      builder: (_) => const FavoritesPage(),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  minTileHeight: 68,
                  leading: const _InstagramProfileIcon(),
                  title: const Text(
                    'Do‘kon Instagrami',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('@muhajeerbooks'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://www.instagram.com/muhajeerbooks?stkn=dmdpNHhuM3ZsN3U5',
                    );
                    final opened = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Do‘kon Instagram ochilmadi.'),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  minTileHeight: 68,
                  leading: const _InstagramProfileIcon(),
                  title: const Text(
                    'Admin Instagrami',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('@bek_ismoill'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://www.instagram.com/bek_ismoill?stkn=MW9wbWl0djY5OGM1bA==',
                    );
                    final opened = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Admin Instagram ochilmadi.'),
                        ),
                      );
                    }
                  },
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

class _ProfileReferenceAction extends StatelessWidget {
    const _ProfileReferenceAction({required this.icon, required this.label, required this.onTap});
    final IconData icon; final String label; final VoidCallback onTap;
    @override Widget build(BuildContext context) => Material(
      color: const Color(0xFFFFFCF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE4D3AE))),
      child: InkWell(onTap:onTap,borderRadius:BorderRadius.circular(20),child:Padding(padding:const EdgeInsets.symmetric(horizontal:9,vertical:13),child:Row(children:[Icon(icon,color:const Color(0xFF082B3D),size:25),const SizedBox(width:6),Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Color(0xFF082B3D),fontWeight:FontWeight.w800,fontFamily:'serif',fontSize:12))),const Icon(Icons.chevron_right_rounded,color:Color(0xFF082B3D),size:18)]))),
    );
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

class _InstagramProfileIcon extends StatelessWidget {
  const _InstagramProfileIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: UzbekCustomerColors.goldSoft,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: UzbekCustomerColors.border),
    ),
    alignment: Alignment.center,
    child: SizedBox(
      width: 23,
      height: 23,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: UzbekCustomerColors.navy,
                  width: 2,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: UzbekCustomerColors.navy,
                  width: 2,
                ),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              width: 3.5,
              height: 3.5,
              decoration: const BoxDecoration(
                color: UzbekCustomerColors.navy,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
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

  Future<void> _restoreOrders() async {
    final state = context.read<AppState>();
    final phoneController = TextEditingController(
      text: state.savedCustomer['phone'] ?? '',
    );
    final codeController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eski buyurtmalarni tiklash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Oldingi buyurtmadagi 12 belgili tiklash kodi va telefon raqamingizni kiriting.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon raqami',
                hintText: '010-1234-5678',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Tiklash kodi',
                hintText: '12 belgi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tiklash'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      phoneController.dispose();
      codeController.dispose();
      return;
    }

    try {
      final count = await state.restoreCustomerOrders(
        phone: phoneController.text,
        recoveryCode: codeController.text,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '$count ta buyurtma tiklandi ✅'
                : 'Tiklanadigan buyurtma topilmadi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('PostgrestException(message: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tiklash amalga oshmadi: $message')),
      );
    } finally {
      phoneController.dispose();
      codeController.dispose();
    }
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
            tooltip: 'Eski buyurtmalarni tiklash',
            onPressed: _restoreOrders,
            icon: const Icon(Icons.restore_rounded),
          ),
          IconButton(
            tooltip: 'Yangilash',
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
                                'Buyurtma № ${order.recoveryCode}',
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
                    if (order.status == 'shipping' ||
                        order.status == 'done') ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCDEAD7)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.local_shipping_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Buyurtma pochtaga topshirildi.\n1–3 ish kunida yetkaziladi.',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (order.status == 'paid' ||
                        order.status == 'shipping' ||
                        order.status == 'done') ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showMuhajeerReceipt(context, order),
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('🧾 Chekni ko‘rish'),
                        ),
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

Future<void> _showMuhajeerReceipt(BuildContext context, ShopOrder order) async {
  final itemTotal = order.items.fold<int>(0, (sum, item) {
    final original = (item['original_price'] as num?)?.toInt() ??
        (item['price'] as num?)?.toInt() ??
        (item['unit_price'] as num?)?.toInt() ?? 0;
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    return sum + original * quantity;
  });
  final discount = (itemTotal - order.subtotal).clamp(0, itemTotal).toInt();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: UzbekCustomerColors.border),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories_rounded,
                  color: UzbekCustomerColors.navy, size: 34),
              const SizedBox(height: 8),
              const Text('MUHAJEER BOOKS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Text('Xaridingiz uchun rahmat!',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 18),
              const Divider(),
              _ReceiptRow(label: 'Buyurtma', value: '#${order.displayOrderNumber ?? order.recoveryCode}'),
              _ReceiptRow(label: 'Sana', value: DateFormat('dd.MM.yyyy  HH:mm').format(order.createdAt)),
              _ReceiptRow(label: 'Mijoz', value: order.customerName),
              const Divider(),
              ...order.items.map((item) {
                final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                final price = (item['price'] as num?)?.toInt() ??
                    (item['unit_price'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['title'] ?? 'Kitob').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$quantity × ${won(price)}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '············',
                                overflow: TextOverflow.clip,
                                maxLines: 1,
                                style: TextStyle(color: AppColors.border),
                              ),
                            ),
                          ),
                          Text(
                            won(price * quantity),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              _ReceiptRow(label: 'Kitoblar', value: won(itemTotal > 0 ? itemTotal : order.subtotal)),
              if (discount > 0)
                _ReceiptRow(label: 'Chegirma', value: '-${won(discount)}'),
              _ReceiptRow(label: 'Yetkazib berish',
                  value: order.deliveryFee == 0 ? 'Bepul' : won(order.deliveryFee)),
              const SizedBox(height: 6),
              _ReceiptRow(label: 'JAMI', value: won(order.total), strong: true),
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                  SizedBox(width: 7),
                  Text('To‘lov qabul qilindi',
                      style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.success)),
                ],
              ),
              const SizedBox(height: 18),
              const Text('MUHAJEER BOOKS',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const Text('Koreya bo‘ylab kitoblar 📚',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                color: strong ? AppColors.navy : AppColors.text,
              )),
        ),
        const SizedBox(width: 12),
        Text(value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: strong ? 18 : 14,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              color: strong ? AppColors.navy : AppColors.text,
            )),
      ],
    ),
  );
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
      'shipping' || 'done' => 2,
      _ => 0,
    };
    const labels = ['Yuborildi', 'Qabul qilindi', 'Jo‘natildi'];
    const icons = [
      Icons.outbox_rounded,
      Icons.inventory_2_rounded,
      Icons.local_shipping_rounded,
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
      'done' => 'Jo‘natildi',
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
