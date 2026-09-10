from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Missing patch target: {label}")
    return text.replace(old, new, 1)


# -------------------------
# pubspec.yaml
# -------------------------
pubspec_path = Path("pubspec.yaml")
pubspec = pubspec_path.read_text(encoding="utf-8")
if "  url_launcher:" not in pubspec:
    pubspec = replace_once(
        pubspec,
        "  shared_preferences: ^2.5.3\n",
        "  shared_preferences: ^2.5.3\n  url_launcher: ^6.3.1\n",
        "url_launcher dependency",
    )
pubspec_path.write_text(pubspec, encoding="utf-8")


# -------------------------
# lib/app_state.dart
# -------------------------
state_path = Path("lib/app_state.dart")
state = state_path.read_text(encoding="utf-8")

if "String get recoveryCode" not in state:
    state = replace_once(
        state,
        "  bool get isApp => source == 'app';\n",
        "  bool get isApp => source == 'app';\n\n"
        "  String get recoveryCode {\n"
        "    final compact = id.replaceAll('-', '').toLowerCase();\n"
        "    if (compact.length <= 12) return compact;\n"
        "    return compact.substring(compact.length - 12);\n"
        "  }\n",
        "ShopOrder recovery code",
    )

if "Future<List<ShopOrder>> restoreOrders" not in state:
    marker = "  Future<List<ShopOrder>> fetchOrders() async {\n"
    backend_restore = """  Future<List<ShopOrder>> restoreOrders({
    required String phone,
    required String recoveryCode,
  }) async {
    final raw = await client.rpc(
      'customer_restore_orders',
      params: {
        'p_phone': phone.trim(),
        'p_recovery_code': recoveryCode.trim(),
      },
    );
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => ShopOrder.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

"""
    idx = state.find(marker)
    if idx < 0:
        raise RuntimeError("Missing BackendService fetchOrders marker")
    state = state[:idx] + backend_restore + state[idx:]

state = state.replace(
    "_booksFallbackTimer = Timer.periodic(const Duration(seconds: 20), (_) {",
    "_booksFallbackTimer = Timer.periodic(const Duration(seconds: 60), (_) {",
    1,
)
state = state.replace(
    "        const Duration(seconds: 8),",
    "        const Duration(seconds: 30),",
    1,
)

# A successful online insert reserves stock on the server immediately.
receipt_marker = "      final receipt = ShopOrder(\n"
receipt_start = state.find(receipt_marker)
if receipt_start < 0:
    raise RuntimeError("Missing online receipt marker")
receipt_end = state.find("      _localOrders.removeWhere", receipt_start)
if receipt_end < 0:
    raise RuntimeError("Missing online receipt end marker")
receipt_segment = state[receipt_start:receipt_end]
if "stockReserved: true," not in receipt_segment:
    if "stockReserved: false," not in receipt_segment:
        raise RuntimeError("Missing online stockReserved flag")
    receipt_segment = receipt_segment.replace(
        "stockReserved: false,", "stockReserved: true,", 1
    )
    state = state[:receipt_start] + receipt_segment + state[receipt_end:]

if "Future<int> restoreCustomerOrders" not in state:
    restore_method = """  Future<int> restoreCustomerOrders({
    required String phone,
    required String recoveryCode,
  }) async {
    if (_backend == null) {
      throw StateError('Buyurtmalarni tiklash uchun internet kerak.');
    }

    final restored = await _backend!.restoreOrders(
      phone: phone,
      recoveryCode: recoveryCode,
    );
    if (restored.isEmpty) return 0;

    final merged = <String, ShopOrder>{
      for (final order in _localOrders) order.id: order,
      for (final order in restored) order.id: order,
    };
    final sorted = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _localOrders
      ..clear()
      ..addAll(sorted.take(100));

    final cleanPhone = phone.trim();
    savedCustomer = {
      'name': savedCustomer['name'] ?? '',
      'phone': cleanPhone,
      'address': savedCustomer['address'] ?? '',
    };
    await Future.wait([
      _local.saveOrders(_localOrders),
      _local.saveCustomer(
        savedCustomer['name'] ?? '',
        cleanPhone,
        savedCustomer['address'] ?? '',
      ),
    ]);
    notifyListeners();
    return restored.length;
  }

"""
    state = replace_once(
        state,
        "  Future<void> markCustomerNoticesRead() async {\n",
        restore_method + "  Future<void> markCustomerNoticesRead() async {\n",
        "AppState restore orders",
    )

state = state.replace(
    "        if (newStatus != oldOrder.status &&\n"
    "            (newStatus == 'accepted' || newStatus == 'shipping')) {",
    "        if (newStatus != oldOrder.status &&\n"
    "            const {'accepted', 'paid', 'shipping', 'cancelled'}\n"
    "                .contains(newStatus)) {",
    1,
)

old_notice = """              'title': newStatus == 'accepted'
                  ? '✅ Buyurtmangiz qabul qilindi'
                  : '🚚 Buyurtmangiz pochtaga topshirildi',
              'message': newStatus == 'accepted'
                  ? 'Buyurtmangiz tasdiqlandi va tayyorlanmoqda.'
                  : 'Buyurtmangiz pochtaga topshirildi. 1–3 ish kunida yetkaziladi.',
"""
new_notice = """              'title': switch (newStatus) {
                'accepted' => '✅ Buyurtmangiz qabul qilindi',
                'paid' => '💳 To‘lovingiz tasdiqlandi',
                'shipping' => '🚚 Buyurtmangiz pochtaga topshirildi',
                'cancelled' => '❌ Buyurtmangiz bekor qilindi',
                _ => 'Buyurtma yangilandi',
              },
              'message': switch (newStatus) {
                'accepted' => 'Buyurtmangiz tasdiqlandi va tayyorlanmoqda.',
                'paid' => 'To‘lov tekshirildi. Buyurtmangiz tayyorlanmoqda.',
                'shipping' =>
                  'Buyurtmangiz pochtaga topshirildi. 1–3 ish kunida yetkaziladi.',
                'cancelled' =>
                  'Buyurtma bekor qilindi. Savol bo‘lsa Muhajeer Books bilan bog‘laning.',
                _ => 'Buyurtmangiz holati yangilandi.',
              },
"""
if old_notice in state:
    state = state.replace(old_notice, new_notice, 1)
elif "'paid' => '💳 To‘lovingiz tasdiqlandi'" not in state:
    raise RuntimeError("Missing customer notice patch target")

state_path.write_text(state, encoding="utf-8")


# -------------------------
# lib/store_ui.dart
# -------------------------
ui_path = Path("lib/store_ui.dart")
ui = ui_path.read_text(encoding="utf-8")

if "package:url_launcher/url_launcher.dart" not in ui:
    ui = replace_once(
        ui,
        "import 'package:supabase_flutter/supabase_flutter.dart';\n",
        "import 'package:supabase_flutter/supabase_flutter.dart';\n"
        "import 'package:url_launcher/url_launcher.dart';\n",
        "url_launcher import",
    )

if "Future<void> _openTelegramRestock" not in ui:
    helper = """
Future<void> _openTelegramRestock(BuildContext context, Book book) async {
  final telegramId = book.legacyId;
  if (telegramId == null || telegramId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bu kitob uchun Telegram xabari hali ulanmagan.'),
      ),
    );
    return;
  }

  final uri = Uri.parse(
    'https://t.me/muhajeerbooks_bot?start=restock_$telegramId',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted) return;
  if (!opened) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Telegram ochilmadi. @muhajeerbooks_bot orqali kirishingiz mumkin.'),
      ),
    );
  }
}

"""
    ui = replace_once(
        ui,
        "String won(int value) => '₩${_money.format(value)}';\n\n",
        "String won(int value) => '₩${_money.format(value)}';\n\n" + helper,
        "Telegram restock helper",
    )

# Add real Telegram push option on the sold-out detail screen.
telegram_button_anchor = """                label: Text(
                  b.inStock
                      ? 'Savatchaga qo‘shish'
                      : state.isRestockSubscribed(b)
                      ? 'Xabar beramiz ✅'
                      : 'Kelganda xabar berish',
                ),
              ),
            ],
"""
if "Telegramda xabar olish" not in ui:
    telegram_button_new = """                label: Text(
                  b.inStock
                      ? 'Savatchaga qo‘shish'
                      : state.isRestockSubscribed(b)
                      ? 'Xabar beramiz ✅'
                      : 'Kelganda xabar berish',
                ),
              ),
              if (!b.inStock && b.legacyId != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openTelegramRestock(context, b),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Telegramda xabar olish'),
                ),
              ],
            ],
"""
    ui = replace_once(
        ui,
        telegram_button_anchor,
        telegram_button_new,
        "Telegram restock detail button",
    )

# Order history recovery dialog.
if "Future<void> _restoreOrders() async" not in ui:
    reload_anchor = """  void _reload() {
    final state = context.read<AppState>();
    future = state.customerOrdersByPhone(state.savedCustomer['phone'] ?? '');
  }

  @override
"""
    restore_dialog = """  void _reload() {
    final state = context.read<AppState>();
    future = state.customerOrdersByPhone(state.savedCustomer['phone'] ?? '');
  }

  Future<void> _restoreOrders() async {
    final state = context.read<AppState>();
    final phoneController = TextEditingController(
      text: state.savedCustomer['phone'] ?? '',
    );
    final codeController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eski buyurtmalarni tiklash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Oldingi buyurtmadagi 12 belgili tiklash kodi va telefon raqamingizni kiriting.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon raqami',
                hintText: '010-1234-5678',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Tiklash kodi',
                hintText: '12 belgi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tiklash'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      phoneController.dispose();
      codeController.dispose();
      return;
    }

    try {
      final count = await state.restoreCustomerOrders(
        phone: phoneController.text,
        recoveryCode: codeController.text,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '$count ta buyurtma tiklandi ✅'
                : 'Tiklanadigan buyurtma topilmadi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '').replaceFirst(
        'PostgrestException(message: ',
        '',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tiklash amalga oshmadi: $message')),
      );
    } finally {
      phoneController.dispose();
      codeController.dispose();
    }
  }

  @override
"""
    ui = replace_once(ui, reload_anchor, restore_dialog, "order recovery dialog")

if "tooltip: 'Eski buyurtmalarni tiklash'" not in ui:
    appbar_anchor = """        title: const Text('Mening buyurtmalarim'),
        actions: [
          IconButton(
            onPressed: () => setState(_reload),
"""
    appbar_new = """        title: const Text('Mening buyurtmalarim'),
        actions: [
          IconButton(
            tooltip: 'Eski buyurtmalarni tiklash',
            onPressed: _restoreOrders,
            icon: const Icon(Icons.restore_rounded),
          ),
          IconButton(
            tooltip: 'Yangilash',
            onPressed: () => setState(_reload),
"""
    ui = replace_once(ui, appbar_anchor, appbar_new, "order recovery appbar action")

ui = ui.replace(
    "'Buyurtma № ${order.id}'",
    "'Buyurtma № ${order.recoveryCode}'",
    1,
)

ui_path.write_text(ui, encoding="utf-8")


# -------------------------
# web/index.html
# -------------------------
web_path = Path("web/index.html")
web = web_path.read_text(encoding="utf-8")
if 'property="og:title"' not in web:
    seo = """  <meta name="theme-color" content="#113D43">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Muhajeer Books">
  <meta property="og:title" content="Muhajeer Books — Koreyadagi o‘zbek kitob do‘koni">
  <meta property="og:description" content="Koreya bo‘ylab o‘zbek kitoblarini qulay buyurtma qiling. 4 ta va undan ortiq kitobga yetkazib berish bepul.">
  <meta property="og:url" content="https://muhajeer-books-live-production.up.railway.app/">
  <meta property="og:image" content="https://muhajeer-books-live-production.up.railway.app/icons/Icon-512.png">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Muhajeer Books">
  <meta name="twitter:description" content="Koreyadagi o‘zbek kitob do‘koni">
  <meta name="twitter:image" content="https://muhajeer-books-live-production.up.railway.app/icons/Icon-512.png">
"""
    web = replace_once(
        web,
        "  <meta name=\"description\" content=\"Muhajeer Books — Koreyadagi o'zbek kitob do'koni\">\n",
        "  <meta name=\"description\" content=\"Muhajeer Books — Koreyadagi o'zbek kitob do'koni\">\n" + seo,
        "SEO meta tags",
    )
web = web.replace("flutter_bootstrap.js?v=20260909-1", "flutter_bootstrap.js?v=20260910-2")
web_path.write_text(web, encoding="utf-8")


# -------------------------
# test/order_rules_test.dart
# -------------------------
test_path = Path("test/order_rules_test.dart")
test = test_path.read_text(encoding="utf-8")
if "recovery code is stable" not in test:
    insert = """

  test('recovery code is stable and short enough to share', () {
    final order = ShopOrder(
      id: '677ae40f-7c44-4420-acb6-fef72c6b1641',
      customerName: 'Test',
      phone: '01012345678',
      address: 'Test address',
      deliveryType: '택배',
      deliveryFee: 4000,
      subtotal: 10000,
      total: 14000,
      status: 'new',
      source: 'app',
      items: const [],
      createdAt: DateTime(2026, 9, 10),
      stockReserved: true,
    );

    expect(order.recoveryCode, 'fef72c6b1641');
    expect(order.stockReserved, isTrue);
  });
"""
    pos = test.rfind("}\n")
    if pos < 0:
        raise RuntimeError("Missing test main closing brace")
    test = test[:pos] + insert + test[pos:]
    test_path.write_text(test, encoding="utf-8")

print("Launch hardening patches applied")
