part of 'store_ui.dart';

// Book suggestions use only real catalog metadata; never create a new
// recommendation from a missing author or the unspecific "Boshqalar" genre.
String _relatedKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r"[‘’ʻʼ\u02BB\u02BC\u2018\u2019\x60´]"), "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _knownAuthor(Book book) {
  final value = _relatedKey(book.author);
  return value.isNotEmpty &&
      value != "ko'rsatilmagan" &&
      value != "noma'lum" &&
      value != "nomalum" &&
      value != '-';
}

bool _specificCategory(Book book) {
  final value = _relatedKey(book.category);
  return value.isNotEmpty &&
      value != 'boshqalar' &&
      value != 'barchasi' &&
      value != '-';
}

int _relatedSort(Book a, Book b) {
  final saleA = a.inStock || a.preorderEnabled;
  final saleB = b.inStock || b.preorderEnabled;
  if (saleA != saleB) return saleA ? -1 : 1;
  final stock = b.stock.compareTo(a.stock);
  if (stock != 0) return stock;
  final date = b.catalogArrivalAt.compareTo(a.catalogArrivalAt);
  return date != 0 ? date : a.title.compareTo(b.title);
}

List<Book> _sameAuthorBooks(Book book, List<Book> all) {
  if (!_knownAuthor(book)) return const [];
  final author = _relatedKey(book.author);
  final result = all
      .where((item) => item.id != book.id &&
          item.isActive &&
          _relatedKey(item.author) == author)
      .toList()
    ..sort(_relatedSort);
  return result.take(12).toList();
}

List<Book> _similarGenreBooks(Book book, List<Book> all) {
  if (!_specificCategory(book)) return const [];
  final category = _relatedKey(book.category);
  final author = _relatedKey(book.author);
  final result = all
      .where((item) => item.id != book.id &&
          item.isActive &&
          _relatedKey(item.category) == category &&
          (!_knownAuthor(book) || _relatedKey(item.author) != author))
      .toList()
    ..sort(_relatedSort);
  return result.take(12).toList();
}

class _BookRelatedSections extends StatelessWidget {
  const _BookRelatedSections({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<AppState>().books;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RelatedBookStrip(
          title: 'Muallifning boshqa kitoblari',
          subtitle: _knownAuthor(book)
              ? book.author.trim()
              : 'Muallif ko‘rsatilmagan',
          icon: Icons.person_outline_rounded,
          books: _sameAuthorBooks(book, catalog),
          emptyText: _knownAuthor(book)
              ? 'Hozircha bu muallifning boshqa kitoblari katalogda yo‘q.'
              : 'Bu kitobning muallifi ko‘rsatilmagan.',
        ),
        const SizedBox(height: 26),
        _RelatedBookStrip(
          title: 'O‘xshash kitoblar',
          subtitle: _specificCategory(book)
              ? '${book.category.trim()} yo‘nalishidagi asarlar'
              : 'Mavzu bo‘yicha boshqa kitoblar',
          icon: Icons.auto_awesome_outlined,
          books: _similarGenreBooks(book, catalog),
          emptyText: 'Hozircha shu yo‘nalishda boshqa kitob topilmadi.',
        ),
      ],
    );
  }
}

class _RelatedBookStrip extends StatelessWidget {
  const _RelatedBookStrip({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.books,
    required this.emptyText,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Book> books;
  final String emptyText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppSectionHeader(title: title, subtitle: subtitle, icon: icon),
      const SizedBox(height: 12),
      if (books.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            emptyText,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        )
      else
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = books[index];
              return SizedBox(
                width: 140,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openBookDetail(context, item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: _BookCover(book: item),
                            ),
                            if (!item.inStock && !item.preorderEnabled)
                              Positioned(
                                bottom: 6,
                                left: 6,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.navy,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      'Tugagan',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.preorderEnabled
                            ? 'Oldindan sotuvda'
                            : won(item.currentPrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
    ],
  );
}
