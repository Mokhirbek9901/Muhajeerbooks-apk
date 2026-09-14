from pathlib import Path
import re

p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')

pattern = re.compile(
    r"  Future<void> backfillThumbnail\(Book book\) async \{.*?\n  \}\n\n  Future<void> deleteBook",
    re.S,
)

replacement = r'''  Future<void> backfillThumbnail(Book book) async {
    if (book.id.isEmpty ||
        book.thumbnailUrl.trim().isNotEmpty ||
        book.imageUrl.trim().isEmpty) {
      return;
    }

    final uri = Uri.tryParse(book.imageUrl.trim());
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;

    final downloaded = await http.get(uri).timeout(const Duration(seconds: 20));
    if (downloaded.statusCode < 200 || downloaded.statusCode >= 300) return;
    if (downloaded.bodyBytes.isEmpty ||
        downloaded.bodyBytes.length > 10 * 1024 * 1024) {
      return;
    }

    final prepared = await compute(
      _prepareBookImageVariants,
      Uint8List.fromList(downloaded.bodyBytes),
    );
    if (prepared == null) return;
    final fullBytes = prepared['full'];
    final thumbBytes = prepared['thumb'];
    if (fullBytes == null ||
        fullBytes.isEmpty ||
        thumbBytes == null ||
        thumbBytes.isEmpty) {
      return;
    }

    final response = await client.functions.invoke(
      'admin-cover-upload',
      body: {
        'admin_code': secret,
        'file_name': 'optimized-${book.id}.jpg',
        'content_type': 'image/jpeg',
        'data_base64': base64Encode(fullBytes),
        'thumb_base64': base64Encode(thumbBytes),
      },
    );
    final data = _functionResponseMap(response.data);
    final optimizedUrl = (data['url'] ?? '').toString().trim();
    final thumbUrl = (data['thumbnail_url'] ?? '').toString().trim();
    if (optimizedUrl.isEmpty || thumbUrl.isEmpty) return;

    final oldGallery = book.galleryImages;
    final optimizedGallery = <String>[
      optimizedUrl,
      ...oldGallery.skip(1),
    ];

    await saveBook(
      book.copyWith(
        imageUrl: optimizedUrl,
        thumbnailUrl: thumbUrl,
        imageUrls: optimizedGallery,
      ),
    );
  }

  Future<void> deleteBook'''

new_s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    if "'file_name': 'optimized-${book.id}.jpg'" in s:
        print('Legacy cover optimization already applied.')
        raise SystemExit(0)
    raise SystemExit('backfillThumbnail block not found')

p.write_text(new_s, encoding='utf-8')
print('Legacy first-cover optimization applied.')
