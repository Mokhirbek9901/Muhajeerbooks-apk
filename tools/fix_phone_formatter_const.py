from pathlib import Path

path = Path('lib/store_ui.dart')
text = path.read_text(encoding='utf-8')
old = """                      inputFormatters: const [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
"""
new = """                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
"""
if text.count(old) != 1:
    raise SystemExit(f'Expected exactly one phone formatter block, found {text.count(old)}')
text = text.replace(old, new, 1)
text = text.replace("hintText: '01024338600',", "hintText: 'Masalan: 01024338600',", 1)
path.write_text(text, encoding='utf-8')
print('Phone formatter compile fix applied')
