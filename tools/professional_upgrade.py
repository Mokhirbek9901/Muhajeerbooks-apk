from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Pattern not found in {path}: {old[:120]!r}')
    text = text.replace(old, new, 1)
    p.write_text(text, encoding='utf-8')


# ---------------- AUTH GATE ----------------
auth_gate = r'''import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'brand.dart';
import 'design_system.dart';
import 'store_ui.dart';

/// Phone OTP is ready in the app. Keep this false until a Supabase SMS provider
/// is enabled, so customers are never locked out by missing third-party SMS
/// credentials. Enable at build time with --dart-define=REQUIRE_PHONE_AUTH=true.
const bool requirePhoneAuth = bool.fromEnvironment(
  'REQUIRE_PHONE_AUTH',
  defaultValue: false,
);

class CustomerAuthGate extends StatefulWidget {
  const CustomerAuthGate({super.key});

  @override
  State<CustomerAuthGate> createState() => _CustomerAuthGateState();
}

class _CustomerAuthGateState extends State<CustomerAuthGate> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController();
  StreamSubscription<AuthState>? _authSub;
  bool sending = false;
  bool verifying = false;
  bool codeSent = false;
  String normalizedPhone = '';
  String? error;

  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _authSub = client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
    if (client.auth.currentSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateExisting());
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    name.dispose();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  String _normalizeKoreanPhone(String input) {
    final raw = input.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (raw.startsWith('+')) return '+$digits';
    if (digits.startsWith('82')) return '+$digits';
    if (digits.startsWith('0')) return '+82${digits.substring(1)}';
    return '+82$digits';
  }

  Future<void> _hydrateExisting() async {
    final user = client.auth.currentUser;
    if (user == null || !mounted) return;
    try {
      final row = await client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', user.id)
          .maybeSingle();
      final displayName = (row?['full_name'] ?? '').toString();
      final displayPhone = (row?['phone'] ?? user.phone ?? '').toString();
      await client.rpc('customer_register_session', params: {'p_name': displayName});
      if (!mounted) return;
      await context.read<AppState>().setAuthenticatedCustomer(
            displayName,
            displayPhone,
          );
    } catch (_) {
      // Session is still valid; analytics/profile sync can retry next launch.
    }
  }

  Future<void> _sendCode() async {
    final fullName = name.text.trim();
    final value = _normalizeKoreanPhone(phone.text);
    if (fullName.length < 2) {
      setState(() => error = 'Ism va familiyangizni kiriting.');
      return;
    }
    if (value.length < 10) {
      setState(() => error = 'Telefon raqamingizni to‘liq kiriting.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await client.auth.signInWithOtp(phone: value);
      if (!mounted) return;
      setState(() {
        normalizedPhone = value;
        codeSent = true;
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'SMS yuborilmadi: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _verify() async {
    final token = code.text.replaceAll(RegExp(r'\D'), '');
    if (token.length != 6) {
      setState(() => error = 'SMS orqali kelgan 6 xonali kodni kiriting.');
      return;
    }
    setState(() {
      verifying = true;
      error = null;
    });
    try {
      final response = await client.auth.verifyOTP(
        type: OtpType.sms,
        token: token,
        phone: normalizedPhone,
      );
      if (response.session == null) {
        throw const AuthException('Tasdiqlash yakunlanmadi.');
      }
      await client.rpc(
        'customer_register_session',
        params: {'p_name': name.text.trim()},
      );
      await context.read<AppState>().setAuthenticatedCustomer(
            name.text.trim(),
            normalizedPhone,
          );
      if (mounted) setState(() {});
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Kod tasdiqlanmadi: $e');
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!requirePhoneAuth || client.auth.currentSession != null) {
      return const StoreShell();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: MuhajeerLogoBadge(size: 92, radius: 24)),
                        const SizedBox(height: 16),
                        Text(
                          codeSent ? 'SMS kodni tasdiqlang' : 'Muhajeer Books’ga kirish',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          codeSent
                              ? '$normalizedPhone raqamiga kelgan 6 xonali kodni kiriting.'
                              : 'Ismingiz va Koreya telefon raqamingiz kifoya. Parol kerak emas.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted, height: 1.45),
                        ),
                        const SizedBox(height: 22),
                        if (!codeSent) ...[
                          TextField(
                            controller: name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Ism va familiya',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            onSubmitted: (_) => _sendCode(),
                            decoration: const InputDecoration(
                              labelText: 'Telefon raqam',
                              hintText: '010-1234-5678',
                              prefixIcon: Icon(Icons.phone_iphone_rounded),
                              helperText: '010 bilan yozsangiz, +82 avtomatik qo‘shiladi.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: sending ? null : _sendCode,
                            icon: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sms_outlined),
                            label: Text(sending ? 'Yuborilmoqda...' : 'SMS kod yuborish'),
                          ),
                        ] else ...[
                          TextField(
                            controller: code,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onSubmitted: (_) => _verify(),
                            decoration: const InputDecoration(
                              labelText: '6 xonali SMS kod',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: verifying ? null : _verify,
                            icon: verifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(verifying ? 'Tekshirilmoqda...' : 'Kirish'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: sending
                                ? null
                                : () {
                                    setState(() {
                                      codeSent = false;
                                      code.clear();
                                      error = null;
                                    });
                                  },
                            child: const Text('Raqamni o‘zgartirish'),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFCCD1)),
                            ),
                            child: Text(
                              error!,
                              style: const TextStyle(color: AppColors.danger, height: 1.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'''
Path('lib/auth_gate.dart').write_text(auth_gate, encoding='utf-8')

# ---------------- MAIN / ROUTE STABILITY ----------------
replace_once(
    'lib/main.dart',
    "import 'app_state.dart';\n",
    "import 'app_state.dart';\nimport 'auth_gate.dart';\n",
)
replace_once(
    'lib/main.dart',
    "        theme: MuhajeerDesign.theme,\n        home: const StoreShell(),\n",
    "        theme: MuhajeerDesign.theme,\n        builder: (context, child) => ColoredBox(\n          color: AppColors.background,\n          child: child ?? const SizedBox.shrink(),\n        ),\n        home: backendConfigured\n            ? const CustomerAuthGate()\n            : const StoreShell(),\n",
)
replace_once(
    'lib/design_system.dart',
    "      visualDensity: VisualDensity.standard,\n      splashFactory: InkSparkle.splashFactory,\n",
    "      visualDensity: VisualDensity.standard,\n      canvasColor: AppColors.background,\n      pageTransitionsTheme: const PageTransitionsTheme(\n        builders: {\n          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),\n          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),\n          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),\n          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),\n          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),\n        },\n      ),\n      splashFactory: InkSparkle.splashFactory,\n",
)

# ---------------- APP STATE: visitor analytics + authenticated customer data ----------------
replace_once(
    'lib/app_state.dart',
    "  static const _customerAddressKey = 'muhajeer_customer_address';\n",
    "  static const _customerAddressKey = 'muhajeer_customer_address';\n  static const _installIdKey = 'muhajeer_install_id_v1';\n",
)
replace_once(
    'lib/app_state.dart',
    "  Future<void> saveCustomer(String name, String phone, String address) async {\n    final prefs = await _prefs;\n    await prefs.setString(_customerNameKey, name);\n    await prefs.setString(_customerPhoneKey, phone);\n    await prefs.setString(_customerAddressKey, address);\n  }\n",
    "  Future<void> saveCustomer(String name, String phone, String address) async {\n    final prefs = await _prefs;\n    await prefs.setString(_customerNameKey, name);\n    await prefs.setString(_customerPhoneKey, phone);\n    await prefs.setString(_customerAddressKey, address);\n  }\n\n  Future<String> installId() async {\n    final prefs = await _prefs;\n    final existing = prefs.getString(_installIdKey);\n    if (existing != null && existing.length >= 12) return existing;\n    final generated = 'mb-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(prefs).abs()}';\n    await prefs.setString(_installIdKey, generated);\n    return generated;\n  }\n",
)
replace_once(
    'lib/app_state.dart',
    "  Future<void> signOut() => client.auth.signOut();\n",
    "  Future<void> signOut() => client.auth.signOut();\n\n  Future<void> registerInstallation(String installId, String platform) async {\n    await client.rpc(\n      'register_app_install',\n      params: {'p_install_id': installId, 'p_platform': platform},\n    );\n  }\n",
)
replace_once(
    'lib/app_state.dart',
    "    if (_backend == null) {\n      await _initializeLocalCatalog();\n    } else {\n      await refreshBooks();\n      _startLiveBooksSync();\n    }\n",
    "    if (_backend == null) {\n      await _initializeLocalCatalog();\n    } else {\n      unawaited(_registerInstallation());\n      await refreshBooks();\n      _startLiveBooksSync();\n    }\n",
)
replace_once(
    'lib/app_state.dart',
    "  void _startLiveBooksSync() {\n",
    "  Future<void> _registerInstallation() async {\n    try {\n      final id = await _local.installId();\n      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;\n      await _backend?.registerInstallation(id, platform);\n    } catch (_) {\n      // Analytics must never slow or block shopping.\n    }\n  }\n\n  Future<void> setAuthenticatedCustomer(String name, String phone) async {\n    final cleanName = name.trim();\n    final cleanPhone = phone.trim();\n    savedCustomer = {\n      'name': cleanName.isEmpty ? (savedCustomer['name'] ?? '') : cleanName,\n      'phone': cleanPhone.isEmpty ? (savedCustomer['phone'] ?? '') : cleanPhone,\n      'address': savedCustomer['address'] ?? '',\n    };\n    await _local.saveCustomer(\n      savedCustomer['name'] ?? '',\n      savedCustomer['phone'] ?? '',\n      savedCustomer['address'] ?? '',\n    );\n    notifyListeners();\n  }\n\n  void _startLiveBooksSync() {\n",
)

# ---------------- CHECKOUT: proof is mandatory and submit appears only after proof ----------------
store = Path('lib/store_ui.dart').read_text(encoding='utf-8')
if "import 'package:supabase_flutter/supabase_flutter.dart';" not in store:
    store = store.replace(
        "import 'package:provider/provider.dart';\n",
        "import 'package:provider/provider.dart';\nimport 'package:supabase_flutter/supabase_flutter.dart';\n",
        1,
    )
old_submit = r'''            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: saving || state.cartLines.isEmpty
                    ? null
                    : () => _submit(state, deliveryFee),
                icon: saving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(saving ? 'Yuborilmoqda...' : 'Buyurtmani yuborish'),
              ),
            ),'''
new_submit = r'''            if (paymentDone && paymentProof != null)
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: saving || state.cartLines.isEmpty
                      ? null
                      : () => _submit(state, deliveryFee),
                  icon: saving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(saving ? 'Yuborilmoqda...' : 'Buyurtmani yuborish'),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFDF9B)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: AppColors.warning),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Buyurtmani yuborish tugmasi chek skrinshotini joylaganingizdan keyin ochiladi.',
                        style: TextStyle(fontWeight: FontWeight.w700, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),'''
if old_submit not in store:
    raise SystemExit('Checkout submit block not found')
store = store.replace(old_submit, new_submit, 1)
store = store.replace(
    "    if (paymentDone && paymentProof == null) {\n",
    "    if (!paymentDone || paymentProof == null) {\n",
    1,
)
store = store.replace(
    "      final proof = paymentDone ? paymentProof : null;\n",
    "      final proof = paymentProof;\n",
    1,
)
# Dynamic customer profile instead of showing the shop owner to every customer.
needle = "    final availableBooks = state.books\n        .where((b) => b.isActive && b.inStock)\n        .length;\n\n    return Scaffold("
replacement = "    final availableBooks = state.books\n        .where((b) => b.isActive && b.inStock)\n        .length;\n    final currentUser = Supabase.instance.client.auth.currentUser;\n    final displayName = (state.savedCustomer['name'] ?? '').trim().isNotEmpty\n        ? state.savedCustomer['name']!.trim()\n        : 'Muhajeer kitobxoni';\n    final displayPhone = currentUser?.phone ?? state.savedCustomer['phone'] ?? '';\n\n    return Scaffold("
if needle not in store:
    raise SystemExit('Profile header insertion point not found')
store = store.replace(needle, replacement, 1)
store = store.replace("                  child: const Padding(\n", "                  child: Padding(\n", 1)
store = store.replace("                      'Mohirbek Ismoilov',\n", "                      displayName,\n", 1)
# Replace profile settings no-op with logout when phone auth is active.
store = store.replace(
    "          IconButton(\n            onPressed: () {},\n            icon: const Icon(Icons.settings_outlined),\n          ),",
    "          IconButton(\n            tooltip: 'Hisobdan chiqish',\n            onPressed: currentUser == null\n                ? null\n                : () async {\n                    await Supabase.instance.client.auth.signOut();\n                  },\n            icon: const Icon(Icons.logout_rounded),\n          ),",
    1,
)
# Show phone below the customer name if authenticated.
store = store.replace(
    "                const SizedBox(height: 4),\n                const Text(\n                  'Muhajeer Books',",
    "                if (displayPhone.trim().isNotEmpty) ...[\n                  const SizedBox(height: 4),\n                  Text(\n                    displayPhone,\n                    textAlign: TextAlign.center,\n                    style: const TextStyle(\n                      color: Color(0xFFE5F1EE),\n                      fontSize: 12,\n                      fontWeight: FontWeight.w700,\n                    ),\n                  ),\n                ],\n                const SizedBox(height: 4),\n                const Text(\n                  'Muhajeer Books',",
    1,
)
Path('lib/store_ui.dart').write_text(store, encoding='utf-8')

# ---------------- ADMIN: customer analytics and user management tab ----------------
admin = Path('lib/admin_ui.dart').read_text(encoding='utf-8')
api_anchor = r'''  Future<void> updateOrderStatus(String id, String status) async {
    await client.rpc(
      'admin_update_order_status',
      params: {'p_secret': secret, 'p_id': id, 'p_status': status},
    );
  }
}'''
api_replacement = r'''  Future<void> updateOrderStatus(String id, String status) async {
    await client.rpc(
      'admin_update_order_status',
      params: {'p_secret': secret, 'p_id': id, 'p_status': status},
    );
  }

  Future<Map<String, dynamic>> userStats() async {
    final raw = await client.rpc(
      'admin_user_stats',
      params: {'p_secret': secret},
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> customers() async {
    final raw = await client.rpc(
      'admin_list_customers',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}'''
if api_anchor not in admin:
    raise SystemExit('Admin API anchor not found')
admin = admin.replace(api_anchor, api_replacement, 1)
admin = admin.replace(
    "    'Buyurtmalar',\n    'Chegirmalar',\n",
    "    'Buyurtmalar',\n    'Mijozlar',\n    'Chegirmalar',\n",
    1,
)
admin = admin.replace(
    "    Icons.receipt_long_rounded,\n    Icons.percent_rounded,\n",
    "    Icons.receipt_long_rounded,\n    Icons.people_alt_rounded,\n    Icons.percent_rounded,\n",
    1,
)
admin = admin.replace(
    "      _OrdersAdmin(api: api),\n      _DiscountAdmin(api: api),\n",
    "      _OrdersAdmin(api: api),\n      _CustomersAdmin(api: api),\n      _DiscountAdmin(api: api),\n",
    1,
)

customers_widget = r'''

class _CustomersAdmin extends StatefulWidget {
  const _CustomersAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_CustomersAdmin> createState() => _CustomersAdminState();
}

class _CustomersAdminState extends State<_CustomersAdmin> {
  late Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> future;
  String query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    future = Future.wait<dynamic>([
      widget.api.userStats(),
      widget.api.customers(),
    ]).then((v) => (
          Map<String, dynamic>.from(v[0] as Map),
          (v[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        ));
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse((value ?? '').toString())?.toLocal();
    if (d == null) return '—';
    return DateFormat('yyyy.MM.dd HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Qayta yuklash: ${snapshot.error}'),
            ),
          );
        }
        final stats = snapshot.data?.$1 ?? <String, dynamic>{};
        final all = snapshot.data?.$2 ?? <Map<String, dynamic>>[];
        final q = query.trim().toLowerCase();
        final customers = all.where((c) {
          if (q.isEmpty) return true;
          return (c['full_name'] ?? '').toString().toLowerCase().contains(q) ||
              (c['phone'] ?? '').toString().toLowerCase().contains(q);
        }).toList();

        Widget metric(String label, dynamic value, IconData icon) => Expanded(
              child: AppSurface(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppColors.navy, size: 20),
                    const SizedBox(height: 10),
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                  ],
                ),
              ),
            );

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            setState(() {});
            await future;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
            children: [
              const AppSectionHeader(
                title: 'Mijozlar markazi',
                subtitle: 'Loginlar, faol foydalanuvchilar va xarid tarixi',
                icon: Icons.people_alt_rounded,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  metric('Ro‘yxatdan o‘tgan', stats['total_users'] ?? 0, Icons.person_add_alt_1_rounded),
                  const SizedBox(width: 10),
                  metric('Bugun faol', stats['active_today'] ?? 0, Icons.bolt_rounded),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  metric('Ilova qurilmalari', stats['total_installs'] ?? 0, Icons.phone_iphone_rounded),
                  const SizedBox(width: 10),
                  metric('7 kunda faol', stats['active_7d'] ?? 0, Icons.calendar_view_week_rounded),
                ],
              ),
              const SizedBox(height: 16),
              AppSurface(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.navy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ochiq buyurtmalar: ${stats['open_orders'] ?? 0} • Yakunlangan: ${stats['completed_orders'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      _won((stats['completed_revenue'] as num?)?.toInt() ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.success),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  hintText: 'Ism yoki telefon bo‘yicha qidirish...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (customers.isEmpty)
                const AppSurface(
                  child: Text('Hozircha ro‘yxatdan o‘tgan mijoz yo‘q.'),
                )
              else
                ...customers.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: AppSurface(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.infoSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.person_rounded, color: AppColors.info),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (c['full_name'] ?? '').toString().trim().isEmpty
                                        ? 'Nomsiz mijoz'
                                        : c['full_name'].toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                  const SizedBox(height: 3),
                                  Text((c['phone'] ?? '—').toString(), style: const TextStyle(color: AppColors.muted)),
                                  const SizedBox(height: 7),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      AppInfoPill(
                                        icon: Icons.shopping_bag_outlined,
                                        label: '${c['order_count'] ?? 0} buyurtma',
                                      ),
                                      AppInfoPill(
                                        icon: Icons.payments_outlined,
                                        label: _won((c['spent'] as num?)?.toInt() ?? 0),
                                        foreground: AppColors.success,
                                        background: AppColors.successSoft,
                                        border: const Color(0xFFCDEAD7),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Oxirgi faollik', style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
                                const SizedBox(height: 3),
                                Text(_date(c['last_seen_at']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text('${c['login_count'] ?? 0} login', style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}
'''
admin += customers_widget
Path('lib/admin_ui.dart').write_text(admin, encoding='utf-8')

# Bump application version for this production-grade upgrade.
pub = Path('pubspec.yaml').read_text(encoding='utf-8')
pub = pub.replace('version: 2.3.0+5', 'version: 2.4.0+6', 1)
Path('pubspec.yaml').write_text(pub, encoding='utf-8')

print('Professional upgrade staged successfully.')
