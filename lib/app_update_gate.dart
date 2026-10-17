import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'remote_config.dart';

const int _currentApkBuild = int.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: 0,
);

const bool _playStoreBuild = bool.fromEnvironment('PLAY_STORE_BUILD');
const bool _appStoreBuild = bool.fromEnvironment('APP_STORE_BUILD');

const String _playStoreUrl = String.fromEnvironment(
  'PLAY_STORE_URL',
  defaultValue:
      'https://play.google.com/store/apps/details?id=com.muhajeerbooks.app',
);

const String _appStoreUrl =
    'https://apps.apple.com/app/muhajeer-books/id6817641775';

const String _latestManifestUrl =
    'https://github.com/Mokhirbek9901/Muhajeerbooks-apk/releases/download/apk-latest/app-version.json';

const String _iosLookupUrl =
    'https://itunes.apple.com/lookup?id=6817641775&country=kr';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _dialogOpen = false;
  DateTime? _lastCheck;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForUpdate(force: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkForUpdate(force: true));
    }
  }

  Future<void> _checkForUpdate({bool force = false}) async {
    if ((!_isAndroid && !_isIos) || _checking || _dialogOpen || !mounted) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastCheck != null &&
        now.difference(_lastCheck!) < const Duration(minutes: 5)) {
      return;
    }

    _checking = true;
    _lastCheck = now;
    try {
      final remote = context.read<RemoteConfigStore>();
      await remote.refresh();

      if (!remote.boolValue(
        'release.force_update_enabled',
        fallback: true,
      )) {
        return;
      }

      if (_isIos && _appStoreBuild) {
        await _checkIosAppStore(remote);
        return;
      }

      if (_isAndroid && _playStoreBuild) {
        await _checkGooglePlay(remote);
        return;
      }

      if (_isAndroid) {
        await _checkDirectAndroidBuild(remote);
      }
    } catch (_) {
      // Store/version tekshiruvi vaqtincha ishlamasa ilova bloklanmaydi.
    } finally {
      _checking = false;
    }
  }

  Future<void> _checkIosAppStore(RemoteConfigStore remote) async {
    final package = await PackageInfo.fromPlatform();
    final currentVersion = package.version.trim();
    if (currentVersion.isEmpty) return;

    final response = await http
        .get(Uri.parse(_iosLookupUrl))
        .timeout(const Duration(seconds: 7));
    if (response.statusCode != 200) return;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return;
    final results = decoded['results'];
    if (results is! List || results.isEmpty || results.first is! Map) return;

    final storeVersion =
        Map<String, dynamic>.from(results.first as Map)['version']
            ?.toString()
            .trim() ??
        '';
    if (storeVersion.isEmpty ||
        !_isVersionNewer(storeVersion, currentVersion) ||
        !mounted) {
      return;
    }

    await _showMandatoryUpdate(
      remote: remote,
      version: storeVersion,
      url: remote.stringValue(
        'release.ios_store_url',
        fallback: _appStoreUrl,
      ),
      storeName: 'App Store',
    );
  }

  Future<void> _checkGooglePlay(RemoteConfigStore remote) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!mounted ||
          info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (info.immediateUpdateAllowed) {
        try {
          await InAppUpdate.performImmediateUpdate();
          if (!mounted) return;
          final after = await InAppUpdate.checkForUpdate();
          if (after.updateAvailability != UpdateAvailability.updateAvailable) {
            return;
          }
        } catch (_) {
          // Immediate flow ishlamasa pastdagi majburiy Play Market oynasi qoladi.
        }
      }

      await _showMandatoryUpdate(
        remote: remote,
        version: '',
        url: remote.stringValue(
          'release.android_store_url',
          fallback: _playStoreUrl,
        ),
        storeName: 'Google Play',
      );
    } catch (_) {
      // Play Core mavjud bo'lmagan qurilmada do'kon bloklanmaydi.
    }
  }

  Future<void> _checkDirectAndroidBuild(RemoteConfigStore remote) async {
    final response = await http
        .get(Uri.parse(_latestManifestUrl))
        .timeout(const Duration(seconds: 7));
    if (response.statusCode != 200) return;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return;
    final data = Map<String, dynamic>.from(decoded);
    final remoteBuild = (data['build_number'] as num?)?.toInt() ?? 0;
    final downloadUrl = (data['download_url'] ?? '').toString().trim();
    final version = (data['version'] ?? '').toString().trim();

    if (remoteBuild <= _currentApkBuild || downloadUrl.isEmpty || !mounted) {
      return;
    }

    await _showMandatoryUpdate(
      remote: remote,
      version: version,
      url: downloadUrl,
      storeName: 'yangilanish sahifasi',
    );
  }

  bool _isVersionNewer(String remote, String current) {
    List<int> parts(String value) {
      final clean = value.split(RegExp(r'[-+]')).first;
      return clean
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
    }

    final a = parts(remote);
    final b = parts(current);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final left = i < a.length ? a[i] : 0;
      final right = i < b.length ? b[i] : 0;
      if (left > right) return true;
      if (left < right) return false;
    }
    return false;
  }

  Future<void> _showMandatoryUpdate({
    required RemoteConfigStore remote,
    required String version,
    required String url,
    required String storeName,
  }) async {
    if (_dialogOpen || !mounted || url.trim().isEmpty) return;
    _dialogOpen = true;

    final title = remote.stringValue(
      'release.update_title',
      fallback: 'Yangilanish kerak',
    );
    final body = remote.stringValue(
      'release.update_message',
      fallback:
          'Muhajeer Books yangilandi. Ilovadan foydalanishni davom ettirish '
          'uchun so‘nggi versiyani o‘rnating.',
    );
    final button = remote.stringValue(
      'release.update_button',
      fallback: 'Yangilash',
    );

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(title),
            content: Text(
              [
                if (version.isNotEmpty) 'Yangi versiya: $version',
                body,
                '$storeName orqali yangilang.',
              ].join('\n\n'),
            ),
            actions: [
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(url.trim());
                  if (uri == null) return;
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.system_update_alt_rounded),
                label: Text(button),
              ),
            ],
          ),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
