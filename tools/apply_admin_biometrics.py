from pathlib import Path
import re

ADMIN = Path('lib/admin_ui.dart')
FINANCE = Path('lib/finance_admin.dart')
PUBSPEC = Path('pubspec.yaml')
ANDROID_WORKFLOW = Path('.github/workflows/android_build.yml')

s = ADMIN.read_text(encoding='utf-8')

# Imports needed only by native biometric login. Web is gated with kIsWeb.
if "package:flutter/foundation.dart" not in s:
    s = s.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';\n",
        1,
    )
if "package:flutter_secure_storage/flutter_secure_storage.dart" not in s:
    s = s.replace(
        "import 'package:flutter/services.dart';\n",
        "import 'package:flutter/services.dart';\nimport 'package:flutter_secure_storage/flutter_secure_storage.dart';\n",
        1,
    )
if "package:local_auth/local_auth.dart" not in s:
    s = s.replace(
        "import 'package:intl/intl.dart';\n",
        "import 'package:intl/intl.dart';\nimport 'package:local_auth/local_auth.dart';\n",
        1,
    )
if "package:shared_preferences/shared_preferences.dart" not in s:
    s = s.replace(
        "import 'package:provider/provider.dart';\n",
        "import 'package:provider/provider.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\n",
        1,
    )

start_marker = 'class _AdminGatePageState extends State<AdminGatePage> {'
build_marker = '  @override\n  Widget build(BuildContext context) {'
start = s.index(start_marker)
build = s.index(build_marker, start)

new_state = '''class _AdminGatePageState extends State<AdminGatePage> {
  static const _biometricPreferenceKey = 'muhajeer_admin_biometrics_v1';
  static const _secureAdminCodeKey = 'muhajeer_admin_code_v1';

  final code = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool loading = false;
  bool biometricLoading = false;
  bool biometricAvailable = false;
  bool biometricEnabled = false;
  bool obscure = true;
  String? error;

  bool get _nativeBiometrics {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_prepareBiometric());
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<bool> _deviceHasBiometrics() async {
    if (!_nativeBiometrics) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      return supported && canCheck && available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _prepareBiometric() async {
    if (!_nativeBiometrics) return;
    final available = await _deviceHasBiometrics();
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        available && (prefs.getBool(_biometricPreferenceKey) ?? false);
    if (!mounted) return;
    setState(() {
      biometricAvailable = available;
      biometricEnabled = enabled;
    });
    if (enabled) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 450), () async {
        if (mounted) await _biometricLogin();
      }));
    }
  }

  Future<void> _openDashboard(String secret) async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AdminDashboardPage(secret: secret)),
    );
  }

  Future<void> _saveBiometricSecret(String secret) async {
    if (!_nativeBiometrics) return;
    final available = await _deviceHasBiometrics();
    if (!available) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyEnabled = prefs.getBool(_biometricPreferenceKey) ?? false;
    if (alreadyEnabled) {
      await _secureStorage.write(key: _secureAdminCodeKey, value: secret);
      if (mounted) {
        setState(() {
          biometricAvailable = true;
          biometricEnabled = true;
        });
      }
      return;
    }

    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Face ID / biometrik kirish'),
        content: const Text(
          'Keyingi safar admin kodini yozmasdan Face ID yoki barmoq izi bilan kirishni yoqasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hozir emas'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Yoqish'),
          ),
        ],
      ),
    );
    if (enable != true) return;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Admin panel uchun biometrik kirishni tasdiqlang',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated) return;
      await _secureStorage.write(key: _secureAdminCodeKey, value: secret);
      await prefs.setBool(_biometricPreferenceKey, true);
      if (mounted) {
        setState(() {
          biometricAvailable = true;
          biometricEnabled = true;
        });
      }
    } catch (_) {
      // Kod bilan kirish har doim zaxira usul bo‘lib qoladi.
    }
  }

  Future<void> _biometricLogin() async {
    if (!_nativeBiometrics || biometricLoading || loading) return;
    setState(() {
      biometricLoading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_biometricPreferenceKey) ?? false)) return;

      final storedSecret = await _secureStorage.read(key: _secureAdminCodeKey);
      if (storedSecret == null || storedSecret.trim().isEmpty) {
        await prefs.setBool(_biometricPreferenceKey, false);
        if (mounted) {
          setState(() {
            biometricEnabled = false;
            error = 'Biometrik kirishni qayta yoqish uchun avval admin kodi bilan kiring.';
          });
        }
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Muhajeer Books admin paneliga kirish',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated) return;

      final api = _AdminApi(storedSecret.trim());
      if (!await api.verify()) {
        await _secureStorage.delete(key: _secureAdminCodeKey);
        await prefs.setBool(_biometricPreferenceKey, false);
        if (mounted) {
          setState(() {
            biometricEnabled = false;
            error = 'Admin kodi o‘zgargan. Yangi kod bilan bir marta kiring.';
          });
        }
        return;
      }
      await _openDashboard(storedSecret.trim());
    } on PlatformException {
      if (mounted) {
        setState(() {
          error = 'Face ID / biometrik tekshiruv ishlamadi. Kod bilan kiring.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Biometrik kirishda xatolik. Kod bilan kiring.';
        });
      }
    } finally {
      if (mounted) setState(() => biometricLoading = false);
    }
  }

  Future<void> _login() async {
    final value = code.text.trim();
    if (value.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = _AdminApi(value);
      if (!await api.verify()) {
        if (mounted) setState(() => error = 'Admin kodi noto‘g‘ri.');
        return;
      }
      await _saveBiometricSecret(value);
      await _openDashboard(value);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Kirishda xatolik. Internetni tekshiring.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

'''
s = s[:start] + new_state + s[build:]

button_anchor = '''                    ),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,'''
button_replacement = '''                    ),
                    if (biometricAvailable && biometricEnabled) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: biometricLoading ? null : _biometricLogin,
                          icon: biometricLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.fingerprint_rounded),
                          label: Text(
                            biometricLoading
                                ? 'Tekshirilmoqda...'
                                : 'Face ID / biometrika bilan kirish',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,'''
if button_anchor not in s:
    raise SystemExit('Admin biometric button anchor not found')
s = s.replace(button_anchor, button_replacement, 1)
ADMIN.write_text(s, encoding='utf-8')

# Replace piggy-bank-like icon with a neutral wallet icon.
f = FINANCE.read_text(encoding='utf-8')
old_icon = '''? Icons.savings_outlined
                        : Icons.trending_down_rounded,'''
new_icon = '''? Icons.account_balance_wallet_outlined
                        : Icons.trending_down_rounded,'''
if old_icon not in f:
    raise SystemExit('Finance profit icon anchor not found')
f = f.replace(old_icon, new_icon, 1)
FINANCE.write_text(f, encoding='utf-8')

# Native biometric packages and release version.
p = PUBSPEC.read_text(encoding='utf-8')
p = re.sub(r'^version:\s*[^\n]+', 'version: 2.5.2+9', p, count=1, flags=re.M)
if '  local_auth:' not in p:
    p = p.replace(
        '  http: ^1.2.2\n',
        '  http: ^1.2.2\n  local_auth: ^2.3.0\n  flutter_secure_storage: ^9.2.4\n',
        1,
    )
PUBSPEC.write_text(p, encoding='utf-8')

# Android files are regenerated by CI, so patch them after flutter create.
w = ANDROID_WORKFLOW.read_text(encoding='utf-8')
if 'Prepare Android biometrics' not in w:
    anchor = '      - name: Apply official Muhajeer launcher icon\n'
    step = '''      - name: Prepare Android biometrics
        run: |
          python3 tools/prepare_android_biometrics.py

'''
    if anchor not in w:
        raise SystemExit('Android workflow anchor not found')
    w = w.replace(anchor, step + anchor, 1)
ANDROID_WORKFLOW.write_text(w, encoding='utf-8')

print('Admin biometrics patch applied')
