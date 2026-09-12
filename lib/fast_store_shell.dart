import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'store_ui.dart';
import 'uzbek_customer_style.dart';

/// Store shell that keeps already-opened tabs alive, but does not build all
/// five storefront pages on first paint. This is especially important on
/// Android browsers where building hidden catalog/category/profile pages at
/// startup adds avoidable layout and image work.
class FastStoreShell extends StatefulWidget {
  const FastStoreShell({super.key});

  @override
  State<FastStoreShell> createState() => _FastStoreShellState();
}

class _FastStoreShellState extends State<FastStoreShell> {
  int index = 0;
  String? _lastPresentedNoticeId;
  final List<bool> _visited = <bool>[true, false, false, false, false];

  Widget _pageFor(int pageIndex) {
    if (!_visited[pageIndex]) return const SizedBox.shrink();
    switch (pageIndex) {
      case 0:
        return const HomePage();
      case 1:
        return const CategoriesPage();
      case 2:
        return const CartPage();
      case 3:
        return const FavoritesPage();
      case 4:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
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
      body: IndexedStack(
        index: index,
        children: List<Widget>.generate(5, _pageFor, growable: false),
      ),
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
            if (value == index) return;
            setState(() {
              _visited[value] = true;
              index = value;
            });
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
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
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
