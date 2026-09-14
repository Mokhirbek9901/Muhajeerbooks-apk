from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

# ---------- app_state.dart ----------
app = ROOT / 'lib/app_state.dart'
s = app.read_text(encoding='utf-8')

marker = "class Book {"
if "bool isOptimizedBookImageUrl(" not in s:
    helper = r'''bool isOptimizedBookImageUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  final path = uri?.path ?? value;
  return path.contains('/book-covers/covers/') &&
      (path.contains('-opt-') || path.contains('-optimized-'));
}

String derivedBookThumbnailUrl(String raw) {
  final value = raw.trim();
  if (!isOptimizedBookImageUrl(value)) return '';
  final uri = Uri.tryParse(value);
  if (uri == null) return '';
  var path = uri.path.replaceFirst('/book-covers/covers/', '/book-covers/covers/thumbs/');
  path = path.replaceFirst(RegExp(r'\.[^.\/]+$'), '.jpg');
  return uri.replace(path: path).toString();
}

'''
    if marker not in s:
        raise SystemExit('Book marker not found')
    s = s.replace(marker, helper + marker, 1)

old = """  String get previewImageUrl =>
      thumbnailUrl.trim().isNotEmpty ? thumbnailUrl.trim() : imageUrl;

  List<String> get galleryImages {
"""
new = """  String get previewImageUrl =>
      thumbnailUrl.trim().isNotEmpty ? thumbnailUrl.trim() : imageUrl;

  bool get galleryImagesOptimized =>
      galleryImages.every(isOptimizedBookImageUrl);

  String galleryThumbnailUrlAt(int index) {
    final images = galleryImages;
    if (index < 0 || index >= images.length) return '';
    if (index == 0 && thumbnailUrl.trim().isNotEmpty) {
      return thumbnailUrl.trim();
    }
    final derived = derivedBookThumbnailUrl(images[index]);
    return derived.isNotEmpty ? derived : images[index];
  }

  List<String> get galleryImages {
"""
if new not in s:
    if old not in s:
        raise SystemExit('Book preview block not found')
    s = s.replace(old, new, 1)
app.write_text(s, encoding='utf-8')

# ---------- admin_ui.dart ----------
admin = ROOT / 'lib/admin_ui.dart'
s = admin.read_text(encoding='utf-8')

# New uploads get a marker so their paired thumbnail URL can safely be derived.
old = "uploadName = '${base.isEmpty ? 'cover' : base}.jpg';"
new = "uploadName = 'opt-${base.isEmpty ? 'cover' : base}.jpg';"
if new not in s:
    if old not in s:
        raise SystemExit('uploadName block not found')
    s = s.replace(old, new, 1)

pattern = re.compile(
    r"  Future<void> backfillThumbnail\(Book book\) async \{.*?\n  \}\n\n  Future<void> deleteBook",
    re.S,
)
replacement = r'''  Future<void> backfillThumbnail(Book book) async {
    final sourceGallery = book.galleryImages;
    if (book.id.isEmpty || sourceGallery.isEmpty) return;
    if (book.thumbnailUrl.trim().isNotEmpty && book.galleryImagesOptimized) {
      return;
    }

    final optimizedGallery = <String>[];
    var firstThumbnail = book.thumbnailUrl.trim();
    var changed = false;

    for (var index = 0; index < sourceGallery.length; index++) {
      final sourceUrl = sourceGallery[index].trim();
      if (sourceUrl.isEmpty) continue;

      if (isOptimizedBookImageUrl(sourceUrl)) {
        optimizedGallery.add(sourceUrl);
        if (index == 0 && firstThumbnail.isEmpty) {
          firstThumbnail = derivedBookThumbnailUrl(sourceUrl);
        }
        continue;
      }

      try {
        final uri = Uri.tryParse(sourceUrl);
        if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
          optimizedGallery.add(sourceUrl);
          continue;
        }

        final downloaded = await http.get(uri).timeout(const Duration(seconds: 20));
        if (downloaded.statusCode < 200 || downloaded.statusCode >= 300) {
          optimizedGallery.add(sourceUrl);
          continue;
        }
        if (downloaded.bodyBytes.isEmpty ||
            downloaded.bodyBytes.length > 10 * 1024 * 1024) {
          optimizedGallery.add(sourceUrl);
          continue;
        }

        final prepared = await compute(
          _prepareBookImageVariants,
          Uint8List.fromList(downloaded.bodyBytes),
        );
        if (prepared == null) {
          optimizedGallery.add(sourceUrl);
          continue;
        }
        final fullBytes = prepared['full'];
        final thumbBytes = prepared['thumb'];
        if (fullBytes == null ||
            fullBytes.isEmpty ||
            thumbBytes == null ||
            thumbBytes.isEmpty) {
          optimizedGallery.add(sourceUrl);
          continue;
        }

        final response = await client.functions.invoke(
          'admin-cover-upload',
          body: {
            'admin_code': secret,
            'file_name': 'optimized-${book.id}-$index.jpg',
            'content_type': 'image/jpeg',
            'data_base64': base64Encode(fullBytes),
            'thumb_base64': base64Encode(thumbBytes),
          },
        );
        final data = _functionResponseMap(response.data);
        final optimizedUrl = (data['url'] ?? '').toString().trim();
        final thumbUrl = (data['thumbnail_url'] ?? '').toString().trim();
        if (optimizedUrl.isEmpty || thumbUrl.isEmpty) {
          optimizedGallery.add(sourceUrl);
          continue;
        }

        optimizedGallery.add(optimizedUrl);
        if (index == 0) firstThumbnail = thumbUrl;
        changed = true;

        // Edge Function rate limitini oshirmaslik uchun rasmlarni navbat bilan o'tkazamiz.
        if (index + 1 < sourceGallery.length) {
          await Future<void>.delayed(const Duration(milliseconds: 2200));
        }
      } catch (_) {
        optimizedGallery.add(sourceUrl);
      }
    }

    if (optimizedGallery.isEmpty) return;
    final first = optimizedGallery.first;
    if (firstThumbnail.isEmpty) {
      firstThumbnail = derivedBookThumbnailUrl(first);
    }

    if (!changed &&
        firstThumbnail == book.thumbnailUrl.trim() &&
        optimizedGallery.length == sourceGallery.length) {
      return;
    }

    await saveBook(
      book.copyWith(
        imageUrl: first,
        thumbnailUrl: firstThumbnail,
        imageUrls: optimizedGallery,
      ),
    );
  }

  Future<void> deleteBook'''

new_s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    if "'file_name': 'optimized-${book.id}-$index.jpg'" not in s:
        raise SystemExit('backfillThumbnail block not found')
else:
    s = new_s

old_filter = """              book.id.isNotEmpty &&
              book.thumbnailUrl.trim().isEmpty &&
              book.imageUrl.trim().isNotEmpty,
"""
new_filter = """              book.id.isNotEmpty &&
              book.imageUrl.trim().isNotEmpty &&
              (book.thumbnailUrl.trim().isEmpty || !book.galleryImagesOptimized),
"""
if new_filter not in s:
    if old_filter not in s:
        raise SystemExit('backfill pending filter not found')
    s = s.replace(old_filter, new_filter, 1)

admin.write_text(s, encoding='utf-8')

# ---------- store_ui.dart ----------
store = ROOT / 'lib/store_ui.dart'
s = store.read_text(encoding='utf-8')
old = """                    child: Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      cacheWidth: 160,
"""
new = """                    child: Image.network(
                      widget.book.galleryThumbnailUrlAt(i),
                      fit: BoxFit.cover,
                      cacheWidth: 160,
"""
if new not in s:
    if old not in s:
        raise SystemExit('gallery thumbnail Image.network block not found')
    s = s.replace(old, new, 1)
store.write_text(s, encoding='utf-8')

# Verification
app_s = app.read_text(encoding='utf-8')
admin_s = admin.read_text(encoding='utf-8')
store_s = store.read_text(encoding='utf-8')
checks = [
    'galleryThumbnailUrlAt' in app_s,
    'galleryImagesOptimized' in app_s,
    "uploadName = 'opt-" in admin_s,
    "optimized-${book.id}-$index.jpg" in admin_s,
    '!book.galleryImagesOptimized' in admin_s,
    'widget.book.galleryThumbnailUrlAt(i)' in store_s,
]
if not all(checks):
    raise SystemExit('gallery optimization verification failed')
print('All gallery images now use paired tiny thumbnails without changing UI.')
