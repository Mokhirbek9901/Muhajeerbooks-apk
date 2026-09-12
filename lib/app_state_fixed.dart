import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';

/// AppState with an immediate customer logout for web/APK.
/// Local customer data is cleared first so the UI reacts instantly;
/// remote Supabase sign-out is allowed to finish in the background.
class AppStateFixed extends AppState {
  AppStateFixed({required super.backendConfigured});

  bool _checkoutChangingCart = false;
  bool get suppressCartStockAlert => _checkoutChangingCart;

  @override
  Future<String> placeOrder({
    required String customerName,
    required String phone,
    required String address,
    required String deliveryType,
    required int deliveryFee,
    XFile? paymentProof,
  }) async {
    _checkoutChangingCart = true;
    try {
      return await super.placeOrder(
        customerName: customerName,
        phone: phone,
        address: address,
        deliveryType: deliveryType,
        deliveryFee: deliveryFee,
        paymentProof: paymentProof,
      );
    } finally {
      _checkoutChangingCart = false;
    }
  }

  @override
  Future<void> signOutCustomer() async {
    // 1) UI darhol mehmon holatiga o'tadi.
    savedCustomer = const {'name': '', 'phone': '', 'address': ''};
    customerVerified = false;
    notifyListeners();

    // 2) Qurilmada/brauzerda saqlangan mijoz ma'lumotlarini o'chiramiz.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('muhajeer_customer_name');
    await prefs.remove('muhajeer_customer_phone');
    await prefs.remove('muhajeer_customer_address');
    await prefs.setBool('muhajeer_customer_verified_v1', false);

    // 3) Supabase auth lokal logoutni bloklamaydi.
    if (backendConfigured) {
      unawaited(_remoteSignOut());
    }
  }

  Future<void> _remoteSignOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Local logout allaqachon bajarilgan; tarmoq xatosi foydalanuvchini ushlab qolmaydi.
    }
  }
}
