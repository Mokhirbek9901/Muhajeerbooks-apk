from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label}: expected source block not found in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def patch_app_state() -> None:
    path = ROOT / "lib/app_state.dart"
    text = path.read_text(encoding="utf-8")

    replacements = [
        (
            "    required this.imageUrl,\n    this.imageUrls = const [],",
            "    required this.imageUrl,\n    this.thumbnailUrl = '',\n    this.imageUrls = const [],",
        ),
        (
            "  final String imageUrl;\n  final List<String> imageUrls;",
            "  final String imageUrl;\n  final String thumbnailUrl;\n  final List<String> imageUrls;",
        ),
        (
            "  bool get inStock => stock > 0 && price > 0;\n\n  List<String> get galleryImages {",
            "  bool get inStock => stock > 0 && price > 0;\n  String get previewImageUrl =>\n      thumbnailUrl.trim().isNotEmpty ? thumbnailUrl.trim() : imageUrl;\n\n  List<String> get galleryImages {",
        ),
        (
            "    imageUrl: (map['image_url'] ?? '').toString(),\n    imageUrls:",
            "    imageUrl: (map['image_url'] ?? '').toString(),\n    thumbnailUrl: (map['thumbnail_url'] ?? '').toString(),\n    imageUrls:",
        ),
        (
            "    'image_url': galleryImages.isEmpty ? '' : galleryImages.first,\n    'image_urls': galleryImages,",
            "    'image_url': galleryImages.isEmpty ? '' : galleryImages.first,\n    'thumbnail_url': thumbnailUrl,\n    'image_urls': galleryImages,",
        ),
        (
            "    String? imageUrl,\n    List<String>? imageUrls,",
            "    String? imageUrl,\n    String? thumbnailUrl,\n    List<String>? imageUrls,",
        ),
        (
            "    imageUrl: imageUrl ?? this.imageUrl,\n    imageUrls: imageUrls ?? this.imageUrls,",
            "    imageUrl: imageUrl ?? this.imageUrl,\n    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,\n    imageUrls: imageUrls ?? this.imageUrls,",
        ),
        (
            "      'discount_percent,image_url,image_urls,is_active,cover_type,recommended,'",
            "      'discount_percent,image_url,thumbnail_url,image_urls,is_active,cover_type,recommended,'",
        ),
    ]

    for old, new in replacements:
        if new in text:
            continue
        if old not in text:
            raise SystemExit(f"app_state patch source not found: {old[:80]!r}")
        text = text.replace(old, new, 1)

    path.write_text(text, encoding="utf-8")


def patch_store_ui() -> None:
    path = ROOT / "lib/store_ui.dart"
    text = path.read_text(encoding="utf-8")
    old = """  @override
  Widget build(BuildContext context) {
    if (book.imageUrl.isNotEmpty) {
      return Image.network(
        book.imageUrl,
"""
    new = """  @override
  Widget build(BuildContext context) {
    final previewUrl = book.previewImageUrl;
    if (previewUrl.isNotEmpty) {
      return Image.network(
        previewUrl,
"""
    if new not in text:
        if old not in text:
            raise SystemExit("store_ui _BookCover block not found")
        text = text.replace(old, new, 1)
    path.write_text(text, encoding="utf-8")


def patch_admin_ui() -> None:
    path = ROOT / "lib/admin_ui.dart"
    text = path.read_text(encoding="utf-8")

    if "import 'dart:typed_data';" not in text:
        text = text.replace("import 'dart:convert';\n", "import 'dart:convert';\nimport 'dart:typed_data';\n", 1)
    if "package:http/http.dart' as http" not in text:
        text = text.replace(
            "import 'package:flutter_secure_storage/flutter_secure_storage.dart';\n",
            "import 'package:flutter_secure_storage/flutter_secure_storage.dart';\nimport 'package:http/http.dart' as http;\n",
            1,
        )
    if "package:image/image.dart' as img" not in text:
        text = text.replace(
            "import 'package:image_picker/image_picker.dart';\n",
            "import 'package:image/image.dart' as img;\nimport 'package:image_picker/image_picker.dart';\n",
            1,
        )

    helper_marker = "class _AdminApi {"
    if "class _UploadedBookImage" not in text:
        helper = r'''class _UploadedBookImage {
  const _UploadedBookImage({required this.url, required this.thumbnailUrl});
  final String url;
  final String thumbnailUrl;
}

img.Image _resizeWithin(img.Image source, int maxWidth, int maxHeight) {
  if (source.width <= maxWidth && source.height <= maxHeight) return source;
  final widthScale = maxWidth / source.width;
  final heightScale = maxHeight / source.height;
  final scale = widthScale < heightScale ? widthScale : heightScale;
  return img.copyResize(
    source,
    width: (source.width * scale).round().clamp(1, maxWidth),
    height: (source.height * scale).round().clamp(1, maxHeight),
    interpolation: img.Interpolation.linear,
  );
}

Uint8List _encodeJpegTarget(
  img.Image source, {
  required int targetBytes,
  required int startQuality,
  required int minQuality,
}) {
  var quality = startQuality;
  var bytes = Uint8List.fromList(img.encodeJpg(source, quality: quality));
  while (bytes.length > targetBytes && quality > minQuality) {
    quality = (quality - 4).clamp(minQuality, 100);
    bytes = Uint8List.fromList(img.encodeJpg(source, quality: quality));
  }
  return bytes;
}

Map<String, Uint8List>? _prepareBookImageVariants(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);

  var fullImage = _resizeWithin(oriented, 1200, 1800);
  var fullBytes = _encodeJpegTarget(
    fullImage,
    targetBytes: 220 * 1024,
    startQuality: 76,
    minQuality: 60,
  );
  if (fullBytes.length > 280 * 1024) {
    fullImage = _resizeWithin(fullImage, 1050, 1575);
    fullBytes = _encodeJpegTarget(
      fullImage,
      targetBytes: 240 * 1024,
      startQuality: 72,
      minQuality: 58,
    );
  }

  final thumbImage = _resizeWithin(oriented, 360, 540);
  final thumbBytes = _encodeJpegTarget(
    thumbImage,
    targetBytes: 34 * 1024,
    startQuality: 70,
    minQuality: 48,
  );

  return <String, Uint8List>{'full': fullBytes, 'thumb': thumbBytes};
}

Uint8List? _prepareBookThumbnail(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final thumbImage = _resizeWithin(oriented, 360, 540);
  return _encodeJpegTarget(
    thumbImage,
    targetBytes: 34 * 1024,
    startQuality: 70,
    minQuality: 48,
  );
}

Map<String, dynamic> _functionResponseMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Proxy ayrim hollarda JSON javobni string ko‘rinishida qaytaradi.
    }
  }
  return <String, dynamic>{};
}

'''
        if helper_marker not in text:
            raise SystemExit("admin helper insertion marker not found")
        text = text.replace(helper_marker, helper + helper_marker, 1)

    payload_old = """          'image_url': book.galleryImages.isEmpty
              ? ''
              : book.galleryImages.first,
          'image_urls': book.galleryImages,
"""
    payload_new = """          'image_url': book.galleryImages.isEmpty
              ? ''
              : book.galleryImages.first,
          'thumbnail_url': book.thumbnailUrl,
          'image_urls': book.galleryImages,
"""
    if payload_new not in text:
        if payload_old not in text:
            raise SystemExit("admin saveBook image payload block not found")
        text = text.replace(payload_old, payload_new, 1)

    upload_pattern = re.compile(
        r"  Future<String> uploadCover\(XFile file\) async \{.*?\n  \}\n\n  Future<void> deleteBook",
        re.S,
    )
    if "Future<_UploadedBookImage> uploadCover" not in text:
        replacement = r'''  Future<_UploadedBookImage> uploadCover(XFile file) async {
    final sourceBytes = await file.readAsBytes();
    if (sourceBytes.isEmpty) throw StateError('Rasm bo‘sh.');
    if (sourceBytes.length > 20 * 1024 * 1024) {
      throw StateError('Rasm hajmi 20 MB dan kichik bo‘lishi kerak.');
    }

    final prepared = await compute(
      _prepareBookImageVariants,
      Uint8List.fromList(sourceBytes),
    );

    Uint8List uploadBytes;
    Uint8List? thumbBytes;
    String contentType;
    String uploadName;

    if (prepared != null) {
      uploadBytes = prepared['full']!;
      thumbBytes = prepared['thumb'];
      contentType = 'image/jpeg';
      final base = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      uploadName = '${base.isEmpty ? 'cover' : base}.jpg';
    } else {
      if (sourceBytes.length > 7 * 1024 * 1024) {
        throw StateError('Bu rasmni optimallashtirib bo‘lmadi. Boshqa JPG/PNG rasm tanlang.');
      }
      uploadBytes = Uint8List.fromList(sourceBytes);
      final lower = file.name.toLowerCase();
      contentType = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      uploadName = file.name;
    }

    final body = <String, dynamic>{
      'admin_code': secret,
      'file_name': uploadName,
      'content_type': contentType,
      'data_base64': base64Encode(uploadBytes),
    };
    if (thumbBytes != null && thumbBytes.isNotEmpty) {
      body['thumb_base64'] = base64Encode(thumbBytes);
    }

    final response = await client.functions.invoke(
      'admin-cover-upload',
      body: body,
    );
    final data = _functionResponseMap(response.data);
    final url = (data['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw StateError((data['error'] ?? 'Rasm yuklanmadi.').toString());
    }
    return _UploadedBookImage(
      url: url,
      thumbnailUrl: (data['thumbnail_url'] ?? '').toString().trim(),
    );
  }

  Future<void> backfillThumbnail(Book book) async {
    if (book.id.isEmpty ||
        book.thumbnailUrl.trim().isNotEmpty ||
        book.imageUrl.trim().isEmpty) {
      return;
    }

    final uri = Uri.tryParse(book.imageUrl.trim());
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;

    final downloaded = await http.get(uri).timeout(const Duration(seconds: 20));
    if (downloaded.statusCode < 200 || downloaded.statusCode >= 300) return;
    if (downloaded.bodyBytes.isEmpty || downloaded.bodyBytes.length > 10 * 1024 * 1024) {
      return;
    }

    final thumbBytes = await compute(
      _prepareBookThumbnail,
      Uint8List.fromList(downloaded.bodyBytes),
    );
    if (thumbBytes == null || thumbBytes.isEmpty) return;

    final response = await client.functions.invoke(
      'admin-cover-upload',
      body: {
        'admin_code': secret,
        'action': 'thumbnail',
        'file_name': 'thumb-${book.id}.jpg',
        'content_type': 'image/jpeg',
        'data_base64': base64Encode(thumbBytes),
      },
    );
    final data = _functionResponseMap(response.data);
    final thumbUrl = (data['thumbnail_url'] ?? data['url'] ?? '')
        .toString()
        .trim();
    if (thumbUrl.isEmpty) return;

    await client.rpc(
      'admin_set_book_thumbnail',
      params: {
        'p_secret': secret,
        'p_id': book.id,
        'p_thumbnail_url': thumbUrl,
      },
    );
  }

  Future<void> deleteBook'''
        text, count = upload_pattern.subn(replacement, text, count=1)
        if count != 1:
            raise SystemExit("admin uploadCover method block not found")

    state_old = """  bool uploadingImage = false;
  List<String> gallery = [];
"""
    state_new = """  bool uploadingImage = false;
  List<String> gallery = [];
  String thumbnailUrl = '';
  final Map<String, String> thumbnailByUrl = <String, String>{};
"""
    if state_new not in text:
        if state_old not in text:
            raise SystemExit("book form state block not found")
        text = text.replace(state_old, state_new, 1)

    init_old = """    gallery = b?.galleryImages.toList() ?? <String>[];
    image = TextEditingController(
      text: gallery.isNotEmpty ? gallery.first : b?.imageUrl ?? '',
    );
"""
    init_new = """    gallery = b?.galleryImages.toList() ?? <String>[];
    thumbnailUrl = b?.thumbnailUrl.trim() ?? '';
    if (b != null &&
        b.imageUrl.trim().isNotEmpty &&
        thumbnailUrl.isNotEmpty) {
      thumbnailByUrl[b.imageUrl.trim()] = thumbnailUrl;
    }
    image = TextEditingController(
      text: gallery.isNotEmpty ? gallery.first : b?.imageUrl ?? '',
    );
"""
    if init_new not in text:
        if init_old not in text:
            raise SystemExit("book form init gallery block not found")
        text = text.replace(init_old, init_new, 1)

    sync_old = """  void _syncCoverController() {
    final first = gallery.isEmpty ? '' : gallery.first;
    if (image.text != first) image.text = first;
  }
"""
    sync_new = """  void _syncCoverController() {
    final first = gallery.isEmpty ? '' : gallery.first;
    if (image.text != first) image.text = first;
    if (first.isEmpty) {
      thumbnailUrl = '';
      return;
    }
    final mapped = thumbnailByUrl[first]?.trim() ?? '';
    if (mapped.isNotEmpty) {
      thumbnailUrl = mapped;
      return;
    }
    final oldBook = widget.book;
    if (oldBook != null && oldBook.imageUrl.trim() == first) {
      thumbnailUrl = oldBook.thumbnailUrl.trim();
    } else {
      thumbnailUrl = '';
    }
  }
"""
    if sync_new not in text:
        if sync_old not in text:
            raise SystemExit("sync cover block not found")
        text = text.replace(sync_old, sync_new, 1)

    picker_old = """      final picked = await picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 2200,
      );
"""
    picker_new = """      final picked = await picker.pickMultiImage(
        imageQuality: 92,
        maxWidth: 2200,
        maxHeight: 3000,
      );
"""
    if picker_new not in text:
        if picker_old not in text:
            raise SystemExit("image picker settings block not found")
        text = text.replace(picker_old, picker_new, 1)

    upload_loop_old = """          final url = (await widget.api.uploadCover(file)).trim();
          if (url.isEmpty) {
            errors.add('${file.name}: bo‘sh manzil qaytdi');
            continue;
          }
          if (!mounted) return;
          if (!gallery.contains(url)) {
            setState(() {
              gallery = [...gallery, url].take(10).toList();
              _syncCoverController();
            });
            uploadedCount++;
          }
"""
    upload_loop_new = """          final uploaded = await widget.api.uploadCover(file);
          final url = uploaded.url.trim();
          if (url.isEmpty) {
            errors.add('${file.name}: bo‘sh manzil qaytdi');
            continue;
          }
          final thumb = uploaded.thumbnailUrl.trim();
          if (thumb.isNotEmpty) thumbnailByUrl[url] = thumb;
          if (!mounted) return;
          if (!gallery.contains(url)) {
            setState(() {
              gallery = [...gallery, url].take(10).toList();
              _syncCoverController();
            });
            uploadedCount++;
          }
"""
    if upload_loop_new not in text:
        if upload_loop_old not in text:
            raise SystemExit("book upload loop block not found")
        text = text.replace(upload_loop_old, upload_loop_new, 1)

    remove_old = """    setState(() {
      gallery.removeAt(index);
      _syncCoverController();
    });
"""
    remove_new = """    setState(() {
      final removed = gallery.removeAt(index);
      thumbnailByUrl.remove(removed);
      _syncCoverController();
    });
"""
    if remove_new not in text:
        if remove_old not in text:
            raise SystemExit("gallery remove block not found")
        text = text.replace(remove_old, remove_new, 1)

    save_book_old = """          imageUrl: urls.isEmpty ? '' : urls.first,
          imageUrls: urls,
"""
    save_book_new = """          imageUrl: urls.isEmpty ? '' : urls.first,
          thumbnailUrl: urls.isEmpty ? '' : thumbnailUrl.trim(),
          imageUrls: urls,
"""
    if save_book_new not in text:
        if save_book_old not in text:
            raise SystemExit("Book save constructor image block not found")
        text = text.replace(save_book_old, save_book_new, 1)

    init_books_old = """  @override
  void initState() {
    super.initState();
    future = widget.api.books();
    unawaited(_loadSales());
  }
"""
    init_books_new = """  @override
  void initState() {
    super.initState();
    future = widget.api.books();
    unawaited(_startThumbnailBackfill(future));
    unawaited(_loadSales());
  }

  Future<void> _startThumbnailBackfill(Future<List<Book>> source) async {
    try {
      final books = await source;
      await _backfillMissingThumbnails(books);
    } catch (_) {
      // Eski rasmlarni kichraytirish admin ishini hech qachon bloklamaydi.
    }
  }

  Future<void> _backfillMissingThumbnails(List<Book> books) async {
    final pending = books
        .where(
          (book) =>
              book.id.isNotEmpty &&
              book.thumbnailUrl.trim().isEmpty &&
              book.imageUrl.trim().isNotEmpty,
        )
        .toList();
    for (var i = 0; i < pending.length; i++) {
      if (!mounted) return;
      try {
        await widget.api.backfillThumbnail(pending[i]);
      } catch (_) {
        // Bitta eski rasm xato bo‘lsa qolganlari davom etadi.
      }
      if (i + 1 < pending.length) {
        await Future<void>.delayed(const Duration(milliseconds: 2300));
      }
    }
  }
"""
    if init_books_new not in text:
        if init_books_old not in text:
            raise SystemExit("BooksAdmin initState block not found")
        text = text.replace(init_books_old, init_books_new, 1)

    text = text.replace("_AdminBookThumb(url: b.imageUrl)", "_AdminBookThumb(url: b.previewImageUrl)")

    path.write_text(text, encoding="utf-8")


def verify() -> None:
    app = (ROOT / "lib/app_state.dart").read_text(encoding="utf-8")
    admin = (ROOT / "lib/admin_ui.dart").read_text(encoding="utf-8")
    store = (ROOT / "lib/store_ui.dart").read_text(encoding="utf-8")
    checks = {
        "Book.thumbnailUrl": "final String thumbnailUrl;" in app,
        "Book.previewImageUrl": "String get previewImageUrl" in app,
        "store preview image": "final previewUrl = book.previewImageUrl;" in store,
        "optimized full image": "targetBytes: 220 * 1024" in admin,
        "optimized thumbnail": "targetBytes: 34 * 1024" in admin,
        "thumbnail backfill": "_backfillMissingThumbnails" in admin,
        "thumbnail save": "'thumbnail_url': book.thumbnailUrl" in admin,
    }
    missing = [name for name, ok in checks.items() if not ok]
    if missing:
        raise SystemExit("Verification failed: " + ", ".join(missing))


if __name__ == "__main__":
    patch_app_state()
    patch_store_ui()
    patch_admin_ui()
    verify()
    print("Free-plan image optimization patch applied.")
