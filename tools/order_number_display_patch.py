from pathlib import Path

p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')

old = """              final books = (row['books'] ?? '• Kitob ma’lumoti yo‘q')
                  .toString();
              final orderNumber = row['order_number'];
              return Padding(
"""
new = """              final books = (row['books'] ?? '• Kitob ma’lumoti yo‘q')
                  .toString();
              final rawOrderNumber = int.tryParse(
                (row['order_number'] ?? '').toString(),
              );
              final normalizedOrderNumber = rawOrderNumber == null
                  ? null
                  : (rawOrderNumber >= 9000000000000
                        ? rawOrderNumber - 9000000000000
                        : rawOrderNumber);
              final displayOrderNumber = normalizedOrderNumber == null
                  ? ''
                  : normalizedOrderNumber.toString().padLeft(4, '0');
              return Padding(
"""
if old not in s:
    raise SystemExit('order number data marker not found')
s = s.replace(old, new, 1)

old = """                                  '${sourceLabel(source)}${orderNumber == null ? '' : ' · №$orderNumber'}',
"""
new = """                                  '${sourceLabel(source)}${displayOrderNumber.isEmpty ? '' : ' · №$displayOrderNumber'}',
"""
if old not in s:
    raise SystemExit('order number label marker not found')
s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
print('Shipping queue order numbers now use short sequential display numbers.')
