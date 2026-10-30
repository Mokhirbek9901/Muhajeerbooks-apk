import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'admin_resume_session.dart';
import 'admin_ui.dart' show AdminGatePage, AdminDashboardPage, AdminPreorderInboxPage;
import 'native_admin_push.dart';
import 'native_android_push.dart';
import 'customer_pin_page.dart';
import 'store_ui.dart' show MyOrdersPage, CustomerNotificationsPage;
import 'preorder_balance_page.dart' show CustomerPreorderBalancesPage;

class NativeCustomerNotificationBridge extends StatefulWidget {
  const NativeCustomerNotificationBridge({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<NativeCustomerNotificationBridge> createState() =>
      _NativeCustomerNotificationBridgeState();
}

class _NativeCustomerNotificationBridgeState
    extends State<NativeCustomerNotificationBridge> {
  static const channel = MethodChannel('muhajeerbooks/admin_apns');
  bool opening = false;
  StreamSubscription<void>? _androidTokens;
  StreamSubscription<Map<String, String>>? _androidTaps;
  @override
  void initState() {
    super.initState();
    if (NativeAndroidPush.supported) {
      _androidTokens = NativeAndroidPush.tokenChanges.listen((_) {
        if (mounted) unawaited(context.read<AppState>().syncNativeCustomerPushIfAllowed());
      });
      _androidTaps = NativeAndroidPush.notificationTaps.listen((message) {
        unawaited(_openAndroidMessage(message));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final message = await NativeAndroidPush.pendingNotification();
          if (message != null && mounted) await _openAndroidMessage(message);
        } catch (_) {}
      });
      return;
    }
    if (!NativeAdminPush.supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'adminOrderTapped')
        await openAdminOrders();
      if (call.method == 'customerOrderTapped')
        await open('${call.arguments ?? ''}');
      if (call.method == 'adminPreorderTapped')
        await openAdminPreorders();
      if (call.method == 'customerPreorderTapped')
        await openPreorders('${call.arguments ?? ''}');
      if (call.method == 'tokenUpdated' && mounted)
        unawaited(context.read<AppState>().syncNativeCustomerPushIfAllowed());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final pendingAdmin = await channel.invokeMethod<bool>('getPendingAdminOrder');
        if (pendingAdmin == true && mounted) await openAdminOrders();
      } catch (_) {}
      try {
        final id = await channel.invokeMethod<String>(
          'getPendingCustomerOrder',
        );
        if (id != null && id.isNotEmpty) await open(id);
      } catch (_) {}
      try {
        final pending = await channel.invokeMethod<bool>('getPendingAdminPreorder');
        if (pending == true && mounted) await openAdminPreorders();
      } catch (_) {}
      try {
        final id = await channel.invokeMethod<String>('getPendingCustomerPreorder');
        if (id != null && id.isNotEmpty) await openPreorders(id);
      } catch (_) {}
    });
  }

  Future<void> _openAndroidMessage(Map<String, String> message) async {
    if (!mounted) return;
    if (message['kind'] == 'admin_preorder') {
      await openAdminPreorders();
    } else if (message['kind'] == 'customer_preorder') {
      await openPreorders(message['preorder_id'] ?? '');
    } else if (message['kind'] == 'admin_new_order') {
      await openAdminOrders();
    } else if (message['kind'] == 'customer_order') {
      await open(message['order_id'] ?? '');
    } else if (message['kind'] == 'customer_broadcast' && !opening) {
      final nav = widget.navigatorKey.currentState;
      if (nav == null) return;
      opening = true;
      try {
        await nav.push(MaterialPageRoute<void>(builder: (_) => const CustomerNotificationsPage()));
      } finally {
        opening = false;
      }
    }
  }

  Future<void> openAdminPreorders() async {
    if (opening || !mounted) return;
    opening = true;
    try {
      final nav = widget.navigatorKey.currentState;
      if (nav == null) return;
      final snapshot = await AdminResumeSession.restore();
      if (!mounted) return;
      await nav.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'mb:admin-push-preorders'),
        builder: (_) => snapshot == null
            ? const AdminGatePage()
            : AdminPreorderInboxPage(secret: snapshot.secret),
      ));
    } finally {
      opening = false;
    }
  }

  Future<void> openPreorders(String id) async {
    if (opening || !mounted ||
        !(RegExp(r'^[0-9]+
    if (opening || !mounted) return;
    opening = true;
    try {
      final nav = widget.navigatorKey.currentState;
      if (nav == null) return;
      final snapshot = await AdminResumeSession.restore();
      if (!mounted) return;
      await nav.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'mb:admin-push-orders'),
        builder: (_) => snapshot == null
            ? const AdminGatePage()
            : AdminDashboardPage(secret: snapshot.secret, initialTab: 3),
      ));
    } finally {
      opening = false;
    }
  }

  Future<void> open(String id) async {
    if (opening || !mounted || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
      return;
    opening = true;
    try {
      final nav = widget.navigatorKey.currentState;
      final ctx = nav?.overlay?.context;
      if (nav == null || ctx == null) return;
      if (!await ensureCustomerCheckoutIdentity(ctx) || !mounted) return;
      await context.read<AppState>().refreshPinOrderHistory();
      if (mounted)
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) => MyOrdersPage(focusOrderId: id),
          ),
        );
    } finally {
      opening = false;
    }
  }

  @override
  void dispose() {
    unawaited(_androidTokens?.cancel());
    unawaited(_androidTaps?.cancel());
    if (NativeAdminPush.supported) channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
).hasMatch(id) ||
          RegExp(r'^[0-9a-fA-F-]{36}
    if (opening || !mounted) return;
    opening = true;
    try {
      final nav = widget.navigatorKey.currentState;
      if (nav == null) return;
      final snapshot = await AdminResumeSession.restore();
      if (!mounted) return;
      await nav.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'mb:admin-push-orders'),
        builder: (_) => snapshot == null
            ? const AdminGatePage()
            : AdminDashboardPage(secret: snapshot.secret, initialTab: 3),
      ));
    } finally {
      opening = false;
    }
  }

  Future<void> open(String id) async {
    if (opening || !mounted || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
      return;
    opening = true;
    try {
      final nav = widget.navigatorKey.currentState;
      final ctx = nav?.overlay?.context;
      if (nav == null || ctx == null) return;
      if (!await ensureCustomerCheckoutIdentity(ctx) || !mounted) return;
      await context.read<AppState>().refreshPinOrderHistory();
      if (mounted)
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) => MyOrdersPage(focusOrderId: id),
          ),
        );
    } finally {
      opening = false;
    }
  }

  @override
  void dispose() {
    unawaited(_androidTokens?.cancel());
    unawaited(_androidTaps?.cancel());
    if (NativeAdminPush.supported) channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
).hasMatch(id))) return;
    opening = true;
    try {
      final nav = widget.navigatorKey.currentState;
      final ctx = nav?.overlay?.context;
      if (nav == null || ctx == null) return;
      if (!await ensureCustomerCheckoutIdentity(ctx) || !mounted) return;
      await nav.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'mb:customer-push-preorders'),
        builder: (_) => CustomerPreorderBalancesPage(focusPreorderId: id),
      ));
    } finally {
      opening = false;
    }
  }

  Future<void> openAdminOrders() async {
    if (opening || !mounted) return;
    opening = true;
    try {
      final nav = widget.navigatorKey.currentState;
      if (nav == null) return;
      final snapshot = await AdminResumeSession.restore();
      if (!mounted) return;
      await nav.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'mb:admin-push-orders'),
        builder: (_) => snapshot == null
            ? const AdminGatePage()
            : AdminDashboardPage(secret: snapshot.secret, initialTab: 3),
      ));
    } finally {
      opening = false;
    }
  }

  Future<void> open(String id) async {
    if (opening || !mounted || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
      return;
    opening = true;
    try {
      final nav = widget.navigatorKey.currentState;
      final ctx = nav?.overlay?.context;
      if (nav == null || ctx == null) return;
      if (!await ensureCustomerCheckoutIdentity(ctx) || !mounted) return;
      await context.read<AppState>().refreshPinOrderHistory();
      if (mounted)
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) => MyOrdersPage(focusOrderId: id),
          ),
        );
    } finally {
      opening = false;
    }
  }

  @override
  void dispose() {
    unawaited(_androidTokens?.cancel());
    unawaited(_androidTaps?.cancel());
    if (NativeAdminPush.supported) channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
