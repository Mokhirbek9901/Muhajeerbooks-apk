import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_session.dart';
import 'app_state.dart';

/// One in-memory, admin-verified entitlement bound to the saved customer
/// profile. The owner's name and phone live ONLY in the private backend.
/// Never ship those identifiers or a reversible digest in the app bundle.
class OwnerStoryAccess extends ChangeNotifier {
  OwnerStoryAccess._();
  static final OwnerStoryAccess instance = OwnerStoryAccess._();

  bool _granted = false;
  String _verifiedName = '';
  String _verifiedPhone = '';

  static String normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('8210')) {
      digits = '0${digits.substring(2)}';
    }
    return digits;
  }

  bool allowedFor(AppState state) {
    return _granted &&
        AdminSession.active &&
        _verifiedName.isNotEmpty &&
        _verifiedPhone.isNotEmpty &&
        _verifiedName == normalizeName(state.savedCustomer['name'] ?? '') &&
        _verifiedPhone == normalizePhone(state.savedCustomer['phone'] ?? '');
  }

  void lock() {
    _granted = false;
    _verifiedName = '';
    _verifiedPhone = '';
    notifyListeners();
  }

  /// Run only after successful server-side admin login/Face ID verification.
  /// Not a customer-login check: customerVerified is locally editable.
  Future<bool> verifyAfterAdminLogin(AppState state) async {
    lock();
    final secret = AdminSession.code;
    final name = (state.savedCustomer['name'] ?? '').trim();
    final phone = (state.savedCustomer['phone'] ?? '').trim();
    if (secret == null || secret.isEmpty || name.isEmpty || phone.isEmpty) {
      return false;
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'admin-rpc',
        body: {
          'name': 'admin_story_owner_check',
          'params': {
            'p_secret': secret,
            'p_name': name,
            'p_phone': phone,
          },
        },
      );
      final raw = response.data;
      if (raw is! Map || raw['ok'] != true || raw['data'] != true) {
        return false;
      }
      _verifiedName = normalizeName(name);
      _verifiedPhone = normalizePhone(phone);
      _granted = true;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
