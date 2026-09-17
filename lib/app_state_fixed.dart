import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';

/// AppState with immediate customer logout and a final live-stock guard
/// before checkout. The database still performs the authoritative atomic
/// stock reservation; this client-side guard keeps stale carts from reaching
/// the order step when Telegram/Instagram sales changed the stock meanwhile.
class AppStateFixed extends AppState {
  AppStateFixed({required super.backendConfigured});

  bool _checkoutChangingCart = false;
  bool get suppressCartStockAlert => _checkoutChangingCart;

  Future<void> _verifyFreshCartStock() async {
    final requested = <String, ({String title, int quantity})>{
      for (final line in cartLines)
        line.book.id: (title: line.book.title, quantity: line.quantity),
    };

    if (requested.isEmpty) {
      throw StateError('Savatcha bo‘sh.');
    }

    final service = backend;
    if (service == null) return;

    // Normal checkoutda global AppState.loading ni yoqib butun storefrontni
    // rebuild qilmaymiz. Live katalog snapshotini jim o‘qib, faqat savatdagi
    // kitoblarni tekshiramiz. Server INSERT trigger baribir oxirgi atomik
    // himoya bo‘lib qoladi.
    Map<String, dynamic> snapshot;
    try {
      snapshot = await service
          .fetchCatalogDelta('1970-01-01T00:00:00Z')
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      throw StateError(
        'Ombordagi oxirgi holatni tekshirib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',
      );
    }

    final rows = snapshot['upserts'];
    if (rows is! List) {
      throw StateError(
        'Ombordagi oxirgi holatni tekshirib bo‘lmadi. Qayta urinib ko‘ring.',
      );
    }

    final liveBooks = <String, Book>{};
    for (final raw in rows.whereType<Map>()) {
      final book = Book.fromMap(Map<String, dynamic>.from(raw));
      if (book.id.isNotEmpty) liveBooks[book.id] = book;
    }

    final soldOut = <String>[];
    final reduced = <String>[];

    for (final entry in requested.entries) {
      final live = liveBooks[entry.key];
      if (live == null || !live.isActive || live.stock <= 0 || live.price <= 0) {
        soldOut.add(entry.value.title);
        continue;
      }
      if (live.stock < entry.value.quantity) {
        reduced.add('“${live.title}” — ${live.stock} dona qoldi');
      }
    }

    if (soldOut.isEmpty && reduced.isEmpty) return;

    // Faqat haqiqiy stock farqi bo‘lsa katalog/savatni yangilaymiz. Normal
    // buyurtmada bu qimmat rebuild umuman bajarilmaydi.
    await refreshBooks();

    final parts = <String>[];
    if (soldOut.isNotEmpty) {
      parts.add(
        soldOut.length == 1
            ? '“${soldOut.first}” hozir omborda qolmagan.'
            : '${soldOut.map((e) => '“$e”').join(', ')} hozir omborda qolmagan.',
      );
    }
    if (reduced.isNotEmpty) {
      parts.add(reduced.join(', '));
    }
    parts.add(
      'Savatcha yangi ombor holatiga moslandi. Qayta tekshirib buyurtma bering.',
    );
    throw StateError(parts.join(' '));
  }

  bool _isStockConflict(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('omborda yetarli emas') ||
        message.contains('omborda qolmagan') ||
        message.contains('sotuvda emas') ||
        message.contains('kitob topilmadi') ||
        message.contains('stock');
  }

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
      // 1) Final tugma bosilgan lahzada live stockni UI'ni bloklamasdan tekshiramiz.
      await _verifyFreshCartStock();

      try {
        // 2) Serverdagi order INSERT trigger ham kitob qatorlarini FOR UPDATE
        // bilan atomik bloklab tekshiradi. Shu ikki qatlam race-conditionni
        // yopadi: tekshiruvdan keyingi millisekundda boshqa savdo bo‘lsa ham
        // ortiqcha buyurtma yaratilmaydi.
        return await super.placeOrder(
          customerName: customerName,
          phone: phone,
          address: address,
          deliveryType: deliveryType,
          deliveryFee: deliveryFee,
          paymentProof: paymentProof,
        );
      } catch (e) {
        if (!_isStockConflict(e)) rethrow;

        // Server ayni paytdagi parallel savdo sabab rad etsa, savatni darhol
        // eng yangi qoldiqqa moslab, mijozga tushunarli xabar qaytaramiz.
        await refreshBooks();
        throw StateError(
          'Ombordagi qoldiq hozirgina o‘zgardi. Ayrim kitoblar tugagan yoki soni kamaygan. Savatcha yangilandi — qayta tekshirib buyurtma bering.',
        );
      }
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
