import 'dart:async';

import 'package:flutter/material.dart';

import 'browser_history.dart';

class MuhajeerNavigatorObserver extends NavigatorObserver {
  bool _handlingBrowserPop = false;
  Timer? _guardRestoreTimer;

  bool _managed(Route<dynamic> route) =>
      (route.settings.name ?? '').startsWith('mb:');

  void _syncSwipeStateAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setBrowserBackSwipeEnabled(navigator?.canPop() ?? false);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_managed(route) && browserHistorySupported) {
      pushBrowserHistoryEntry();
    }
    _syncSwipeStateAfterFrame();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _syncSwipeStateAfterFrame();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _syncSwipeStateAfterFrame();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _syncSwipeStateAfterFrame();
  }

  Future<void> handleBrowserPop(NavigatorState navigator) async {
    if (!browserHistorySupported) return;
    if (_handlingBrowserPop || !navigator.canPop()) return;

    _handlingBrowserPop = true;
    try {
      await navigator.maybePop();
      await WidgetsBinding.instance.endOfFrame;
      setBrowserBackSwipeEnabled(navigator.canPop());

      // Only a native browser pop consumes the fallback guard. For the custom
      // iPhone edge swipe this call is a no-op because the guard is still armed.
      _guardRestoreTimer?.cancel();
      _guardRestoreTimer = Timer(
        const Duration(milliseconds: 360),
        restoreBrowserHistoryGuard,
      );
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
