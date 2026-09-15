import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminResumeSnapshot {
  const AdminResumeSnapshot({required this.secret, required this.tab});

  final String secret;
  final int tab;
}

class AdminResumeSession {
  AdminResumeSession._();

  static const timeout = Duration(minutes: 10);
  static const _secretKey = 'muhajeer_admin_resume_secret_v2';
  static const _activeKey = 'muhajeer_admin_resume_active_v2';
  static const _seenAtKey = 'muhajeer_admin_resume_seen_at_v2';
  static const _tabKey = 'muhajeer_admin_resume_tab_v2';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<void> start(String secret, {required int tab}) async {
    final value = secret.trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      _secure.write(key: _secretKey, value: value),
      prefs.setBool(_activeKey, true),
      prefs.setInt(_seenAtKey, DateTime.now().millisecondsSinceEpoch),
      prefs.setInt(_tabKey, tab.clamp(0, 7).toInt()),
    ]);
  }

  static Future<void> touch({required int tab}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_activeKey) ?? false)) return;
    await Future.wait([
      prefs.setInt(_seenAtKey, DateTime.now().millisecondsSinceEpoch),
      prefs.setInt(_tabKey, tab.clamp(0, 7).toInt()),
    ]);
  }

  static Future<AdminResumeSnapshot?> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_activeKey) ?? false)) return null;

      final seenAt = prefs.getInt(_seenAtKey);
      if (seenAt == null) {
        await clear();
        return null;
      }
      final lastSeen = DateTime.fromMillisecondsSinceEpoch(seenAt);
      final age = DateTime.now().difference(lastSeen);
      if (age.isNegative || age > timeout) {
        await clear();
        return null;
      }

      final secret = (await _secure.read(key: _secretKey) ?? '').trim();
      if (secret.isEmpty) {
        await clear();
        return null;
      }
      final tab = (prefs.getInt(_tabKey) ?? 0).clamp(0, 7).toInt();
      return AdminResumeSnapshot(secret: secret, tab: tab);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        _secure.delete(key: _secretKey),
        prefs.remove(_activeKey),
        prefs.remove(_seenAtKey),
        prefs.remove(_tabKey),
      ]);
    } catch (_) {
      // Resume cache ishlamasa adminning o'zi ishlashda davom etadi.
    }
  }
}
