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
    if (!navigator.canPop()) return;

    _handlingBrowserPop = true;
    try {
      navigator.pop();
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
