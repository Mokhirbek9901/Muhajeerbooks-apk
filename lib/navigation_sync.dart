import 'dart:async';

import 'package:flutter/material.dart';

import 'browser_history.dart';

class MuhajeerNavigatorObserver extends NavigatorObserver {
  bool _handlingBrowserPop = false;
  int _ignoredBrowserPops = 0;
  final List<Route<dynamic>> _routeStack = <Route<dynamic>>[];

  bool _managed(Route<dynamic> route) =>
      (route.settings.name ?? '').startsWith('mb:');

  Route<dynamic>? get _topRoute =>
      _routeStack.isEmpty ? null : _routeStack.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _routeStack.remove(route);
    _routeStack.add(route);
    if (_managed(route) && browserHistorySupported) {
      pushBrowserHistoryEntry();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _routeStack.remove(route);
    if (previousRoute != null && !_routeStack.contains(previousRoute)) {
      _routeStack.add(previousRoute);
    }
    if (_managed(route) && browserHistorySupported && !_handlingBrowserPop) {
      _ignoredBrowserPops += 1;
      backBrowserHistoryEntry();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _routeStack.remove(route);
    if (previousRoute != null && !_routeStack.contains(previousRoute)) {
      _routeStack.add(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute == null) {
      if (newRoute != null) _routeStack.add(newRoute);
      return;
    }
    final index = _routeStack.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routeStack.removeAt(index);
      } else {
        _routeStack[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routeStack.add(newRoute);
    }
  }

  Future<void> handleBrowserPop(NavigatorState navigator) async {
    if (!browserHistorySupported) return;
    if (_ignoredBrowserPops > 0) {
      _ignoredBrowserPops -= 1;
      return;
    }
    if (!navigator.canPop()) return;

    _handlingBrowserPop = true;
    try {
      final route = _topRoute;

      // iPhone/Safari chapdan swipe qilganda brauzerning o‘zi allaqachon
      // orqaga qaytish animatsiyasini ko‘rsatadi. Shu payt Navigator.pop()
      // ishlatilsa Flutter ham ikkinchi reverse animatsiyani bajaradi va sahifa
      // "yangilangandek" lipillaydi. Managed storefront route'ni darhol olib
      // tashlash browser gesture'dan keyingi ikkinchi animatsiyani yo‘q qiladi.
      if (route != null && _managed(route)) {
        navigator.removeRoute(route);
      } else {
        navigator.pop();
      }
      await Future<void>.delayed(Duration.zero);
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

  @override
  void initState() {
    super.initState();
    if (browserHistorySupported) {
      _subscription = browserPopEvents.listen((_) {
        final navigator = widget.navigatorKey.currentState;
        if (navigator != null) {
          unawaited(widget.observer.handleBrowserPop(navigator));
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
