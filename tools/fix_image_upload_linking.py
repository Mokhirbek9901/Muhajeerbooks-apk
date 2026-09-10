from pathlib import Path
import re


admin = Path("lib/admin_ui.dart")
text = admin.read_text(encoding="utf-8")

old_parser = """    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final url = (data['url'] ?? '').toString();
"""
new_parser = """    final raw = response.data;
    Map<String, dynamic> data = <String, dynamic>{};
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Web/proxy ayrim hollarda JSON javobni string ko‘rinishida qaytaradi.
      }
    }
    final url = (data['url'] ?? '').toString();
"""
if old_parser in text:
    text = text.replace(old_parser, new_parser, 1)
elif new_parser not in text:
    raise SystemExit("admin upload response parser block not found")

pattern = re.compile(
    r"  Future<void> pickAndUploadImages\(\) async \{.*?\n  \}\n\n  void _makeCover",
    re.S,
)
replacement = r"""  Future<void> pickAndUploadImages() async {
    if (uploadingImage) return;
    final slots = 20 - gallery.length;
    if (slots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitta kitobga maksimal 20 ta rasm qo‘yiladi.'),
        ),
      );
      return;
    }

    try {
      final picked = await picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 2200,
      );
      if (picked.isEmpty) return;

      final selected = picked.take(slots).toList();
      setState(() => uploadingImage = true);
      var uploadedCount = 0;
      final errors = <String>[];

      // Har bir rasm alohida yuklanadi. Bitta rasmda xato bo‘lsa ham
      // oldin muvaffaqiyatli yuklangan rasmlar yo‘qolib ketmaydi.
      for (final file in selected) {
        try {
          final url = (await widget.api.uploadCover(file)).trim();
          if (url.isEmpty) {
            errors.add('${file.name}: bo‘sh manzil qaytdi');
            continue;
          }
          if (!mounted) return;
          if (!gallery.contains(url)) {
            setState(() {
              gallery = [...gallery, url].take(20).toList();
              _syncCoverController();
            });
            uploadedCount++;
          }
        } catch (e) {
          errors.add('${file.name}: $e');
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (uploadedCount == 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              errors.isEmpty
                  ? 'Rasm yuklanmadi.'
                  : 'Rasm yuklanmadi: ${errors.first}',
            ),
          ),
        );
      } else if (errors.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$uploadedCount ta rasm yuklandi ✅ Saqlash tugmasini bosing.',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$uploadedCount ta rasm yuklandi, ${errors.length} ta rasmda xato bo‘ldi.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rasm tanlashda xatolik: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingImage = false);
    }
  }

  void _makeCover"""
match = pattern.search(text)
if not match:
    raise SystemExit("pickAndUploadImages block not found")
if "oldin muvaffaqiyatli yuklangan rasmlar" not in match.group(0):
    text = pattern.sub(replacement, text, count=1)

admin.write_text(text, encoding="utf-8")

app = Path("lib/app_state.dart")
text = app.read_text(encoding="utf-8")
old_payment = """    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final path = (data['path'] ?? '').toString();
"""
new_payment = """    final raw = response.data;
    Map<String, dynamic> data = <String, dynamic>{};
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Web proxy ayrim hollarda JSON javobni string ko‘rinishida qaytarishi mumkin.
      }
    }
    final path = (data['path'] ?? '').toString();
"""
if old_payment in text:
    text = text.replace(old_payment, new_payment, 1)
elif new_payment not in text:
    raise SystemExit("payment proof response parser block not found")
app.write_text(text, encoding="utf-8")

nginx = Path("nginx.conf")
text = nginx.read_text(encoding="utf-8")
marker = "  server_name _;\n"
if "client_max_body_size 12m;" not in text:
    if marker not in text:
        raise SystemExit("nginx server marker not found")
    text = text.replace(marker, marker + "  client_max_body_size 12m;\n", 1)
nginx.write_text(text, encoding="utf-8")
