from pathlib import Path

p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')
old = '''                  "№ ${order.displayOrderNumber > 0 ? order.displayOrderNumber.toString().padLeft(4, '0') : order.id}",
'''
new = '''                  order.status == 'cancelled'
                      ? ''
                      : "№ ${order.displayOrderNumber > 0 ? order.displayOrderNumber.toString().padLeft(4, '0') : order.id}",
'''
assert old in s
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
