from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


# ---------- AppState: show cached live catalog immediately ----------
path = Path('lib/app_state.dart')
text = path.read_text(encoding='utf-8')
old = """    if (_backend == null) {
      await _initializeLocalCatalog();
    } else {
      unawaited(_registerInstallation());
      await refreshBooks();
      _startLiveBooksSync();
      await _checkRestockNotificationsQuietly();
      await _refreshCustomerOrderStatusesQuietly();
      _orderStatusTimer?.cancel();
      _orderStatusTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshCustomerOrderStatusesQuietly(),
      );
    }
"""
new = """    if (_backend == null) {
      await _initializeLocalCatalog();
    } else {
      // Oldingi live katalog bo‘lsa, internet javobini kutmasdan darhol ko‘rsatamiz.
      // Narx/qoldiq keyin fon rejimida Supabase'dan yangilanadi.
      final cachedBooks = await _local.loadBooks();
      if (cachedBooks.isNotEmpty) {
        _books
          ..clear()
          ..addAll(cachedBooks);
        _sanitizeCart();
        loading = false;
        notifyListeners();
      }

      unawaited(_registerInstallation());
      if (_books.isEmpty) {
        await refreshBooks();
      } else {
        unawaited(_refreshBooksQuietly());
      }
      _startLiveBooksSync();
      unawaited(_checkRestockNotificationsQuietly());
      unawaited(_refreshCustomerOrderStatusesQuietly());
      _orderStatusTimer?.cancel();
      _orderStatusTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshCustomerOrderStatusesQuietly(),
      );
    }
"""
text = replace_once(text, old, new, 'initialize cache-first')
old = """      _books
        ..clear()
        ..addAll(fresh);
      await _local.saveBooks(_books);
      _sanitizeCart();
      notifyListeners();
"""
new = """      _books
        ..clear()
        ..addAll(fresh);
      _sanitizeCart();
      notifyListeners();
      // Diskka yozish UI ni kutib turmasin.
      unawaited(_local.saveBooks(_books));
"""
text = replace_once(text, old, new, 'quiet refresh persistence')
path.write_text(text, encoding='utf-8')


# ---------- Store UI: named internal routes + lighter images ----------
path = Path('lib/store_ui.dart')
text = path.read_text(encoding='utf-8')
if not text.startswith("import 'dart:async';"):
    text = "import 'dart:async';\n\n" + text

anchor = """final _money = NumberFormat('#,###', 'en_US');
String won(int value) => '₩${_money.format(value)}';
"""
helper = """final _money = NumberFormat('#,###', 'en_US');
String won(int value) => '₩${_money.format(value)}';

Future<void> _openBookDetail(BuildContext context, Book book) async {
  if (book.imageUrl.trim().isNotEmpty) {
    unawaited(
      precacheImage(NetworkImage(book.imageUrl), context).catchError((_) {}),
    );
  }
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'mb:book:${book.id}'),
      builder: (_) => BookDetailPage(bookId: book.id),
    ),
  );
}
"""
text = replace_once(text, anchor, helper, 'book detail helper')

# Book taps (featured + regular card)
text = text.replace(
"""                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookDetailPage(bookId: b.id),
                  ),
                ),
""",
"""                onTap: () => _openBookDetail(context, b),
""",
)
text = text.replace(
"""        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailPage(bookId: book.id)),
        ),
""",
"""        onTap: () => _openBookDetail(context, book),
""",
)

# Category/public pages get managed browser-history entries.
text = replace_once(
    text,
"""                  MaterialPageRoute(
                    builder: (_) => isPublishers
                        ? const PublishersPage()
                        : CategoryBrowsePage(category: c),
                  ),
""",
"""                  MaterialPageRoute(
                    settings: RouteSettings(
                      name: isPublishers ? 'mb:publishers' : 'mb:category:$c',
                    ),
                    builder: (_) => isPublishers
                        ? const PublishersPage()
                        : CategoryBrowsePage(category: c),
                  ),
""",
    'category route',
)
text = replace_once(
    text,
"""                      MaterialPageRoute(
                        builder: (_) =>
                            CategoryBrowsePage(category: name, publisher: name),
                      ),
""",
"""                      MaterialPageRoute(
                        settings: RouteSettings(name: 'mb:publisher:$name'),
                        builder: (_) =>
                            CategoryBrowsePage(category: name, publisher: name),
                      ),
""",
    'publisher route',
)
text = replace_once(
    text,
"""                        MaterialPageRoute(
                          builder: (_) => const PublishersPage(),
                        ),
""",
"""                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'mb:publishers'),
                          builder: (_) => const PublishersPage(),
                        ),
""",
    'quick publisher route',
)
text = replace_once(
    text,
"""                    MaterialPageRoute(
                      builder: (_) => const CustomerNotificationsPage(),
                    ),
""",
"""                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'mb:notifications'),
                      builder: (_) => const CustomerNotificationsPage(),
                    ),
""",
    'notification route',
)
text = replace_once(
    text,
"""                  MaterialPageRoute(
                    builder: (_) => BookImageViewerPage(
                      images: images,
                      initialIndex: i,
                      title: widget.book.title,
                    ),
                  ),
""",
"""                  MaterialPageRoute(
                    settings: RouteSettings(
                      name: 'mb:image:${widget.book.id}:$i',
                    ),
                    builder: (_) => BookImageViewerPage(
                      images: images,
                      initialIndex: i,
                      title: widget.book.title,
                    ),
                  ),
""",
    'image viewer route',
)
text = replace_once(
    text,
"""                          MaterialPageRoute(
                            builder: (_) => const CheckoutPage(),
                          ),
""",
"""                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'mb:checkout'),
                            builder: (_) => const CheckoutPage(),
                          ),
""",
    'checkout route',
)
text = replace_once(
    text,
"""                    MaterialPageRoute(builder: (_) => const AdminGatePage()),
""",
"""                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'mb:admin'),
                      builder: (_) => const AdminGatePage(),
                    ),
""",
    'admin route',
)
text = replace_once(
    text,
"""                    MaterialPageRoute(builder: (_) => const MyOrdersPage()),
""",
"""                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'mb:orders'),
                      builder: (_) => const MyOrdersPage(),
                    ),
""",
    'orders route',
)
text = replace_once(
    text,
"""                    MaterialPageRoute(builder: (_) => const FavoritesPage()),
""",
"""                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'mb:favorites'),
                      builder: (_) => const FavoritesPage(),
                    ),
""",
    'favorites route',
)

# Lower decode cost on Android; web safely ignores cacheWidth when unsupported.
text = replace_once(
    text,
"""      return Image.network(
        book.imageUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
""",
"""      return Image.network(
        book.imageUrl,
        fit: BoxFit.cover,
        cacheWidth: 420,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
""",
    'card image size',
)
text = replace_once(
    text,
"""                    Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
""",
"""                    Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      cacheWidth: widget.desktop ? 900 : 700,
                      filterQuality: FilterQuality.medium,
""",
    'detail image size',
)
text = replace_once(
    text,
"""                    child: Image.network(
                      images[i],
                      fit: BoxFit.cover,
""",
"""                    child: Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      cacheWidth: 160,
""",
    'thumbnail size',
)
path.write_text(text, encoding='utf-8')


# ---------- Version bump ----------
path = Path('pubspec.yaml')
text = path.read_text(encoding='utf-8')
text = replace_once(text, 'version: 2.5.3+10', 'version: 2.5.4+11', 'version bump')
path.write_text(text, encoding='utf-8')

print('App speed/navigation patch applied.')
