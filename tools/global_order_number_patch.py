from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'marker not found: {label}')
    return text.replace(old, new, 1)

# Add the central display order number to ShopOrder so every admin order screen can use it.
p = Path('lib/app_state.dart')
s = p.read_text(encoding='utf-8')
s = replace_once(
    s,
    "    this.source = 'app',\n    required this.items,",
    "    this.source = 'app',\n    this.displayOrderNumber = 0,\n    required this.items,",
    'ShopOrder constructor',
)
s = replace_once(
    s,
    "  final String source;\n  final List<Map<String, dynamic>> items;",
    "  final String source;\n  final int displayOrderNumber;\n  final List<Map<String, dynamic>> items;",
    'ShopOrder field',
)
s = replace_once(
    s,
    "    source: (map['source'] ?? 'app').toString(),\n    items:",
    "    source: (map['source'] ?? 'app').toString(),\n    displayOrderNumber: (map['display_order_number'] as num?)?.toInt() ?? 0,\n    items:",
    'ShopOrder fromMap',
)
s = replace_once(
    s,
    "    'source': source,\n    'items': items,",
    "    'source': source,\n    'display_order_number': displayOrderNumber,\n    'items': items,",
    'ShopOrder toMap',
)
s = replace_once(
    s,
    "    source: source ?? this.source,\n    items: items,",
    "    source: source ?? this.source,\n    displayOrderNumber: displayOrderNumber,\n    items: items,",
    'ShopOrder copyWith',
)
p.write_text(s, encoding='utf-8')

# Use the DB-assigned global sequence everywhere the admin UI shows an order number.
p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')
old_block = """              final rawOrderNumber = int.tryParse(\n                (row['order_number'] ?? '').toString(),\n              );\n              final normalizedOrderNumber = rawOrderNumber == null\n                  ? null\n                  : (rawOrderNumber >= 9000000000000\n                        ? rawOrderNumber - 9000000000000\n                        : rawOrderNumber);\n              final displayOrderNumber = normalizedOrderNumber == null\n                  ? ''\n                  : normalizedOrderNumber.toString().padLeft(4, '0');\n"""
new_block = """              final displayOrderNumberValue = int.tryParse(\n                (row['display_order_number'] ?? '').toString(),\n              );\n              final displayOrderNumber = displayOrderNumberValue == null ||\n                      displayOrderNumberValue <= 0\n                  ? ''\n                  : displayOrderNumberValue.toString().padLeft(4, '0');\n"""
s = replace_once(s, old_block, new_block, 'shipping queue number')
s = s.replace(
    "'№ ${order.id}'",
    "\"№ ${order.displayOrderNumber > 0 ? order.displayOrderNumber.toString().padLeft(4, '0') : order.id}\"",
)
p.write_text(s, encoding='utf-8')
print('Global four-digit order number UI applied.')
