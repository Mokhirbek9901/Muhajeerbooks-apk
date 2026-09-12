import 'dart:async';

import 'package:flutter/material.dart';

import 'browser_history.dart';

class MuhajeerNavigatorObserver extends NavigatorObserver {
  bool _handlingBrowserPop = false;
  Timer? _guardRestoreTimer;

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
    // Flutter's own back button only pops Flutter. Browser history is moved only
    // by Safari's native edge swipe, never by the in-app back button.
  }

  Future<void> handleBrowserPop(NavigatorState navigator) async {
    if (!browserHistorySupported) return;
    if (_handlingBrowserPop || !navigator.canPop()) return;

    _handlingBrowserPop = true;
    try {
      // Show the previous Flutter screen immediately when Safari finishes the
      // edge swipe. Do NOT push a new history entry while Safari is still
      // completing its native interactive animation: on iPhone that can expose
      // Safari's blank page snapshot for a moment (white/cream flash).
      await navigator.maybePop();

      // Re-arm the single guard only after Safari's own animation has settled.
      // pushState itself is invisible once the gesture is over, so the user sees
      // the previous screen continuously instead of a blank frame first.
      _guardRestoreTimer?.cancel();
      _guardRestoreTimer = Timer(
        const Duration(milliseconds: 320),
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
