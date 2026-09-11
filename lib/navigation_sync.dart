import 'dart:async';

import 'package:flutter/material.dart';

import 'browser_history.dart';

class MuhajeerNavigatorObserver extends NavigatorObserver {
  bool _handlingBrowserPop = false;
  int _ignoredBrowserPops = 0;

  bool _managed(Route<dynamic> route) =>
      (route.settings.name ?? '').startsWith('mb:');

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_managed(route) && browserHistorySupported) {
      pushBrowserHistoryEntry();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_managed(route) && browserHistorySupported && !_handlingBrowserPop) {
      // Flutter ichidagi back tugmasi bosilganda browser history ham bir qadam
      // orqaga yuradi. Keladigan popstate eventini yana Navigator.pop qilmaslik
      // uchun bir martalik ignore qilamiz.
      _ignoredBrowserPops += 1;
      backBrowserHistoryEntry();
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
      // Safari/iPhone edge-swipe route'ni zo‘rlab removeRoute qilish o‘rniga
      // oddiy pop qiladi. Shunda oldingi Flutter sahifasi mounted holatda qoladi,
      // uning ScrollController pozitsiyasi saqlanadi va sahifa qayta yaratilmaydi.
      await navigator.maybePop();
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
