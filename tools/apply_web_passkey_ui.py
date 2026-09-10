from pathlib import Path

admin = Path('lib/admin_ui.dart')
s = admin.read_text(encoding='utf-8')

if "package:url_launcher/url_launcher.dart" not in s:
    s = s.replace(
        "import 'package:supabase_flutter/supabase_flutter.dart';\n",
        "import 'package:supabase_flutter/supabase_flutter.dart';\nimport 'package:url_launcher/url_launcher.dart';\n",
        1,
    )

old_init = """  @override
  void initState() {
    super.initState();
    unawaited(_prepareBiometric());
  }
"""
new_init = """  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      unawaited(_checkWebAdminSession());
    } else {
      unawaited(_prepareBiometric());
    }
  }
"""
if old_init in s:
    s = s.replace(old_init, new_init, 1)

anchor = """  Future<bool> _deviceHasBiometrics() async {
"""
web_methods = """  Future<void> _checkWebAdminSession() async {
    if (!kIsWeb) return;
    final fragment = Uri.base.fragment;
    if (!fragment.startsWith('admin_session=')) return;
    final token = Uri.decodeComponent(fragment.substring('admin_session='.length));
    if (token.trim().isEmpty) return;
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final api = _AdminApi(token.trim());
      if (!await api.verify()) {
        if (mounted) {
          setState(() => error = 'Face ID / Passkey sessiyasi eskirgan. Qayta kiring.');
        }
        return;
      }
      await _openDashboard(token.trim());
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Face ID / Passkey bilan kirishda xatolik.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openWebPasskey(String mode) async {
    if (!kIsWeb) return;
    final uri = Uri.base.resolve('passkey.html?mode=$mode');
    final ok = await launchUrl(uri, webOnlyWindowName: '_self');
    if (!ok && mounted) {
      setState(() => error = 'Face ID / Passkey oynasi ochilmadi.');
    }
  }

"""
if web_methods.strip() not in s and anchor in s:
    s = s.replace(anchor, web_methods + anchor, 1)

ui_anchor = """                    if (biometricAvailable && biometricEnabled) ...[
"""
web_ui = """                    if (kIsWeb) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: loading ? null : () => _openWebPasskey('login'),
                          icon: const Icon(Icons.face_rounded),
                          label: const Text('Face ID / Passkey bilan kirish'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: loading ? null : () => _openWebPasskey('register'),
                        icon: const Icon(Icons.add_moderator_outlined, size: 19),
                        label: const Text('Face ID / Passkey ni yoqish'),
                      ),
                    ],
"""
if web_ui.strip() not in s and ui_anchor in s:
    s = s.replace(ui_anchor, web_ui + ui_anchor, 1)

admin.write_text(s, encoding='utf-8')

main = Path('lib/main.dart')
m = main.read_text(encoding='utf-8')
if "import 'admin_ui.dart';" not in m:
    m = m.replace("import 'app_update_gate.dart';\n", "import 'app_update_gate.dart';\nimport 'admin_ui.dart';\n", 1)

old_home = """        home: AppUpdateGate(
          child: backendConfigured ? const CustomerAuthGate() : const StoreShell(),
        ),
"""
new_home = """        home: AppUpdateGate(
          child: kIsWeb && Uri.base.fragment.startsWith('admin_session=')
              ? const AdminGatePage()
              : (backendConfigured ? const CustomerAuthGate() : const StoreShell()),
        ),
"""
if old_home in m:
    m = m.replace(old_home, new_home, 1)
main.write_text(m, encoding='utf-8')

print('Web passkey admin UI patch applied')
