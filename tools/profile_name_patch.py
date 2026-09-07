from pathlib import Path

path = Path('lib/store_ui.dart')
text = path.read_text(encoding='utf-8')

old = """                const UzbekMedallion(size: 58, dark: true),\n                const SizedBox(height: 10),\n                const Text(\n                  'Mohirbek Ismoilov',"""
new = """                const Text(\n                  'Mohirbek Ismoilov',"""

if old not in text:
    raise SystemExit('Profile header pattern not found')

text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('Profile updated: Mohirbek Ismoilov, no portrait/avatar image.')
