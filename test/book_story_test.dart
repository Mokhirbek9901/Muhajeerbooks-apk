import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/book_story_image.dart';

const book = Book(
  id: 'd6c1745a-4d94-4c19-8fa0-1c0852e37d97',
  title: 'Allohning go‘zal ismlari bor', author: 'Ko‘rsatilmagan',
  category: 'Boshqalar', description: '', price: 25000, stock: 3,
  discountPercent: 0, imageUrl: '', isActive: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('story price uses the sale price and handles an unknown price', () {
    expect(storyPrice(book), '₩25,000');
    expect(storyPrice(book.copyWith(discountPercent: 20)), '₩20,000');
    expect(storyPrice(book.copyWith(price: 0)), 'Narxi aniqlanmoqda');
  });

  test('Story frames follow the cover aspect ratio without cropping', () {
    const portraitArea = ui.Rect.fromLTWH(140, 180, 800, 730);
    final portrait = fittedStoryCoverRect(
      portraitArea,
      const ui.Size(600, 900),
    );
    expect(portrait.center, portraitArea.center);
    expect(portrait.height, closeTo(730, 0.01));
    expect(portrait.width, closeTo(730 * 2 / 3, 0.01));
    expect(portrait.left >= portraitArea.left, isTrue);
    expect(portrait.right <= portraitArea.right, isTrue);

    const wideArea = ui.Rect.fromLTWH(100, 200, 700, 620);
    final wide = fittedStoryCoverRect(wideArea, const ui.Size(1200, 600));
    expect(wide.width, closeTo(700, 0.01));
    expect(wide.height, closeTo(350, 0.01));
    expect(wide.center, wideArea.center);

    // An invalid cover never crashes export layout.
    expect(
      fittedStoryCoverRect(portraitArea, const ui.Size(0, 0)),
      portraitArea,
    );
  });

  test('story exports a full portrait PNG with the supplied cover', () async {
    final fontRoot = Platform.environment['FLUTTER_ROOT'];
    if (fontRoot != null) {
      final font = File('$fontRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
      if (await font.exists()) {
        final loader = FontLoader('Roboto')..addFont(font.readAsBytes().then((b) => ByteData.sublistView(b)));
        await loader.load();
      }
    }
    final cover = (await rootBundle.load('assets/images/muhajeer_logo.jpg')).buffer.asUint8List();
    final png = await renderBookStory(book, coverBytes: cover);
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    expect(image.width, 1080);
    expect(image.height, 1920);
    image.dispose();
    codec.dispose();
    final dir = Directory('build/test-artifacts')..createSync(recursive: true);
    await File('${dir.path}/book-story.png').writeAsBytes(png);
    final long = await renderBookStory(book.copyWith(
      title: 'Juda uzun nomli kitob: inson hayoti, baxt va oilaning qadriga yetish haqida hikoyalar to‘plami',
      author: 'Uzun ismli muallif va uning hammuallifi',
      publisher: 'Nashriyot nomi', discountPercent: 20,
    ), coverBytes: cover);
    await File('${dir.path}/book-story-long-title.png').writeAsBytes(long);
  });
}
