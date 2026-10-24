import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admin Kitoblar filters use sales-style wrapped outline pills', () {
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
    expect(booksPage.contains('Wrap(\n                    spacing: 7,\n                    runSpacing: 7,'), isTrue);
    expect(booksPage.contains('const BoxConstraints(minHeight: 34)'), isTrue);
    expect(booksPage.contains('BorderRadius.circular(13)'), isTrue);
    expect(booksPage.contains('border: Border.all('), isTrue);
    expect(booksPage.contains('AppColors.border'), isTrue);
    expect(booksPage.contains('height: 36,\n                    child: SingleChildScrollView('), isFalse);
  });

  test('Book filters stay pinned while only catalog entries scroll', () {
    final source = File('lib/admin_ui.dart').readAsStringSync();
    final from = source.indexOf('class _BooksAdminState');
    final to = source.indexOf('class _AdminBookThumb', from);
    final page = source.substring(from, to);

    final topFilters = page.indexOf('// Sticky, wrapped filters:');
    final search = page.indexOf("hintText: 'Kitob yoki muallif...'");
    final bookList = page.indexOf('child: ListView.separated(');
    expect(topFilters, greaterThanOrEqualTo(0));
    expect(search, greaterThan(topFilters));
    expect(bookList, greaterThan(search));
    expect(page.contains('return Column(\n          children: ['), isTrue);
    expect(page.contains('Expanded(\n                child: ListView.separated('), isTrue);

    // All sales-style filter actions continue to use the original states.
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
