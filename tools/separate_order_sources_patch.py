from pathlib import Path

# --- app_state.dart: preserve order source (app / telegram) ---
p = Path('lib/app_state.dart')
s = p.read_text(encoding='utf-8')

if "final String source;" not in s:
    s = s.replace(
        "    required this.status,\n    required this.items,",
        "    required this.status,\n    this.source = 'app',\n    required this.items,",
        1,
    )
    s = s.replace(
        "  final String status;\n  final List<Map<String, dynamic>> items;",
        "  final String status;\n  final String source;\n  final List<Map<String, dynamic>> items;",
        1,
    )
    s = s.replace(
        "  bool get hasPaymentProof => paymentProofPath.trim().isNotEmpty;",
        "  bool get hasPaymentProof => paymentProofPath.trim().isNotEmpty;\n  bool get isTelegram => source == 'telegram';\n  bool get isApp => !isTelegram;",
        1,
    )
    s = s.replace(
        "    status: (map['status'] ?? 'new').toString(),\n    items:",
        "    status: (map['status'] ?? 'new').toString(),\n    source: (map['source'] ?? 'app').toString(),\n    items:",
        1,
    )
    s = s.replace(
        "    'status': status,\n    'items': items,",
        "    'status': status,\n    'source': source,\n    'items': items,",
        1,
    )
    s = s.replace(
        "  ShopOrder copyWith({\n    String? status,",
        "  ShopOrder copyWith({\n    String? status,\n    String? source,",
        1,
    )
    s = s.replace(
        "    status: status ?? this.status,\n    items: items,",
        "    status: status ?? this.status,\n    source: source ?? this.source,\n    items: items,",
        1,
    )

# App-created orders are always explicitly marked app.
needle = "      'status': 'new',\n      'items': lines.map(_lineToMap).toList(),"
if needle in s and "'source': 'app'" not in s[s.index(needle)-200:s.index(needle)+300]:
    s = s.replace(
        needle,
        "      'status': 'new',\n      'source': 'app',\n      'items': lines.map(_lineToMap).toList(),",
        1,
    )

p.write_text(s, encoding='utf-8')

# --- admin_ui.dart: Telegram orders are visible but read-only ---
p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')

change_sig = "  Future<void> changeStatus(ShopOrder order, String status) async {\n    if (busy.contains(order.id)) return;"
if change_sig in s and "Telegram buyurtmasi botdan boshqariladi" not in s:
    s = s.replace(
        change_sig,
        "  Future<void> changeStatus(ShopOrder order, String status) async {\n"
        "    if (order.isTelegram) {\n"
        "      if (mounted) {\n"
        "        ScaffoldMessenger.of(context).showSnackBar(\n"
        "          const SnackBar(content: Text('Telegram buyurtmasi botdan boshqariladi.')),\n"
        "        );\n"
        "      }\n"
        "      return;\n"
        "    }\n"
        "    if (busy.contains(order.id)) return;",
        1,
    )

# Show source label directly on each order card before the total.
source_marker = """            children: [\n              Text(\n                _won(order.total),"""
source_replacement = """            children: [\n              if (order.isTelegram) ...[\n                const Icon(Icons.send_rounded, size: 15, color: Color(0xFF229ED9)),\n                const SizedBox(width: 4),\n                const Text(\n                  'Telegramdan zakas',\n                  style: TextStyle(\n                    color: Color(0xFF1976A3),\n                    fontSize: 12,\n                    fontWeight: FontWeight.w800,\n                  ),\n                ),\n                const Text(' • '),\n              ],\n              Text(\n                _won(order.total),"""
if source_marker in s and "'Telegramdan zakas'" not in s:
    s = s.replace(source_marker, source_replacement, 1)

# Hide app-side management buttons for Telegram orders and explain where to manage them.
actions_marker = """  Widget build(BuildContext context) {\n    if (order.status == 'cancelled' || order.status == 'done')"""
actions_replacement = """  Widget build(BuildContext context) {\n    if (order.isTelegram) {\n      return const AppInfoPill(\n        icon: Icons.send_rounded,\n        label: 'Telegram buyurtmasi — botdan boshqariladi',\n        foreground: Color(0xFF1976A3),\n        background: Color(0xFFEAF7FD),\n        border: Color(0xFFC8E8F6),\n      );\n    }\n    if (order.status == 'cancelled' || order.status == 'done')"""
if actions_marker in s and "Telegram buyurtmasi — botdan boshqariladi" not in s:
    s = s.replace(actions_marker, actions_replacement, 1)

p.write_text(s, encoding='utf-8')
