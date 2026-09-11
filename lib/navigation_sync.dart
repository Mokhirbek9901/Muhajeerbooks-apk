import 'dart:async';

import 'package:flutter/material.dart';

import 'browser_history.dart';

class MuhajeerNavigatorObserver extends NavigatorObserver {
  bool _handlingBrowserPop = false;

  bool _managed(Route<dynamic> route) =>
      (route.settings.name ?? '').startsWith('mb:');

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_managed(route) && browserHistorySupported) {
      // One lightweight Safari guard is enough for all Flutter route depth.
      // This prevents the browser document itself from navigating/reloading.
      pushBrowserHistoryEntry();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Important: do NOT call browser history.back() here.
    // Flutter's own back button must only pop the Flutter route. Moving browser
    // history too caused iPhone Safari to reload and reset the catalogue scroll.
  }

  Future<void> handleBrowserPop(NavigatorState navigator) async {
    if (!browserHistorySupported) return;
    if (_handlingBrowserPop || !navigator.canPop()) return;

    _handlingBrowserPop = true;
    try {
      // Safari has consumed the guard entry. Re-arm it immediately while the
      // current document is still mounted, then pop only the Flutter route.
      // The previous page therefore remains the same widget instance and keeps
      // its exact ScrollController offset.
      restoreBrowserHistoryGuard();
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
