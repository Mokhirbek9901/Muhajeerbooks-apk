import 'dart:async';

import 'package:flutter/material.dart';

import 'browser_history.dart';

class MuhajeerNavigatorObserver extends NavigatorObserver {
  bool _handlingBrowserPop = false;
  int _ignoredBrowserPops = 0;
  final List<Route<dynamic>> _managedRoutes = <Route<dynamic>>[];

  bool _managed(Route<dynamic> route) =>
      (route.settings.name ?? '').startsWith('mb:');

  void _forgetManaged(Route<dynamic> route) {
    _managedRoutes.remove(route);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_managed(route)) {
      _managedRoutes.add(route);
      if (browserHistorySupported) {
        pushBrowserHistoryEntry();
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _forgetManaged(route);
    if (_managed(route) && browserHistorySupported && !_handlingBrowserPop) {
      // Flutter ichidagi back tugmasi bosilganda browser history ham bir qadam
      // orqaga yuradi. Keladigan popstate eventini yana Navigator.pop qilmaslik
      // uchun bir martalik ignore qilamiz.
      _ignoredBrowserPops += 1;
      backBrowserHistoryEntry();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _forgetManaged(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) _forgetManaged(oldRoute);
    if (newRoute != null && _managed(newRoute)) {
      _managedRoutes.add(newRoute);
    }
  }

  Future<void> handleBrowserPop(NavigatorState navigator) async {
    if (!browserHistorySupported) return;
    if (_ignoredBrowserPops > 0) {
      _ignoredBrowserPops -= 1;
      return;
    }
    if (_handlingBrowserPop || !navigator.canPop()) return;

    _handlingBrowserPop = true;
    try {
      // iPhone/Safari edge-swipe browserning o'zi oldingi sahifani animatsiya
      // qilib ko'rsatadi. Shu paytda yana Navigator.pop animatsiyasi ishlasa,
      // foydalanuvchiga sahifa orqaga ketib yana qaytgandek ko'rinadi.
      //
      // Browser allaqachon history bo'yicha orqaga yurgani uchun joriy managed
      // route'ni animatsiyasiz olib tashlaymiz. Oldingi route mounted qoladi,
      // shuning uchun uning scroll pozitsiyasi ham aynan saqlanadi.
      if (_managedRoutes.isNotEmpty) {
        final route = _managedRoutes.last;
        navigator.removeRoute(route);
        await Future<void>.delayed(Duration.zero);
      } else {
        // Managed stack noma'lum bo'lsa, xavfsiz fallback.
        await navigator.maybePop();
      }
    } finally {
      _handlingBrowserPop = false;
    }
  }
}

class BrowserBackSync extends StatefulWidget {
  const BrowserBackSync({
    super.key,
    required this.navigatorKey,
    required this.observer,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final MuhajeerNavigatorObserver observer;
  final Widget child;

  @override
  State<BrowserBackSync> createState() => _BrowserBackSyncState();
}

class _BrowserBackSyncState extends State<BrowserBackSync> {
  StreamSubscription<void>? _subscription;
  bool _popInFlight = false;

  @override
  void initState() {
    super.initState();
    if (browserHistorySupported) {
      _subscription = browserPopEvents.listen((_) async {
        if (_popInFlight) return;
        final navigator = widget.navigatorKey.currentState;
        if (navigator == null) return;
        _popInFlight = true;
        try {
          await widget.observer.handleBrowserPop(navigator);
        } finally {
          _popInFlight = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
