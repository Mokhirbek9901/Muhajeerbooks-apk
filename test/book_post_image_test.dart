import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/book_post_image.dart';
import 'package:muhajeerbooks/book_story_image.dart';

const book = Book(
  id: 'post-preview',
  title: 'EXCLUSIVE TITLE NOT SHOWN OUTSIDE COVER',
  author: 'Sotuvchi',
  publisher: 'Test nashriyoti',
  category: 'Kitoblar',
  description: 'Taqdir, mehr va insoniylik haqidagi chuqur hikoya. '
      'Ushbu kitob qahramonlarning hayotini o‘zgartirgan voqealarni '
      'yangi nuqtayi nazardan ochib beradi.',
  price: 21000,
  stock: 6,
  discountPercent: 0,
  imageUrl: '',
  isActive: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every current Story template has a valid post colour scheme', () {
    for (final template in BookStoryTemplate.values) {
      expect(bookStoryTemplateColor(template).alpha, 255);
    }
  });

  test('feed export creates 1080x1350 artwork from the original cover',
      () async {
    final cover = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer.asUint8List();
    for (final template in [
      BookStoryTemplate.pearlEdition,
      BookStoryTemplate.obsidianEdition,
      BookStoryTemplate.atlasLuxeEdition,
    ]) {
      final png = await renderBookInstagramPost(
        book,
        template: template,
        coverBytes: cover,
      );
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1080);
      expect(image.height, 1350);

      // Full canvas has a real design background (not transparent padding).
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(rgba, isNotNull);
      expect(rgba!.getUint8(3), 255);

      image.dispose();
      codec.dispose();
    }
  });

  test('a long feed description never overflows the image export', () async {
    final cover = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer.asUint8List();
    final png = await renderBookInstagramPost(
      book,
      template: BookStoryTemplate.warmEdition,
      coverBytes: cover,
      description: List.filled(75, 'Mazmunli kitob tavsifi').join(' '),
    );
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    expect(image.width, 1080);
    expect(image.height, 1350);
    image.dispose();
    codec.dispose();
  });
}
