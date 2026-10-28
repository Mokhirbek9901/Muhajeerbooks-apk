import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/catalog_book_gallery.dart';
import 'package:muhajeerbooks/book_image_optimizer.dart';

Book galleryBook(int count) => Book.fromMap({
  'id': 'gallery-book', 'title': 'Gallery test',
  'image_url': 'https://example.test/0.jpg',
  'image_urls': List.generate(count, (i) => 'https://example.test/$i.jpg'),
});
void main() {
  test('model and saved data retain all 125 images and deduplicate cover', () {
    final book = galleryBook(125);
    expect(book.galleryImages.length, 125);
    expect(book.galleryImages.first, 'https://example.test/0.jpg');
    expect(book.galleryImages.last, 'https://example.test/124.jpg');
    expect(Book.fromMap(book.toLocalMap()).galleryImages.length, 125);
  });
  testWidgets('compact catalog gallery swipes through every uploaded photo', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      width: 220, height: 280,
      child: CatalogBookGallery(book: galleryBook(45), fallback: const ColoredBox(color: Colors.grey)),
    ))));
    expect(find.text('1/45'), findsOneWidget);
    await tester.tap(find.byTooltip('Keyingi rasm'));
    await tester.pumpAndSettle();
    expect(find.text('2/45'), findsOneWidget);
    final page = tester.widget<PageView>(find.byKey(const ValueKey('catalog-book-photos')));
    page.controller!.jumpToPage(44);
    await tester.pumpAndSettle();
    expect(find.text('45/45'), findsOneWidget);
    expect(tester.getSize(find.byType(CatalogBookGallery)).height, 280);
    expect(tester.takeException(), isNull);
  });
  test('photos are bounded JPEGs, including high-detail source; source is not stored', () {
    final source = img.Image(width: 1400, height: 1900);
    final random = Random(42);
    for (final pixel in source) {
      pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
    }
    final input = Uint8List.fromList(img.encodeJpg(source, quality: 94));
    final prepared = prepareBookImageVariants(input)!;
    expect(prepared.keys.toSet(), {'full', 'thumb'});
    expect(prepared['full']!.length, lessThanOrEqualTo(bookPhotoMaxBytes));
    expect(prepared['thumb']!.length, lessThanOrEqualTo(bookThumbnailMaxBytes));
    final photo = img.decodeJpg(prepared['full']!)!;
    expect(photo.width, lessThanOrEqualTo(1200));
    expect(photo.height, lessThanOrEqualTo(1800));
    expect(prepared['full']!.length + prepared['thumb']!.length, lessThan(input.length));
  });
  test('undecodable files are rejected instead of uploading a large original', () {
    expect(prepareBookImageVariants(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
