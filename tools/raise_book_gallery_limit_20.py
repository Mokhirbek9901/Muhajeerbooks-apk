from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


# Book model: keep and read up to 20 images.
p = Path('lib/app_state.dart')
s = p.read_text(encoding='utf-8')
s = replace_once(
    s,
    '      if (result.length == 10) break;',
    '      if (result.length == 20) break;',
    'gallery getter limit',
)
s = replace_once(
    s,
    "    imageUrls: ((map['image_urls'] as List?) ?? const [])\n        .map((e) => e.toString().trim())\n        .where((e) => e.isNotEmpty)\n        .take(10)\n        .toList(),",
    "    imageUrls: ((map['image_urls'] as List?) ?? const [])\n        .map((e) => e.toString().trim())\n        .where((e) => e.isNotEmpty)\n        .take(20)\n        .toList(),",
    'fromMap gallery limit',
)
p.write_text(s, encoding='utf-8')


# Admin editor: allow selecting, uploading, saving and displaying up to 20 images.
p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')
s = replace_once(
    s,
    '    final slots = 10 - gallery.length;',
    '    final slots = 20 - gallery.length;',
    'remaining gallery slots',
)
s = replace_once(
    s,
    "          content: Text('Bitta kitobga maksimal 10 ta rasm qo‘yiladi.'),",
    "          content: Text('Bitta kitobga maksimal 20 ta rasm qo‘yiladi.'),",
    'gallery limit snackbar',
)
s = replace_once(
    s,
    '        gallery = [...gallery, ...uploaded].take(10).toList();',
    '        gallery = [...gallery, ...uploaded].take(20).toList();',
    'uploaded gallery cap',
)
s = replace_once(
    s,
    "    var urls = gallery\n        .map((e) => e.trim())\n        .where((e) => e.isNotEmpty)\n        .toSet()\n        .take(10)\n        .toList();",
    "    var urls = gallery\n        .map((e) => e.trim())\n        .where((e) => e.isNotEmpty)\n        .toSet()\n        .take(20)\n        .toList();",
    'saved gallery cap',
)
s = replace_once(
    s,
    '                onPressed: uploadingImage || gallery.length >= 10',
    '                onPressed: uploadingImage || gallery.length >= 20',
    'gallery picker button cap',
)
s = replace_once(
    s,
    ": 'Rasmlar tanlash (${gallery.length}/10)',",
    ": 'Rasmlar tanlash (${gallery.length}/20)',",
    'gallery picker counter',
)
s = replace_once(
    s,
    "                '1-rasm — kitob muqovasi. U ilovada ham, Telegram botda ham asosiy rasm bo‘ladi. Qolgan rasmlar kitob ichini ko‘rsatish uchun. Maksimal 10 ta.',",
    "                '1-rasm — kitob muqovasi. U ilovada ham, Telegram botda ham asosiy rasm bo‘ladi. Qolgan rasmlar kitob ichini ko‘rsatish uchun. Maksimal 20 ta.',",
    'gallery helper text',
)
p.write_text(s, encoding='utf-8')

print('Book gallery limit raised from 10 to 20 images.')
