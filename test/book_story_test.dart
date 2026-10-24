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
  test('all Story layouts keep only relevant book data, without free postage ads', () {
    const product = Book(
      id: 'sample', title: 'Oq nilufarlar', author: 'Muallif',
      publisher: 'Ichki nashriyot', category: 'Jahon adabiyoti',
      description: 'Kitob haqida ma’lumot', price: 12000, stock: 7,
      discountPercent: 0, imageUrl: '', isActive: true,
    );
    expect(storyPrice(product), '₩12,000');

    final painter = File('lib/book_story_image.dart').readAsStringSync();
    expect(painter.contains('book.publisher'), isFalse,
        reason: 'Story image must not show publisher');
    expect(painter.contains('book.stock'), isFalse,
        reason: 'Story image must not show stock quantities');
    expect(painter.contains('Omborda:'), isFalse);
    expect(painter.contains('storyCategoryHighlight'), isFalse);
    expect(painter.contains('fittedText(book.category'), isFalse);
    expect(painter.contains('textBox(book.category'), isFalse);
    expect(painter.contains('storyShippingHighlight'), isFalse,
        reason: 'No unnecessary marketing highlights in Story images');
    expect(painter.contains('4 ta kitobdan boshlab pochta bepul'), isFalse);
    expect(painter.contains('4+ kitobda'), isFalse);
  });

  test('newly rejected designs disappear from compact real-story chooser', () {
    final picker = File('lib/book_story_page.dart').readAsStringSync();
    final start = picker.indexOf(
        'static const List<BookStoryTemplate> _templateOrder = [');
    final end = picker.indexOf('];', start);
    expect(start, greaterThanOrEqualTo(0));
    final choices = picker.substring(start, end);
    for (final hidden in <BookStoryTemplate>[
      BookStoryTemplate.scrapbook,
      BookStoryTemplate.ornament,
      BookStoryTemplate.nightEdition,
      BookStoryTemplate.warmEdition,
      BookStoryTemplate.obsidianEdition,
    ]) {
      expect(choices.contains('BookStoryTemplate.${hidden.name}'), isFalse,
          reason: '${hidden.name} should not reappear in picker');
    }
    expect(RegExp(r'BookStoryTemplate\.\w+').allMatches(choices).length, 27);
    expect(picker.contains('FutureBuilder<Uint8List>'), isTrue);
    expect(picker.contains('_previewImageFor(item)'), isTrue);
    expect(picker.contains('fit: BoxFit.contain'), isTrue);
    expect(picker.contains('renderScale: 0.25, previewOnly: true'), isTrue);
  });

  test('Sale and Gallery Line book covers are perfectly horizontally centered', () {
    for (final style in [
      BookStoryTemplate.saleEdition,
      BookStoryTemplate.galleryLine,
    ]) {
      final bounds = storyCoverLayoutBounds(style);
      expect(bounds.center.dx, 540, reason: style.name);
      expect(bounds.left, greaterThan(0));
      expect(bounds.right, lessThan(1080));
    }
  });

  test('small actual story preview exports complete 9:16 frames', () async {
    final cover = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer.asUint8List();
    for (final style in [
      BookStoryTemplate.saleEdition,
      BookStoryTemplate.galleryLine,
      BookStoryTemplate.current,
    ]) {
      final png = await renderBookStory(
        book, coverBytes: cover, template: style,
        renderScale: 0.25, previewOnly: true,
      );
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10],
          reason: style.name);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 270, reason: style.name);
      expect(image.height, 480, reason: style.name);
      image.dispose();
      codec.dispose();
    }
  });

  test('rejected Story designs stay hidden, including saved-picker restores', () {
    final picker = File('lib/book_story_page.dart').readAsStringSync();
    final start = picker.indexOf('static const List<BookStoryTemplate> _templateOrder = [');
    final end = picker.indexOf('];', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final choices = picker.substring(start, end);
    for (final name in <String>[
      'coverFocus',
      'lifestyle',
      'royal',
      'marble',
      'cinema',
      'adras',
      'decorative',
      'classic',
      'oldCurrent',
      'atlasLuxeEdition',
      'velvetEdition',
      'sapphireEdition',
      'editorialEdition',
      'mochaStudio',
      'kineticPop',
    ]) {
      expect(choices.contains('BookStoryTemplate.$name'), isFalse,
          reason: '$name should not be selectable in Instagram Story');
    }
    for (final name in <String>[
      'novaEditorial',
      'velvetRose',
      'auroraInk',
      'hanokPaper',
      'serifLuxe',
      'neonNight',
      'galleryLine',
      'goldenOrbit',
    ]) {
      expect(choices.contains('BookStoryTemplate.$name'), isTrue);
    }
    expect(picker.contains('!_templateOrder.contains(restored)'), isTrue,
        reason: 'Previously saved removed templates must not come back');
  });

  test('remaining Story covers have distinctly different compositions', () {
    const designs = <BookStoryTemplate>[
      BookStoryTemplate.novaEditorial,
      BookStoryTemplate.velvetRose,
      BookStoryTemplate.auroraInk,
      BookStoryTemplate.hanokPaper,
      BookStoryTemplate.serifLuxe,
      BookStoryTemplate.neonNight,
      BookStoryTemplate.galleryLine,
      BookStoryTemplate.goldenOrbit,
    ];
    final rectangles = designs.map(storyCoverLayoutBounds).toList();
    expect(rectangles.toSet().length, designs.length,
        reason: 'Surviving signature designs must not reuse one cover position');
    for (final area in rectangles) {
      expect(area.left, greaterThanOrEqualTo(0));
      expect(area.top, greaterThanOrEqualTo(0));
      expect(area.right, lessThanOrEqualTo(1080));
      expect(area.bottom, lessThanOrEqualTo(1100));
    }
    expect(storyCoverLayoutBounds(BookStoryTemplate.obsidianEdition),
        isNot(storyCoverLayoutBounds(BookStoryTemplate.pearlEdition)));
  });

  test('three legacy price-row arrangements still export valid Stories', () async {
    final cover = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer.asUint8List();
    for (final design in <BookStoryTemplate>[
      BookStoryTemplate.botanical,
      BookStoryTemplate.goldArch,
      BookStoryTemplate.arch,
    ]) {
      final imageBytes = await renderBookStory(
          book, coverBytes: cover, template: design, renderScale: 0.5);
      expect(imageBytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10],
          reason: design.name);
      final codec = await ui.instantiateImageCodec(imageBytes);
      final decoded = (await codec.getNextFrame()).image;
      expect(decoded.width, 540);
      expect(decoded.height, 960);
      decoded.dispose();
      codec.dispose();
    }
  });

  test('ten unique signature Story designs have named colour themes and full copy', () {
    const signatures = <BookStoryTemplate>[
      BookStoryTemplate.novaEditorial,
      BookStoryTemplate.velvetRose,
      BookStoryTemplate.auroraInk,
      BookStoryTemplate.hanokPaper,
      BookStoryTemplate.kineticPop,
      BookStoryTemplate.serifLuxe,
      BookStoryTemplate.mochaStudio,
      BookStoryTemplate.neonNight,
      BookStoryTemplate.galleryLine,
      BookStoryTemplate.goldenOrbit,
    ];
    expect(signatures.length, 10);
    expect(signatures.map(bookStoryTemplateName).toSet().length, 10);
    expect(signatures.map(bookStoryTemplateColor).toSet().length, 10);
    for (final design in signatures) {
      expect(bookStorySupportsDescriptionPages(design), isTrue,
          reason: design.name);
    }
  });

  test('ten signature designs export separate PNG artwork in portrait format', () async {
    final cover = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer.asUint8List();
    const signatures = <BookStoryTemplate>[
      BookStoryTemplate.novaEditorial,
      BookStoryTemplate.velvetRose,
      BookStoryTemplate.auroraInk,
      BookStoryTemplate.hanokPaper,
      BookStoryTemplate.kineticPop,
      BookStoryTemplate.serifLuxe,
      BookStoryTemplate.mochaStudio,
      BookStoryTemplate.neonNight,
      BookStoryTemplate.galleryLine,
      BookStoryTemplate.goldenOrbit,
    ];
    final artwork = <int>{};
    for (final design in signatures) {
      final bytes = await renderBookStory(book, coverBytes: cover,
          template: design, renderScale: 0.5);
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10],
          reason: design.name);
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 540, reason: design.name);
      expect(image.height, 960, reason: design.name);
      image.dispose();
      codec.dispose();
      artwork.add(Object.hash(bytes.length, bytes[250], bytes[500]));
    }
    expect(artwork.length, 10, reason: 'Each template needs distinct graphics');
  });

  test('Story design families export without free postage banners', () async {
    final cover = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer.asUint8List();
    for (final template in [
      BookStoryTemplate.current,
      BookStoryTemplate.oldCurrent,
      BookStoryTemplate.smartMatch,
      BookStoryTemplate.quickPrice,
      BookStoryTemplate.obsidianEdition,
      BookStoryTemplate.magazine,
    ]) {
      final png = await renderBookStory(
        book, coverBytes: cover, template: template, renderScale: 0.5,
      );
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10],
          reason: template.name);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 540);
      expect(image.height, 960);
      image.dispose();
      codec.dispose();
    }
  });

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

  test('new story designs expose seven distinctly named templates', () {
    const templates = [
      BookStoryTemplate.quickPrice,
      BookStoryTemplate.cleanEdition,
      BookStoryTemplate.premiumEdition,
      BookStoryTemplate.nightEdition,
      BookStoryTemplate.warmEdition,
      BookStoryTemplate.saleEdition,
      BookStoryTemplate.editorialEdition,
    ];
    expect(templates.map(bookStoryTemplateName).toSet().length, 7);
    for (final template in templates) {
      expect(bookStoryTemplateName(template), isNotEmpty);
    }
  });


  test('five additional premium layouts have unique names and support full copy', () {
    const newTemplates = [
      BookStoryTemplate.obsidianEdition,
      BookStoryTemplate.pearlEdition,
      BookStoryTemplate.sapphireEdition,
      BookStoryTemplate.velvetEdition,
      BookStoryTemplate.atlasLuxeEdition,
    ];
    expect(newTemplates.map(bookStoryTemplateName).toSet().length, 5);
    for (final template in newTemplates) {
      expect(bookStorySupportsDescriptionPages(template), isTrue);
    }
    expect(bookStorySupportsDescriptionPages(BookStoryTemplate.quickPrice), isFalse);
  });

  test('a long description is preserved word for word across story pages', () {
    final longCopy = List<String>.generate(170,
      (index) => 'Kitobning tafsiloti va mazmuni ${index + 1}').join(' ');
    final product = book.copyWith(description: longCopy);
    final segments = bookStoryDescriptionPages(product);
    expect(segments.length, greaterThan(1));
    expect(segments.join(' '), longCopy);
    expect(segments.every((segment) => segment.isNotEmpty), isTrue);
    expect(bookStoryDescriptionPages(book).length, 1);
  });

  test('long story continuation exports a full-size 9:16 PNG', () async {
    final cover = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer.asUint8List();
    final product = book.copyWith(description: List.filled(125,
      'O‘quvchini o‘ylantiradigan mazmunli satrlar').join(' '));
    expect(bookStoryDescriptionPages(product).length, greaterThan(1));
    final png = await renderBookStory(product, coverBytes: cover,
      template: BookStoryTemplate.obsidianEdition, descriptionPage: 1);
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    expect(image.width, 1080);
    expect(image.height, 1920);
    image.dispose();
    codec.dispose();
  });

  test('replenished books move above older arrivals without rewriting creation date', () {
    final original = book.copyWith(createdAt: DateTime.utc(2026, 9, 1));
    final fresh = book.copyWith(createdAt: DateTime.utc(2026, 10, 10));
    final returned = original.copyWith(restockedAt: DateTime.utc(2026, 10, 12));
    final list = [original, fresh, returned]
      ..sort((a, b) => b.catalogArrivalAt.compareTo(a.catalogArrivalAt));
    expect(list.first.catalogArrivalAt, DateTime.utc(2026, 10, 12));
    expect(returned.createdAt, DateTime.utc(2026, 9, 1));
    expect(list[1].catalogArrivalAt, DateTime.utc(2026, 10, 10));
  });

  test('simplified and full-information Story exports retain 9:16 format', () async {
    final cover = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer.asUint8List();
    for (final template in [
      BookStoryTemplate.quickPrice,
      BookStoryTemplate.cleanEdition,
    ]) {
      final png = await renderBookStory(book, coverBytes: cover, template: template);
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1080);
      expect(image.height, 1920);
      image.dispose();
      codec.dispose();
    }
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
