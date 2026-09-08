from pathlib import Path


def replace_required(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise SystemExit(f"Could not find {label}")
    return text.replace(old, new, 1)

# ---- app_state.dart ----
p = Path('lib/app_state.dart')
s = p.read_text(encoding='utf-8')

s = replace_required(
    s,
    "  static const _customerAddressKey = 'muhajeer_customer_address';\n  static const _installIdKey = 'muhajeer_install_id_v1';",
    "  static const _customerAddressKey = 'muhajeer_customer_address';\n  static const _customerVerifiedKey = 'muhajeer_customer_verified_v1';\n  static const _installIdKey = 'muhajeer_install_id_v1';",
    'customer verification key',
)

s = replace_required(
    s,
    "  Future<void> saveCustomer(String name, String phone, String address) async {\n    final prefs = await _prefs;\n    await prefs.setString(_customerNameKey, name);\n    await prefs.setString(_customerPhoneKey, phone);\n    await prefs.setString(_customerAddressKey, address);\n  }\n\n  Future<String> installId() async {",
    "  Future<void> saveCustomer(String name, String phone, String address) async {\n    final prefs = await _prefs;\n    await prefs.setString(_customerNameKey, name);\n    await prefs.setString(_customerPhoneKey, phone);\n    await prefs.setString(_customerAddressKey, address);\n  }\n\n  Future<bool?> loadCustomerVerified() async =>\n      (await _prefs).getBool(_customerVerifiedKey);\n\n  Future<void> saveCustomerVerified(bool value) async =>\n      (await _prefs).setBool(_customerVerifiedKey, value);\n\n  Future<void> clearCustomer() async {\n    final prefs = await _prefs;\n    await prefs.remove(_customerNameKey);\n    await prefs.remove(_customerPhoneKey);\n    await prefs.remove(_customerAddressKey);\n    await prefs.setBool(_customerVerifiedKey, false);\n  }\n\n  Future<String> installId() async {",
    'local customer methods',
)

s = replace_required(
    s,
    "  bool loading = true;\n  String? error;\n  Map<String, String> savedCustomer = const {",
    "  bool loading = true;\n  String? error;\n  bool customerVerified = false;\n  Map<String, String> savedCustomer = const {",
    'customerVerified field',
)

s = replace_required(
    s,
    "    savedCustomer = await _local.loadCustomer();\n    _localOrders",
    "    savedCustomer = await _local.loadCustomer();\n    final storedVerification = await _local.loadCustomerVerified();\n    if (storedVerification == null) {\n      // Old installations were already registered before SMS verification was introduced.\n      // Keep them signed in; new registrations can be verified once when SMS is enabled.\n      final legacyName = (savedCustomer['name'] ?? '').trim();\n      final legacyPhone = (savedCustomer['phone'] ?? '').replaceAll(RegExp(r'\\D'), '');\n      customerVerified = legacyName.length >= 2 && legacyPhone.length >= 9;\n      if (customerVerified) await _local.saveCustomerVerified(true);\n    } else {\n      customerVerified = storedVerification;\n    }\n    _localOrders",
    'initialize verification state',
)

s = replace_required(
    s,
    "  Future<void> setAuthenticatedCustomer(String name, String phone) async {\n    final cleanName = name.trim();\n    final cleanPhone = phone.trim();",
    "  Future<void> setAuthenticatedCustomer(\n    String name,\n    String phone, {\n    bool verified = true,\n  }) async {\n    final cleanName = name.trim();\n    final cleanPhone = phone.trim();",
    'setAuthenticatedCustomer signature',
)

s = replace_required(
    s,
    "    await _local.saveCustomer(\n      savedCustomer['name'] ?? '',\n      savedCustomer['phone'] ?? '',\n      savedCustomer['address'] ?? '',\n    );\n    notifyListeners();\n  }\n\n  void _startLiveBooksSync() {",
    "    await _local.saveCustomer(\n      savedCustomer['name'] ?? '',\n      savedCustomer['phone'] ?? '',\n      savedCustomer['address'] ?? '',\n    );\n    customerVerified = verified;\n    await _local.saveCustomerVerified(verified);\n    notifyListeners();\n  }\n\n  Future<void> signOutCustomer() async {\n    try {\n      if (backendConfigured) {\n        await Supabase.instance.client.auth.signOut();\n      }\n    } catch (_) {\n      // Local logout must still work even if the network is unavailable.\n    }\n    savedCustomer = const {\n      'name': '',\n      'phone': '',\n      'address': '',\n    };\n    customerVerified = false;\n    await _local.clearCustomer();\n    notifyListeners();\n  }\n\n  void _startLiveBooksSync() {",
    'logout method',
)

p.write_text(s, encoding='utf-8')

# ---- store_ui.dart ----
p = Path('lib/store_ui.dart')
s = p.read_text(encoding='utf-8')

s = replace_required(
    s,
    "    final currentUser = Supabase.instance.client.auth.currentUser;\n    final displayName = (state.savedCustomer['name'] ?? '').trim().isNotEmpty\n        ? state.savedCustomer['name']!.trim()\n        : 'Muhajeer kitobxoni';\n    final displayPhone =\n        currentUser?.phone ?? state.savedCustomer['phone'] ?? '';",
    "    final displayName = (state.savedCustomer['name'] ?? '').trim().isNotEmpty\n        ? state.savedCustomer['name']!.trim()\n        : 'Muhajeer kitobxoni';\n    final displayPhone = state.savedCustomer['phone'] ?? '';",
    'profile current user display',
)

s = replace_required(
    s,
    "          IconButton(\n            tooltip: 'Hisobdan chiqish',\n            onPressed: currentUser == null\n                ? null\n                : () async {\n                    await Supabase.instance.client.auth.signOut();\n                  },\n            icon: const Icon(Icons.logout_rounded),\n          ),",
    "          IconButton(\n            tooltip: 'Hisobdan chiqish',\n            onPressed: () async {\n              final shouldLogout = await showDialog<bool>(\n                context: context,\n                builder: (dialogContext) => AlertDialog(\n                  title: const Text('Hisobdan chiqish'),\n                  content: const Text(\n                    'Haqiqatan ham hisobdan chiqmoqchimisiz?',\n                  ),\n                  actions: [\n                    TextButton(\n                      onPressed: () => Navigator.pop(dialogContext, false),\n                      child: const Text('Yo‘q'),\n                    ),\n                    FilledButton(\n                      onPressed: () => Navigator.pop(dialogContext, true),\n                      child: const Text('Chiqish'),\n                    ),\n                  ],\n                ),\n              );\n              if (shouldLogout != true || !context.mounted) return;\n              await context.read<AppState>().signOutCustomer();\n            },\n            icon: const Icon(Icons.logout_rounded),\n          ),",
    'profile logout button',
)

p.write_text(s, encoding='utf-8')

print('Customer logout fixed and one-time verification state added.')
