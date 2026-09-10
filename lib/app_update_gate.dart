import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const int _currentApkBuild = int.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: 0,
);

const String _latestManifestUrl =
    'https://github.com/Mokhirbek9901/Muhajeerbooks-apk/releases/download/apk-latest/app-version.json';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForUpdate());
    });
  }

  Future<void> _checkForUpdate() async {
    if (_checked || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _checked = true;

    try {
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
      final message = (data['message'] ?? '').toString().trim();

      if (remoteBuild <= _currentApkBuild || downloadUrl.isEmpty || !mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Yangi versiya mavjud'),
          content: Text(
            [
              if (version.isNotEmpty) 'Muhajeer Books $version tayyor.',
              if (message.isNotEmpty) message,
              'Yangilash tugmasini bossangiz yangi APK ochiladi. Android o‘rnatishni tasdiqlashingizni so‘rashi mumkin.',
            ].join('\n\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Keyinroq'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(downloadUrl);
                if (uri == null) return;
                Navigator.pop(dialogContext);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.system_update_alt_rounded),
              label: const Text('Yangilash'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Update tekshiruvi ishlamasa do‘kon ishlashda davom etadi.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
