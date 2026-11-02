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
import 'ios_update_version.dart';
import 'store_distribution.dart';

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
  Timer? _periodicUpdateCheck;

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
    // Public releases can appear while the app remains open. Keep
    // rechecking without requiring customers to restart the app.
    _periodicUpdateCheck = Timer.periodic(const Duration(minutes: 15), (_) {
      if (mounted) unawaited(_checkForUpdate(force: true));
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
      // RemoteConfigStore may already be fetching on app launch. Its
      // refresh() returns immediately in that case, leaving old cached
      // release info behind. Wait briefly for the in-flight fetch.
      for (var attempt = 0; attempt < 20 && remote.isRefreshing; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (!mounted) return;
      await remote.refresh(force: true);
      if (!mounted) return;

      if (!remote.boolValue(
        'release.force_update_enabled',
        fallback: true,
      )) {
        return;
      }

      if (_isIos && _appStoreBuild) {
        // iOS TestFlight binaries use APP_STORE_BUILD=true as well. Never
        // compare a beta install to the public App Store release.
        final distribution = await iosInstallationPlatform();
        if (!mounted) return;
        if (distribution == 'ios_testflight') {
          await _checkIosTestFlight(remote);
        } else {
          await _checkIosAppStore(remote);
        }
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

  /// Check only the latest validated, internally distributed TestFlight
  /// build recorded by the release operator. No guessed build numbers:
  /// a beta must be available in TestFlight before remote config is updated.
  Future<void> _checkIosTestFlight(RemoteConfigStore remote) async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version.trim();
    final currentBuild = int.tryParse(info.buildNumber.trim()) ?? 0;
    final betaVersion = remote.stringValue(
      'release.ios_testflight_version', fallback: '',
    ).trim();
    final betaBuild = remote.intValue(
      'release.ios_testflight_build', fallback: 0,
    );
    if (betaBuild <= 0 || betaVersion.isEmpty || !mounted) return;
    if (!iosPublishedUpdateAvailable(
      installedVersion: currentVersion,
      installedBuild: currentBuild,
      publishedVersion: betaVersion,
      publishedBuild: betaBuild,
    )) return;

    await _showMandatoryUpdate(
      remote: remote,
      version: betaVersion,
      url: remote.stringValue(
        'release.ios_testflight_url',
        fallback: 'https://testflight.apple.com/',
      ),
      storeName: 'TestFlight',
      buttonOverride: 'TestFlight’da yangilash',
      messageOverride: 'Muhajeer Books uchun yangi sinov versiyasi bor. '
          'TestFlight ilovasini ochib, Muhajeer Books yonidagi '
          '“Update / Yangilash” tugmasini bosing.',
    );
  }

  Future<void> _checkIosAppStore(RemoteConfigStore remote) async {
    final package = await PackageInfo.fromPlatform();
    final installedVersion = package.version.trim();
    final installedBuild = int.tryParse(package.buildNumber.trim()) ?? 0;
    if (installedVersion.isEmpty) return;

    // Verified by the release operator only after Apple reports READY_FOR_SALE.
    // This also handles same-marketing-version App Store build updates.
    final approvedVersion = remote.stringValue(
      'release.ios_published_version',
      fallback: '',
    ).trim();
    final approvedBuild = remote.intValue(
      'release.ios_published_build',
      fallback: 0,
    );

    // Apple's public lookup is the primary source for marketing versions.
    // If it is temporarily unreachable, the last server-verified release
    // still allows older installed versions to reach the update screen.
    var lookupVersion = '';
    try {
      final response = await http
          .get(Uri.parse(_iosLookupUrl),
              headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final results = decoded['results'];
          if (results is List && results.isNotEmpty && results.first is Map) {
            final result = Map<String, dynamic>.from(results.first as Map);
            if (result['bundleId'] == 'com.muhajeerbooks.app') {
              lookupVersion = '${result['version'] ?? ''}'.trim();
            }
          }
        }
      }
    } catch (_) {
      // The verified release config remains available if Apple is offline.
    }

    var publishedVersion = approvedVersion;
    if (lookupVersion.isNotEmpty &&
        (publishedVersion.isEmpty ||
            compareIosMarketingVersions(lookupVersion, publishedVersion) > 0)) {
      publishedVersion = lookupVersion;
    }
    // The build number applies only to its exact published marketing version.
    final publishedBuild =
        publishedVersion == approvedVersion ? approvedBuild : 0;
    if (!iosPublishedUpdateAvailable(
          installedVersion: installedVersion,
          installedBuild: installedBuild,
          publishedVersion: publishedVersion,
          publishedBuild: publishedBuild,
        ) ||
        !mounted) {
      return;
    }

    await _showMandatoryUpdate(
      remote: remote,
      version: publishedVersion,
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

  Future<void> _showMandatoryUpdate({
    required RemoteConfigStore remote,
    required String version,
    required String url,
    required String storeName,
    String? buttonOverride,
    String? messageOverride,
  }) async {
    if (_dialogOpen || !mounted || url.trim().isEmpty) return;
    _dialogOpen = true;

    final title = remote.stringValue(
      'release.update_title',
      fallback: 'Yangilanish kerak',
    );
    final body = messageOverride ?? remote.stringValue(
      'release.update_message',
      fallback:
          'Muhajeer Books yangilandi. Ilovadan foydalanishni davom ettirish '
          'uchun so‘nggi versiyani o‘rnating.',
    );
    final button = buttonOverride ?? remote.stringValue(
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
    _periodicUpdateCheck?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
