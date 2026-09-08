from pathlib import Path

p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')
old = "if (order.status == 'cancelled' || order.status == 'done')\n      return const SizedBox.shrink();"
new = "if (order.status == 'cancelled' ||\n        order.status == 'shipping' ||\n        order.status == 'done') {\n      return const SizedBox.shrink();\n    }"
if old not in s:
    raise SystemExit('Order action guard not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
print('Shipping is now the final app order stage with no further action buttons.')
