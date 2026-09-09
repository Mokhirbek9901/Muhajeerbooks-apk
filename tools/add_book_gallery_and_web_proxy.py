from pathlib import Path


def rep(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'{label}: expected 1 match, got {n}')
    return text.replace(old, new, 1)

# ---------------------------------------------------------------------------
# main.dart: web uses same-origin Railway proxy for Supabase. This avoids
# browser/ISP/CORS/stale-auth edge cases while APK keeps direct Supabase.
# ---------------------------------------------------------------------------
p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
s = rep(
    s,
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';\n",
    'main foundation import',
)
s = rep(
    s,
    "  final backendConfigured =\n      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;\n\n  if (backendConfigured) {\n    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);",
    "  final effectiveSupabaseUrl = kIsWeb\n      ? '${Uri.base.origin}/supabase'\n      : supabaseUrl;\n  final backendConfigured =\n      effectiveSupabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;\n\n  if (backendConfigured) {\n    await Supabase.initialize(\n      url: effectiveSupabaseUrl,\n      anonKey: supabaseAnonKey,\n    );",
    'same-origin web supabase',
)
p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# nginx: proxy the full Supabase API (REST/RPC/functions/storage/realtime) under
# the live Railway origin. Flutter web therefore needs only one reachable host.
# ---------------------------------------------------------------------------
p = Path('nginx.conf')
s = p.read_text(encoding='utf-8')
anchor = "  # Flutter web yangilanganda iPhone/Safari eski JS yoki service worker'ni ushlab\n"
proxy = """  # Flutter web uchun Supabase same-origin proxy.\n  # REST/RPC, Edge Functions, Storage va Realtime bir xil Railway domenidan o'tadi.\n  location /supabase/ {\n    proxy_pass https://rytfhjvhjxnbhgitowho.supabase.co/;\n    proxy_http_version 1.1;\n    proxy_set_header Host rytfhjvhjxnbhgitowho.supabase.co;\n    proxy_set_header Upgrade $http_upgrade;\n    proxy_set_header Connection \"upgrade\";\n    proxy_ssl_server_name on;\n    proxy_ssl_name rytfhjvhjxnbhgitowho.supabase.co;\n    proxy_read_timeout 120s;\n    proxy_send_timeout 120s;\n    proxy_buffering off;\n    add_header Cache-Control \"no-store\" always;\n  }\n\n"""
if proxy not in s:
    if anchor not in s:
        raise SystemExit('nginx proxy anchor missing')
    s = s.replace(anchor, proxy + anchor, 1)
p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# app_state.dart: Book supports up to 10 app images. imageUrl stays canonical
# cover and galleryImages always places it first for bot compatibility.
# ---------------------------------------------------------------------------
p = Path('lib/app_state.dart')
s = p.read_text(encoding='utf-8')
s = rep(
    s,
    "    required this.imageUrl,\n    required this.isActive,",
    "    required this.imageUrl,\n    this.imageUrls = const [],\n    required this.isActive,",
    'book constructor imageUrls',
)
s = rep(
    s,
    "  final String imageUrl;\n  final bool isActive;",
    "  final String imageUrl;\n  final List<String> imageUrls;\n  final bool isActive;",
    'book imageUrls field',
)
s = rep(
    s,
    "  bool get inStock => stock > 0 && price > 0;\n\n  factory Book.fromMap",
    "  bool get inStock => stock > 0 && price > 0;\n\n  List<String> get galleryImages {\n    final result = <String>[];\n    for (final raw in [imageUrl, ...imageUrls]) {\n      final url = raw.trim();\n      if (url.isEmpty || result.contains(url)) continue;\n      result.add(url);\n      if (result.length == 10) break;\n    }\n    return result;\n  }\n\n  factory Book.fromMap",
    'book gallery getter',
)
s = rep(
    s,
    "    imageUrl: (map['image_url'] ?? '').toString(),\n    isActive: map['is_active'] as bool? ?? true,",
    "    imageUrl: (map['image_url'] ?? '').toString(),\n    imageUrls: ((map['image_urls'] as List?) ?? const [])\n        .map((e) => e.toString().trim())\n        .where((e) => e.isNotEmpty)\n        .take(10)\n        .toList(),\n    isActive: map['is_active'] as bool? ?? true,",
    'fromMap gallery',
)
s = rep(
    s,
    "    'image_url': imageUrl,\n    'is_active': isActive,",
    "    'image_url': galleryImages.isEmpty ? '' : galleryImages.first,\n    'image_urls': galleryImages,\n    'is_active': isActive,",
    'toDb gallery',
)
s = rep(
    s,
    "    String? imageUrl,\n    bool? isActive,",
    "    String? imageUrl,\n    List<String>? imageUrls,\n    bool? isActive,",
    'copyWith gallery param',
)
s = rep(
    s,
    "    imageUrl: imageUrl ?? this.imageUrl,\n    isActive: isActive ?? this.isActive,",
    "    imageUrl: imageUrl ?? this.imageUrl,\n    imageUrls: imageUrls ?? this.imageUrls,\n    isActive: isActive ?? this.isActive,",
    'copyWith gallery value',
)
s = rep(
    s,
    "          b.imageUrl,\n          b.isActive,",
    "          b.imageUrl,\n          b.galleryImages.join('↕'),\n          b.isActive,",
    'catalog stamp gallery',
)
# First visit must still show catalog if Supabase is temporarily unreachable.
s = rep(
    s,
    "        if (cached.isNotEmpty) {\n          _books\n            ..clear()\n            ..addAll(cached);\n          _sanitizeCart();\n        }\n      }\n    } finally {",
    "        if (cached.isNotEmpty) {\n          _books\n            ..clear()\n            ..addAll(cached);\n          _sanitizeCart();\n        } else {\n          try {\n            final seed = await _loadTelegramSeed();\n            if (seed.isNotEmpty) {\n              _books\n                ..clear()\n                ..addAll(seed);\n              _sanitizeCart();\n            }\n          } catch (_) {}\n        }\n      }\n    } finally {",
    'catalog emergency fallback',
)
p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# admin_ui.dart: admin saves gallery, can upload up to 10 images, reorder cover
# by tapping star, and delete individual inside images.
# ---------------------------------------------------------------------------
p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')
s = rep(
    s,
    "          'image_url': book.imageUrl,\n          'is_active': book.isActive,",
    "          'image_url': book.galleryImages.isEmpty\n              ? ''\n              : book.galleryImages.first,\n          'image_urls': book.galleryImages,\n          'is_active': book.isActive,",
    'admin api gallery payload',
)
s = rep(
    s,
    "  bool saving = false;\n  bool uploadingImage = false;",
    "  bool saving = false;\n  bool uploadingImage = false;\n  List<String> gallery = [];",
    'book form gallery state',
)
s = rep(
    s,
    "    image = TextEditingController(text: b?.imageUrl ?? '');\n    cost = TextEditingController(",
    "    gallery = b?.galleryImages.toList() ?? <String>[];\n    image = TextEditingController(\n      text: gallery.isNotEmpty ? gallery.first : b?.imageUrl ?? '',\n    );\n    cost = TextEditingController(",
    'book form gallery init',
)
start = s.find('  Future<void> pickAndUploadImage() async {')
end = s.find('\n  Future<void> save() async {', start)
if start < 0 or end < 0:
    raise SystemExit('pick image function bounds missing')
new_upload = r'''  void _syncCoverController() {
    final first = gallery.isEmpty ? '' : gallery.first;
    if (image.text != first) image.text = first;
  }

  Future<void> pickAndUploadImages() async {
    if (uploadingImage) return;
    final slots = 10 - gallery.length;
    if (slots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitta kitobga maksimal 10 ta rasm qo‘yiladi.')),
      );
      return;
    }
    try {
      final picked = await picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (picked.isEmpty) return;
      final selected = picked.take(slots).toList();
      setState(() => uploadingImage = true);
      final uploaded = <String>[];
      for (final file in selected) {
        final url = await widget.api.uploadCover(file);
        if (url.trim().isNotEmpty && !gallery.contains(url)) uploaded.add(url);
      }
      if (!mounted) return;
      setState(() {
        gallery = [...gallery, ...uploaded].take(10).toList();
        _syncCoverController();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${uploaded.length} ta rasm yuklandi ✅')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rasm yuklashda xatolik: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingImage = false);
    }
  }

  void _makeCover(int index) {
    if (index <= 0 || index >= gallery.length) return;
    setState(() {
      final selected = gallery.removeAt(index);
      gallery.insert(0, selected);
      _syncCoverController();
    });
  }

  void _removeGalleryImage(int index) {
    if (index < 0 || index >= gallery.length) return;
    setState(() {
      gallery.removeAt(index);
      _syncCoverController();
    });
  }
'''
s = s[:start] + new_upload + s[end:]

# Save exact gallery; manual URL remains supported when no gallery is uploaded.
s = rep(
    s,
    "    setState(() => saving = true);\n    try {\n      await widget.api.saveBook(\n        Book(",
    "    var urls = gallery\n        .map((e) => e.trim())\n        .where((e) => e.isNotEmpty)\n        .toSet()\n        .take(10)\n        .toList();\n    final manualCover = image.text.trim();\n    if (urls.isEmpty && manualCover.isNotEmpty) urls = [manualCover];\n    setState(() => saving = true);\n    try {\n      await widget.api.saveBook(\n        Book(",
    'prepare gallery save',
)
s = rep(
    s,
    "          imageUrl: image.text.trim(),\n          isActive: active,",
    "          imageUrl: urls.isEmpty ? '' : urls.first,\n          imageUrls: urls,\n          isActive: active,",
    'save gallery book',
)
s = rep(
    s,
    "    final imageUrl = image.text.trim();\n    return Scaffold(",
    "    final imageUrl = gallery.isNotEmpty ? gallery.first : image.text.trim();\n    return Scaffold(",
    'build cover source',
)
# Replace single-image admin block with multi-image editor.
block_start = s.find('            Center(\n              child: Container(\n                width: 150,')
block_end_marker = "            field(title, 'Kitob nomi', required: true),"
block_end = s.find(block_end_marker, block_start)
if block_start < 0 or block_end < 0:
    raise SystemExit('admin image block bounds missing')
new_block = r'''            Center(
              child: Container(
                width: 150,
                height: 210,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E6EA)),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isEmpty
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 46, color: _navy),
                          SizedBox(height: 8),
                          Text('Rasm yo‘q', style: TextStyle(color: Colors.black54)),
                        ],
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 44),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: uploadingImage || gallery.length >= 10
                    ? null
                    : pickAndUploadImages,
                icon: uploadingImage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  uploadingImage
                      ? 'Yuklanmoqda...'
                      : 'Rasmlar tanlash (${gallery.length}/10)',
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (gallery.isNotEmpty)
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: gallery.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Container(
                    width: 78,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: i == 0 ? AppColors.orange : AppColors.border,
                        width: i == 0 ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.network(
                            gallery[i],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                        SizedBox(
                          height: 34,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                tooltip: i == 0 ? 'Muqova rasmi' : 'Muqova qilish',
                                onPressed: i == 0 ? null : () => _makeCover(i),
                                icon: Icon(
                                  i == 0 ? Icons.star_rounded : Icons.star_border_rounded,
                                  size: 18,
                                  color: i == 0 ? AppColors.orange : AppColors.muted,
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                tooltip: 'Olib tashlash',
                                onPressed: () => _removeGalleryImage(i),
                                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 14),
              child: Text(
                '1-rasm — kitob muqovasi. U ilovada ham, Telegram botda ham asosiy rasm bo‘ladi. Qolgan rasmlar kitob ichini ko‘rsatish uchun. Maksimal 10 ta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
'''
s = s[:block_start] + new_block + s[block_end:]
p.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# store_ui.dart: detail page has swipeable gallery + tappable thumbnails.
# ---------------------------------------------------------------------------
p = Path('lib/store_ui.dart')
s = p.read_text(encoding='utf-8')
old_cover = """          final cover = Container(
            width: desktop ? 300 : 235,
            height: desktop ? 420 : 330,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F172A),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _BookCover(book: b),
          );"""
new_cover = """          final cover = _BookGallery(book: b, desktop: desktop);"""
s = rep(s, old_cover, new_cover, 'book detail gallery replacement')
insert_anchor = 'class _BookDetailInfo extends StatelessWidget {'
if insert_anchor not in s:
    raise SystemExit('book detail info anchor missing')
gallery_widget = r'''class _BookGallery extends StatefulWidget {
  const _BookGallery({required this.book, required this.desktop});
  final Book book;
  final bool desktop;

  @override
  State<_BookGallery> createState() => _BookGalleryState();
}

class _BookGalleryState extends State<_BookGallery> {
  late final PageController controller;
  int index = 0;

  @override
  void initState() {
    super.initState();
    controller = PageController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.book.galleryImages;
    final width = widget.desktop ? 300.0 : 235.0;
    final coverHeight = widget.desktop ? 420.0 : 330.0;
    if (images.isEmpty) {
      return SizedBox(
        width: width,
        height: coverHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: _BookCover(book: widget.book),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        children: [
          Container(
            width: width,
            height: coverHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F172A),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (_, i) => Image.network(
                images[i],
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _BookCover(book: widget.book),
              ),
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    width: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: i == index
                            ? UzbekCustomerColors.goldDeep
                            : UzbekCustomerColors.border,
                        width: i == index ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${index + 1}/${images.length}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

'''
s = s.replace(insert_anchor, gallery_widget + insert_anchor, 1)
p.write_text(s, encoding='utf-8')

print('Gallery + same-origin web backend patch applied.')
