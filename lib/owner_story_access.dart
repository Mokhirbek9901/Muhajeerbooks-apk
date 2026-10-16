import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';

/// Story access is matched against a private server-side owner profile.
/// No personal identifiers are compiled into the public app or repository.
///
/// This is a *convenience filter*, not strong identity proof: customers can
/// type any name and phone into their own local profile.
class OwnerStoryAccess extends ChangeNotifier {
  OwnerStoryAccess._();
  static final OwnerStoryAccess instance = OwnerStoryAccess._();

  bool _granted = false;
  String _verifiedName = '';
  String _verifiedPhone = '';
  String? _pendingKey;
  int _generation = 0;

  static String normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('8210')) {
      digits = '0${digits.substring(2)}';
    }
    return digits;
  }

  bool allowedFor(AppState state) =>
      _granted &&
      _verifiedName == normalizeName(state.savedCustomer['name'] ?? '') &&
      _verifiedPhone == normalizePhone(state.savedCustomer['phone'] ?? '');

  void lock() {
    ++_generation; // Discard responses for any previous profile.
    _pendingKey = null;
    final wasGranted = _granted;
    _granted = false;
    _verifiedName = '';
    _verifiedPhone = '';
    if (wasGranted) notifyListeners();
  }

  /// Automatically called when the stored profile is loaded or changed.
  /// Does not require entering the profile tab or signing into admin.
  Future<bool> refreshFor(AppState state) async {
    final name = normalizeName(state.savedCustomer['name'] ?? '');
    final phone = normalizePhone(state.savedCustomer['phone'] ?? '');
    if (!state.backendConfigured || name.isEmpty || phone.isEmpty) {
      lock();
      return false;
    }
    if (_granted && _verifiedName == name && _verifiedPhone == phone) {
      return true;
    }
    final profileKey = '$name|$phone';
    if (_pendingKey == profileKey) return false;
    final generation = ++_generation;
    _pendingKey = profileKey;
    final previouslyGranted = _granted;
    _granted = false;
    _verifiedName = '';
    _verifiedPhone = '';
    if (previouslyGranted) notifyListeners();

    bool verified = false;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'customer-rpc',
        body: {
          'name': 'customer_story_owner_check',
          'params': {'p_name': name, 'p_phone': phone},
        },
      );
      final raw = response.data;
      verified = raw is Map && raw['ok'] == true && raw['data'] == true;
    } catch (_) {
      // Network errors must not affect book browsing.
    }
    if (generation != _generation) return false;
    _pendingKey = null;
    if (name != normalizeName(state.savedCustomer['name'] ?? '') ||
        phone != normalizePhone(state.savedCustomer['phone'] ?? '')) {
      return false;
    }
    _granted = verified;
    if (verified) {
      _verifiedName = name;
      _verifiedPhone = phone;
    }
    notifyListeners();
    // The book detail / set buttons watch AppState rather than this singleton.
    // Refresh those widgets as soon as the server responds.
    state.notifyListeners();
    return verified;
  }
}
