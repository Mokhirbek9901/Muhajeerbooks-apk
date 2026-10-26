import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'native_admin_push.dart';
import 'customer_pin_page.dart';
import 'store_ui.dart' show MyOrdersPage;

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
  @override
  void initState() {
    super.initState();
    if (!NativeAdminPush.supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'customerOrderTapped')
        await open('${call.arguments ?? ''}');
      if (call.method == 'tokenUpdated' && mounted)
        unawaited(context.read<AppState>().syncNativeCustomerPushIfAllowed());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final id = await channel.invokeMethod<String>(
          'getPendingCustomerOrder',
        );
        if (id != null && id.isNotEmpty) await open(id);
      } catch (_) {}
    });
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
    if (NativeAdminPush.supported) channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
