from pathlib import Path

p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')

old_label = """      case 'app':
        return 'Ilova / Web';
      case 'manual':
        return 'Qo‘lda';
"""
new_label = """      case 'app':
        return 'Ilova / Web';
      case 'instagram':
        return 'Instagram';
      case 'manual':
        return 'Qo‘lda';
"""
if old_label in s:
    s = s.replace(old_label, new_label, 1)
elif "case 'instagram':\n        return 'Instagram';" not in s:
    raise SystemExit('source label marker not found')

old_icon = """      case 'app':
        return Icons.phone_iphone_rounded;
      case 'manual':
        return Icons.edit_note_rounded;
"""
new_icon = """      case 'app':
        return Icons.phone_iphone_rounded;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'manual':
        return Icons.edit_note_rounded;
"""
if old_icon in s:
    s = s.replace(old_icon, new_icon, 1)
elif "case 'instagram':\n        return Icons.camera_alt_outlined;" not in s:
    raise SystemExit('source icon marker not found')

old_chip = """              ChoiceChip(
                label: const Text('Ilova'),
                selected: filter == 'app',
                onSelected: (_) => setState(() => filter = 'app'),
              ),
              ChoiceChip(
                label: const Text('Qo‘lda'),
"""
new_chip = """              ChoiceChip(
                label: const Text('Ilova'),
                selected: filter == 'app',
                onSelected: (_) => setState(() => filter = 'app'),
              ),
              ChoiceChip(
                label: const Text('Instagram'),
                selected: filter == 'instagram',
                onSelected: (_) => setState(() => filter = 'instagram'),
              ),
              ChoiceChip(
                label: const Text('Qo‘lda'),
"""
if old_chip in s:
    s = s.replace(old_chip, new_chip, 1)
elif "label: const Text('Instagram')" not in s:
    raise SystemExit('Instagram chip marker not found')

p.write_text(s, encoding='utf-8')
print('Instagram shipping tab patched')
