import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admin Kitoblar filters retain sales-style wrapped outline pills', () {
    final source = File('lib/admin_ui.dart').readAsStringSync();
    final from = source.indexOf('class _BooksAdminState');
    final to = source.indexOf('class _AdminBookThumb', from);
    expect(from, greaterThanOrEqualTo(0));
    expect(to, greaterThan(from));
    final booksPage = source.substring(from, to);

    // All original filters and counters remain available, now in rows.
    for (final label in <String>[
      'Kitob ', 'Ombor ', 'Rasm yuklanmagan ', 'Tarifsiz ',
      'Sahifasi ko‘rsatilmagan ', 'Tan narxi kiritilmagan ',
      'Sotuvda ko‘rsatilgan ', 'Sotuvda ko‘rsatilmagan ',
      'Rejadagi kitoblar ', 'Sotilmagan kitoblar ', 'Muammoli ',
    ]) {
      expect(booksPage.contains("label: '$label"), isTrue, reason: label);
    }
    expect(RegExp(r'_booksFilterChip\(').allMatches(booksPage).length, 12);
    expect(booksPage.contains('Wrap(\n                      spacing: 7,\n                      runSpacing: 7,'), isTrue);
    expect(booksPage.contains('const BoxConstraints(minHeight: 34)'), isTrue);
    expect(booksPage.contains('BorderRadius.circular(13)'), isTrue);
    expect(booksPage.contains('border: Border.all('), isTrue);
    expect(booksPage.contains('AppColors.border'), isTrue);
    expect(booksPage.contains('height: 36,\n                    child: SingleChildScrollView('), isFalse);
  });

  test('Book filters and catalog scroll together, matching Sotilgan kitoblar', () {
    final source = File('lib/admin_ui.dart').readAsStringSync();
    final from = source.indexOf('class _BooksAdminState');
    final to = source.indexOf('class _AdminBookThumb', from);
    final page = source.substring(from, to);

    final viewport = page.indexOf('return CustomScrollView(');
    final header = page.indexOf('SliverToBoxAdapter(', viewport);
    final filters = page.indexOf('Same sales-style wrapped pills.');
    final search = page.indexOf("hintText: 'Kitob yoki muallif...'");
    final list = page.indexOf('SliverList(', viewport);
    expect(viewport, greaterThanOrEqualTo(0));
    expect(header, greaterThan(viewport));
    expect(filters, greaterThan(header));
    expect(search, greaterThan(filters));
    expect(list, greaterThan(search));
    expect(page.contains('SliverPadding('), isTrue);
    expect(page.contains('SliverChildBuilderDelegate('), isTrue);
    expect(page.contains('childCount: books.length * 2 - 1'), isTrue);
    expect(page.contains('const SizedBox(height: 8)'), isTrue);
    expect(page.contains('SliverFillRemaining('), isTrue);
    expect(page.contains('Expanded(\\n                child: ListView.separated('), isFalse);
    expect(page.contains('SliverPersistentHeader('), isFalse);
    expect(page.contains('SliverAppBar('), isFalse);
    expect(page.contains('pinned: true'), isFalse);

    // All original filter states and actions still work.
    for (final filter in <String>[
      'all', 'missing_image', 'missing_description',
      'missing_page_count', 'missing_cost', 'active', 'hidden',
      'planned', 'unsold',
    ]) {
      expect(page.contains("filter = '$filter'"), isTrue, reason: filter);
    }
    expect(page.contains('_openProblemFilters(all)'), isTrue);
  });
}
