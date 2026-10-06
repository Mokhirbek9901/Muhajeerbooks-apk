import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'catalog_resume.dart';
import 'store_ui.dart';
import 'uzbek_customer_style.dart';
import 'muhajeer_ai_page.dart';

/// Fast storefront shell.
///
/// The home page stays mounted so its search/scroll state is preserved, but
/// only the currently visible secondary tab is kept in the tree. Previously
/// every tab that had ever been opened stayed inside an IndexedStack, so a
/// cart/favorite/order-state notification could rebuild several hidden pages
/// at once. Keeping just Home + the active secondary page removes that hidden
/// work while preserving the storefront behaviour users see.
class _PersistentMuhajeerAiButton extends StatefulWidget {
  const _PersistentMuhajeerAiButton();

  @override
  State<_PersistentMuhajeerAiButton> createState() =>
      _PersistentMuhajeerAiButtonState();
}

class _PersistentMuhajeerAiButtonState
    extends State<_PersistentMuhajeerAiButton> {
  static const _xKey = 'muhajeer_ai_fab_x_fraction';
  static const _yKey = 'muhajeer_ai_fab_y_fraction';
  static const _buttonWidth = 148.0;
  static const _buttonHeight = 48.0;
  static const _edgeMargin = 12.0;

  double _xFraction = 0;
  double _yFraction = 1;

  @override
  void initState() {
    super.initState();
    _restorePosition();
  }

  Future<void> _restorePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_xKey);
      final y = prefs.getDouble(_yKey);
      if (!mounted) return;
      setState(() {
        _xFraction = (x ?? 0).clamp(0.0, 1.0).toDouble();
        _yFraction = (y ?? 1).clamp(0.0, 1.0).toDouble();
      });
    } catch (_) {
      // Local storage mavjud bo'lmasa ham tugma standart joyida ishlaydi.
    }
  }

  Future<void> _savePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_xKey, _xFraction);
      await prefs.setDouble(_yKey, _yFraction);
    } catch (_) {
      // Joylashuvni saqlashdagi xato asosiy ilovani bloklamaydi.
    }
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, constraints) {
        final minX = _edgeMargin;
        final minY = topSafe + 6;
        final usableX =
            (constraints.maxWidth - _buttonWidth - (_edgeMargin * 2))
                .clamp(0.0, double.infinity)
                .toDouble();
        final usableY =
            (constraints.maxHeight - _buttonHeight - minY - _edgeMargin)
                .clamp(0.0, double.infinity)
                .toDouble();

        final left = minX + (usableX * _xFraction);
        final top = minY + (usableY * _yFraction);

        void moveBy(Offset delta) {
          final nextLeft =
              (left + delta.dx).clamp(minX, minX + usableX).toDouble();
          final nextTop =
              (top + delta.dy).clamp(minY, minY + usableY).toDouble();
          setState(() {
            _xFraction = usableX <= 0 ? 0 : (nextLeft - minX) / usableX;
            _yFraction = usableY <= 0 ? 0 : (nextTop - minY) / usableY;
          });
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              top: top,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerMove: (event) => moveBy(event.delta),
                onPointerUp: (_) => _savePosition(),
                onPointerCancel: (_) => _savePosition(),
                child: SizedBox(
                  width: _buttonWidth,
                  height: _buttonHeight,
                  child: FloatingActionButton.extended(
                    heroTag: 'muhajeer-ai',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MuhajeerAiPage(),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text(
                      'Muhajeer AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    extendedPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WebStorefrontFrame extends StatelessWidget {
  const _WebStorefrontFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return ColoredBox(
      color: UzbekCustomerColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: UzbekCustomerColors.background,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _WebDesktopHeader extends StatelessWidget {
  const _WebDesktopHeader({
    required this.selectedIndex,
    required this.cartCount,
    required this.onSelectTab,
  });

  final int selectedIndex;
  final int cartCount;
  final ValueChanged<int> onSelectTab;

  void _open(BuildContext context, Widget page, String routeName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: routeName),
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget nav(String label, int index) => TextButton(
      onPressed: () => onSelectTab(index),
      style: TextButton.styleFrom(
        foregroundColor: selectedIndex == index
            ? UzbekCustomerColors.navy
            : UzbekCustomerColors.textMuted,
        textStyle: TextStyle(
          fontWeight: selectedIndex == index ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
      child: Text(label),
    );

    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: UzbekCustomerColors.border)),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: UzbekCustomerColors.navy, size: 30),
            const SizedBox(width: 10),
            const Text(
              'MUHAJEER BOOKS',
              style: TextStyle(
                color: UzbekCustomerColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
            const SizedBox(width: 24),
            nav('Bosh sahifa', 0),
            nav('Kategoriyalar', 1),
            TextButton(
              onPressed: () => _open(context, const PublishersPage(), 'mb:publishers'),
              child: const Text('Nashriyotlar'),
            ),
            TextButton(
              onPressed: () => _open(context, const BookBundlesPage(), 'mb:bundles'),
              child: const Text('Setlar'),
            ),
            TextButton(
              onPressed: () => _open(context, const PreorderBooksPage(), 'mb:preorders'),
              child: const Text('Oldindan sotuv'),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Sevimlilar',
              onPressed: () => onSelectTab(3),
              icon: Icon(
                selectedIndex == 3 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: UzbekCustomerColors.navy,
              ),
            ),
            Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: IconButton(
                tooltip: 'Savatcha',
                onPressed: () => onSelectTab(2),
                icon: Icon(
                  selectedIndex == 2
                      ? Icons.shopping_cart_rounded
                      : Icons.shopping_cart_outlined,
                  color: UzbekCustomerColors.navy,
                ),
              ),
            ),
            const SizedBox(width: 4),
            FilledButton.tonalIcon(
              onPressed: () => onSelectTab(4),
              icon: const Icon(Icons.person_outline_rounded, size: 19),
              label: const Text('Mening'),
            ),
          ],
        ),
      ),
    );
  }
}

class FastStoreShell extends StatefulWidget {
  const FastStoreShell({super.key});

  @override
  State<FastStoreShell> createState() => _FastStoreShellState();
}

class _FastStoreShellState extends State<FastStoreShell> {
  int index = 0;
  String? _lastPresentedNoticeId;

  void _showHome() {
    if (!mounted || index == 0) return;
    setState(() => index = 0);
  }

  Widget _secondaryPageFor(int pageIndex) {
    switch (pageIndex) {
      case 1:
        return const CategoriesPage();
      case 2:
        return CartPage(onContinueShopping: _showHome);
      case 3:
        return const FavoritesPage();
      case 4:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    CatalogResume.instance.addListener(_resetAfterAbsence);
    storefrontTabRequest.addListener(_handleTabRequest);
  }

  void _handleTabRequest() {
    final requested = storefrontTabRequest.value;
    if (!mounted || requested == null || requested < 0 || requested > 4) return;
    if (requested == index) return;
    setState(() => index = requested);
  }

  void _resetAfterAbsence() {
    if (!mounted) return;
    // Admin panel o'zining alohida 10 daqiqalik resume qoidasi bilan boshqariladi.
    // Storefront timeouti admin route'larini hech qachon pop qilmasin.
    if (CatalogResume.instance.adminPanelActive) return;

    setState(() => index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    CatalogResume.instance.removeListener(_resetAfterAbsence);
    storefrontTabRequest.removeListener(_handleTabRequest);
    super.dispose();
  }

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
        if (notice == null || notice['id']?.toString() != latestNoticeId) return;
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

    void selectTab(int value) {
      storefrontTabRequest.value = value;
      if (value == index) return;
      setState(() => index = value);
    }

    Widget storefrontBody() => _WebStorefrontFrame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: index != 0,
            child: TickerMode(
              enabled: index == 0,
              child: const HomePage(key: PageStorageKey<String>('home-tab')),
            ),
          ),
          if (index != 0)
            KeyedSubtree(
              key: ValueKey<int>(index),
              child: _secondaryPageFor(index),
            ),
          if (index == 0)
            const Positioned.fill(child: _PersistentMuhajeerAiButton()),
        ],
      ),
    );

    Widget mobileNav() => SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        decoration: BoxDecoration(
          color: UzbekCustomerColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: UzbekCustomerColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D173F4A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 66,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: UzbekCustomerColors.goldSoft,
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? UzbekCustomerColors.navy
                    : UzbekCustomerColors.textMuted,
                size: 23,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected)
                    ? UzbekCustomerColors.navy
                    : UzbekCustomerColors.textMuted,
                fontSize: 10.8,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w900
                    : FontWeight.w600,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: selectTab,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Bosh sahifa',
              ),
              const NavigationDestination(
                icon: Icon(Icons.grid_view_rounded),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Kategoriya',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  child: const Icon(Icons.shopping_cart_rounded),
                ),
                label: 'Savatcha',
              ),
              const NavigationDestination(
                icon: Icon(Icons.favorite_border_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: 'Sevimlilar',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = kIsWeb && constraints.maxWidth >= 1180;
        return Scaffold(
          backgroundColor: UzbekCustomerColors.background,
          body: desktop
              ? Column(
                  children: [
                    _WebDesktopHeader(
                      selectedIndex: index,
                      cartCount: cartCount,
                      onSelectTab: selectTab,
                    ),
                    Expanded(child: storefrontBody()),
                  ],
                )
              : storefrontBody(),
          bottomNavigationBar: desktop ? null : mobileNav(),
        );
      },
    );
  }
}
