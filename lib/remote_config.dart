import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight server-driven settings.
///
/// Important: this never downloads executable code. It only refreshes data,
/// copy and feature switches for capabilities already shipped in the app.
/// That keeps small operational changes out of the App Store review cycle
/// without bypassing native review requirements.
class RemoteConfigStore extends ChangeNotifier with WidgetsBindingObserver {
  RemoteConfigStore({required this.backendConfigured});

  static const _cacheKey = 'muhajeer_remote_config_v1';

  final bool backendConfigured;
  final Map<String, dynamic> _values = <String, dynamic>{
    'config.refresh_minutes': 15,
    'features.muhajeer_ai_enabled': true,
    'features.preorder_enabled': true,
    'features.reviews_enabled': true,
    'features.restock_enabled': true,
    'features.story_share_enabled': true,
    'ui.notification_permission_title': 'Bildirishnomalarga ruxsat berasizmi?',
    'ui.notification_permission_body':
        'Muhajeer Books yangi xabarlar va muhim yangilanishlarni '
        'sizga bildirishnoma orqali yuborishi uchun ruxsat bering.',
    'ui.notification_permission_allow': 'Ruxsat berish',
    'ui.notification_permission_later': 'Hozir emas',
    'ui.home_announcement_enabled': false,
    'ui.home_announcement_title': '',
    'ui.home_announcement_body': '',
    'release.ios_store_url':
        'https://apps.apple.com/app/muhajeer-books/id6817641775',
    'release.android_store_url':
        'https://play.google.com/store/apps/details?id=com.muhajeerbooks.app',
  };

  Timer? _timer;
  DateTime? _lastRefresh;
  bool _refreshing = false;

  bool get isRefreshing => _refreshing;
  DateTime? get lastRefresh => _lastRefresh;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await _loadCached();
    if (backendConfigured) {
      unawaited(refresh(force: true));
      _scheduleRefresh();
    }
  }

  bool boolValue(String key, {bool fallback = false}) {
    final value = _values[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  int intValue(String key, {int fallback = 0}) {
    final value = _values[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String stringValue(String key, {String fallback = ''}) {
    final value = _values[key];
    if (value == null) return fallback;
    return value.toString();
  }

  Map<String, dynamic> snapshot() => Map<String, dynamic>.unmodifiable(_values);

  Future<void> refresh({bool force = false}) async {
    if (!backendConfigured || _refreshing) return;

    final now = DateTime.now();
    final refreshMinutes =
        intValue('config.refresh_minutes', fallback: 15).clamp(1, 1440).toInt();
    final freshEnough = _lastRefresh != null &&
        now.difference(_lastRefresh!) < Duration(minutes: refreshMinutes);
    if (!force && freshEnough) return;

    _refreshing = true;
    try {
      final raw = await Supabase.instance.client
          .rpc('customer_app_config')
          .timeout(const Duration(seconds: 5));

      if (raw is Map) {
        final remote = Map<String, dynamic>.from(raw);
        if (remote.isNotEmpty) {
          _values.addAll(remote);
          _lastRefresh = now;
          await _saveCached();
          notifyListeners();
          _scheduleRefresh();
        }
      }
    } catch (_) {
      // Cached/default settings keep the storefront fully usable offline.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _values.addAll(Map<String, dynamic>.from(decoded));
        notifyListeners();
      }
    } catch (_) {
      // A bad cache must never block app launch.
    }
  }

  Future<void> _saveCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_values));
    } catch (_) {
      // Remote settings still work for this session if caching fails.
    }
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    final minutes =
        intValue('config.refresh_minutes', fallback: 15).clamp(1, 1440).toInt();
    _timer = Timer.periodic(Duration(minutes: minutes), (_) {
      unawaited(refresh(force: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
