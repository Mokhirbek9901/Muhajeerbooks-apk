from pathlib import Path

path = Path('lib/store_ui.dart')
s = path.read_text(encoding='utf-8')

if "import 'book_image_viewer.dart';" not in s:
    s = s.replace("import 'brand.dart';\n", "import 'brand.dart';\nimport 'book_image_viewer.dart';\n", 1)

old = '''              itemBuilder: (_, i) => Image.network(
                images[i],
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _BookCover(book: widget.book),
              ),'''
new = '''              itemBuilder: (_, i) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookImageViewerPage(
                      images: images,
                      initialIndex: i,
                      title: widget.book.title,
                    ),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => _BookCover(book: widget.book),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Icon(
                          Icons.zoom_out_map_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),'''
if old not in s:
    raise SystemExit('gallery image block not found')
s = s.replace(old, new, 1)

hint_old = '''            Text(
              '${index + 1}/${images.length}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),'''
hint_new = '''            Text(
              '${index + 1}/${images.length} • Kattalashtirish uchun rasmni bosing',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),'''
if hint_old in s:
    s = s.replace(hint_old, hint_new, 1)

path.write_text(s, encoding='utf-8')
print('Book image fullscreen viewer connected.')
