import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks time outside the app, not time spent reading a book inside it.
class CatalogResume extends ChangeNotifier with WidgetsBindingObserver {
  CatalogResume({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  static final instance = CatalogResume();
  static const awayKey = 'catalog:awayAt';
  static const timeout = Duration(minutes: 1);
  DateTime? _awayAt;
  bool _adminPanelActive = false;
  bool get adminPanelActive => _adminPanelActive;
  void setAdminPanelActive(bool value) => _adminPanelActive = value;
  late SharedPreferences _prefs;

  static bool expired(DateTime leftAt, DateTime now) =>
      now.difference(leftAt) > timeout;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getInt(awayKey);
    if (saved == null ||
        expired(DateTime.fromMillisecondsSinceEpoch(saved), _now())) {
      await _clearSavedScroll();
    }
    await _prefs.remove(awayKey);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _clearSavedScroll() async {
    final keys = _prefs.getKeys().where((key) => key.startsWith('scroll:')).toList();
    if (keys.isEmpty) return;
    await Future.wait(keys.map(_prefs.remove));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _awayAt ??= _now();
      unawaited(_prefs.setInt(awayKey, _awayAt!.millisecondsSinceEpoch));
    } else if (state == AppLifecycleState.resumed) {
      final leftAt = _awayAt;
      _awayAt = null;
      unawaited(_prefs.remove(awayKey));
      if (leftAt != null &&
          expired(leftAt, _now()) &&
          !_adminPanelActive) {
        // Notify synchronously so a pending scroll restore cannot win the race.
        notifyListeners();
        unawaited(_clearSavedScroll());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
