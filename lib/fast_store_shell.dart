import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'catalog_resume.dart';
import 'store_ui.dart';
import 'uzbek_customer_style.dart';

/// Fast storefront shell.
///
/// The home page stays mounted so its search/scroll state is preserved, but
/// only the currently visible secondary tab is kept in the tree. Previously
/// every tab that had ever been opened stayed inside an IndexedStack, so a
/// cart/favorite/order-state notification could rebuild several hidden pages
/// at once. Keeping just Home + the active secondary page removes that hidden
/// work while preserving the storefront behaviour users see.
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

    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Home is the only tab intentionally kept alive. It already listens
          // only to catalog-specific revisions, so cart/favorite changes don't
          // trigger an expensive hidden catalog rebuild.
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
        ],
      ),
      bottomNavigationBar: SafeArea(
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
              onDestinationSelected: (value) {
                storefrontTabRequest.value = value;
                if (value == index) return;
                setState(() => index = value);
              },
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
      ),
    );
  }
}
