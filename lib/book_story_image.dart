import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'app_state.dart';

const storyOrderLabel = 'Buyurtma berish uchun bosing';

enum BookStoryTemplate { current, editorial, library, arch, emerald, minimal, sunset, magazine, classic, poster, noir, geometric, paper, split, polaroid, collage, coverFocus }

String bookStoryTemplateName(BookStoryTemplate value) => switch (value) {
  BookStoryTemplate.current => 'Hozirgi',
  BookStoryTemplate.editorial => 'Yorug‘',
  BookStoryTemplate.library => 'Kutubxona',
  BookStoryTemplate.arch => 'Sharqona',
  BookStoryTemplate.emerald => 'Zumrad',
  BookStoryTemplate.minimal => 'Minimal',
  BookStoryTemplate.sunset => 'Oqshom',
  BookStoryTemplate.magazine => 'Jurnal',
  BookStoryTemplate.classic => 'Klassik',
  BookStoryTemplate.poster => 'Poster',
  BookStoryTemplate.noir => 'Noir',
  BookStoryTemplate.geometric => 'Geometrik',
  BookStoryTemplate.paper => 'Qog‘oz',
  BookStoryTemplate.split => 'Ikki qism',
  BookStoryTemplate.polaroid => 'Polaroid',
  BookStoryTemplate.collage => 'Kollaj',
  BookStoryTemplate.coverFocus => 'Muqova',
};

Color bookStoryTemplateColor(BookStoryTemplate value) => switch (value) {
  BookStoryTemplate.current => const Color(0xFFF8F4E9),
  BookStoryTemplate.editorial => const Color(0xFFF4EFE4),
  BookStoryTemplate.library => const Color(0xFF24150E),
  BookStoryTemplate.arch => const Color(0xFFF5F0E5),
  BookStoryTemplate.emerald => const Color(0xFF073D3B),
  BookStoryTemplate.minimal => const Color(0xFFF7F4EA),
  BookStoryTemplate.sunset => const Color(0xFF9A5A31),
  BookStoryTemplate.magazine => const Color(0xFFEDE8DC),
  BookStoryTemplate.classic => const Color(0xFFF2E7D2),
  BookStoryTemplate.poster => const Color(0xFFE64A3B),
  BookStoryTemplate.noir => const Color(0xFF111111),
  BookStoryTemplate.geometric => const Color(0xFF184D68),
  BookStoryTemplate.paper => const Color(0xFFF0E5CC),
  BookStoryTemplate.split => const Color(0xFFE8D7BD),
  BookStoryTemplate.polaroid => const Color(0xFFCCD8C8),
  BookStoryTemplate.collage => const Color(0xFFF1C64B),
  BookStoryTemplate.coverFocus => const Color(0xFF242424),
};

String storyPrice(Book book) => book.price > 0
    ? '₩${NumberFormat('#,###').format(book.currentPrice)}'
    : 'Narxi aniqlanmoqda';

String _storyDescription(Book book) {
  final value = book.description.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.isEmpty || value == 'Ma’lumot kiritilmagan.') {
    return 'Kitob haqida batafsil ma’lumotni ilovada ko‘ring.';
  }
  return value;
}

Future<ui.Image> _decodeStoryCover(Uint8List encoded) async {
  // Set story generatorida ishlayotgan xavfsiz yo‘l bilan bir xil qilamiz.
  // Katta iPhone rasmlarini 700–900px texture sifatida Canvas'ga berish ayrim
  // Safari/iOS qurilmalarda qora cover qaytarardi. EXIF'ni bake qilib, 360px
  // alpha-siz RGB PNG ga aylantiramiz — story uchun bu yetarli aniqlik.
  final decoded = img.decodeImage(encoded);
  if (decoded == null) throw StateError('Cover decode failed');

  final resized = decoded.width > 360
      ? img.copyResize(
          decoded,
          width: 360,
          interpolation: img.Interpolation.average,
        )
      : decoded;

  final safe = img.Image(
    width: resized.width,
    height: resized.height,
    numChannels: 3,
  );
  img.fill(safe, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(safe, resized);

  final safePng = Uint8List.fromList(img.encodePng(safe, level: 4));
  final codec = await ui.instantiateImageCodec(safePng, targetWidth: 360);
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List?> _downloadStoryCover(Book book) async {
  // Story uchun thumbnail emas, avval original muqovani olamiz.
  // Ayrim iPhone/Safari holatlarida thumbnail canvas eksportida qora
  // to‘rtburchak bo‘lib qolishi mumkin.
  final candidates = <String>[
    book.imageUrl,
    ...book.imageUrls,
    book.previewImageUrl,
  ].map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

  for (final url in candidates) {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {
      // Keyingi rasm manzilini sinab ko‘ramiz.
    }
  }
  return null;
}

class _TextMetrics {
  const _TextMetrics(this.fontSize, this.size);

  final double fontSize;
  final Size size;
}

_TextMetrics _fitText({
  required String value,
  required double maxWidth,
  required double maxHeight,
  required double maxFontSize,
  required double minFontSize,
  required double lineHeight,
  int? maxLines,
  FontWeight weight = FontWeight.w500,
}) {
  final hardFloor = maxLines == null ? 7.0 : minFontSize;
  var fontSize = maxFontSize;

  while (fontSize >= hardFloor) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: weight,
          height: lineHeight,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);

    final fits = painter.height <= maxHeight && !painter.didExceedMaxLines;
    final size = Size(painter.width, painter.height);
    painter.dispose();
    if (fits) return _TextMetrics(fontSize, size);

    fontSize -= fontSize > minFontSize ? 0.5 : 0.25;
  }

  final painter = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: hardFloor,
        fontWeight: weight,
        height: lineHeight,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: maxLines,
  )..layout(maxWidth: maxWidth);
  final size = Size(painter.width, painter.height);
  painter.dispose();
  return _TextMetrics(hardFloor, size);
}

Size _paintText(
  Canvas canvas,
  String value,
  double y,
  _TextMetrics metrics, {
  required double width,
  required Color color,
  FontWeight weight = FontWeight.w500,
  double lineHeight = 1.12,
  int? maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: metrics.fontSize,
        fontWeight: weight,
        color: color,
        height: lineHeight,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: maxLines,
  )..layout(maxWidth: width);
  painter.paint(canvas, Offset((1080 - painter.width) / 2, y));
  final result = Size(painter.width, painter.height);
  painter.dispose();
  return result;
}

/// A full-resolution 9:16 portrait image, independent of preview screen size.
Future<Uint8List> renderBookStory(
  Book book, {
  Uint8List? coverBytes,
  BookStoryTemplate template = BookStoryTemplate.current,
}) async {
  if (template != BookStoryTemplate.current) {
    return _renderAlternativeBookStory(book, template, coverBytes: coverBytes);
  }
  Uint8List? bytes = coverBytes;
  bytes ??= await _downloadStoryCover(book);
  bytes ??= (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
      .buffer
      .asUint8List();

  ui.Image cover;
  try {
    cover = await _decodeStoryCover(bytes);
  } catch (_) {
    final fallback = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer
        .asUint8List();
    cover = await _decodeStoryCover(fallback);
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const ink = Color(0xFF174652);
  const teal = Color(0xFF0D625C);
  const cream = Color(0xFFF8F4E9);
  const green = Color(0xFF187A55);
  const greenSoft = Color(0xFFE4F4EC);
  const red = Color(0xFFB53B3B);
  const redSoft = Color(0xFFFBE8E8);
  const muted = Color(0xFF66787D);
  const deliveryText = Color(0xFF49666E);
  const deliverySoft = Color(0xFFEAF1F0);

  canvas.drawColor(cream, BlendMode.src);
  canvas.drawCircle(
    const Offset(1050, 150),
    380,
    Paint()..color = const Color(0xFFDFEEE7),
  );
  canvas.drawCircle(
    const Offset(30, 1100),
    290,
    Paint()..color = const Color(0xFFF1E5CA),
  );

  void simpleText(
    String value,
    double y,
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w500,
    double width = 900,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: 1.1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, Offset((1080 - painter.width) / 2, y));
    painter.dispose();
  }

  simpleText('MUHAJEER BOOKS', 120, 46, weight: FontWeight.w800);
  simpleText('Koreyadagi o‘zbek kitob do‘koni', 182, 28);

  final frame = RRect.fromRectAndRadius(
    const Rect.fromLTWH(182, 270, 716, 700),
    const Radius.circular(38),
  );
  canvas.drawShadow(
    Path()..addRRect(frame),
    const Color(0x33174652),
    18,
    false,
  );
  canvas.drawRRect(frame, Paint()..color = Colors.white);
  const coverRect = Rect.fromLTWH(214, 300, 652, 640);
  canvas.drawRect(coverRect, Paint()..color = Colors.white);
  paintImage(
    canvas: canvas,
    rect: coverRect,
    image: cover,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );

  final title = _fitText(
    value: book.title,
    maxWidth: 900,
    maxHeight: 112,
    maxFontSize: 52,
    minFontSize: 34,
    lineHeight: 1.06,
    maxLines: 2,
    weight: FontWeight.w800,
  );

  final hasAuthor =
      book.author.trim().isNotEmpty && book.author != 'Ko‘rsatilmagan';
  final author = hasAuthor
      ? _fitText(
          value: book.author.trim(),
          maxWidth: 800,
          maxHeight: 30,
          maxFontSize: 20,
          minFontSize: 15,
          lineHeight: 1.02,
          maxLines: 1,
        )
      : const _TextMetrics(0, Size.zero);

  final price = _fitText(
    value: storyPrice(book),
    maxWidth: 760,
    maxHeight: 78,
    maxFontSize: book.price > 0 ? 70 : 43,
    minFontSize: book.price > 0 ? 48 : 30,
    lineHeight: 1,
    maxLines: 1,
    weight: FontWeight.w900,
  );

  final publisher = book.publisher.trim();
  final hasPublisher = publisher.isNotEmpty && publisher != 'Ko‘rsatilmagan';
  final publisherMetrics = hasPublisher
      ? _fitText(
          value: publisher,
          maxWidth: 850,
          maxHeight: 40,
          maxFontSize: 23,
          minFontSize: 17,
          lineHeight: 1.06,
          maxLines: 1,
        )
      : const _TextMetrics(0, Size.zero);

  const deliveryHeight = 44.0;
  const stockHeight = 58.0;
  const gapTitleAuthor = 13.0;
  const gapAuthorPrice = 3.0;
  const gapPriceDelivery = 6.0;
  const gapDeliveryStock = 10.0;
  const gapStockPublisher = 11.0;
  const gapPublisherDescription = 16.0;
  const gapStockDescription = 18.0;
  const gapDescriptionCta = 22.0;
  const ctaHeight = 46.0;
  const arrowArea = 62.0;

  const minBlockTop = 976.0;
  const maxBlockTop = 1015.0;
  const blockBottom = 1762.0;

  final fixedHeight = title.size.height +
      (hasAuthor ? gapTitleAuthor + author.size.height : 0) +
      gapAuthorPrice +
      price.size.height +
      gapPriceDelivery +
      deliveryHeight +
      gapDeliveryStock +
      stockHeight +
      (hasPublisher
          ? gapStockPublisher + publisherMetrics.size.height + gapPublisherDescription
          : gapStockDescription) +
      gapDescriptionCta +
      ctaHeight +
      arrowArea;

  final descriptionMaxHeight =
      (blockBottom - minBlockTop - fixedHeight).clamp(130.0, 390.0).toDouble();
  final description = _storyDescription(book);
  final descriptionMetrics = _fitText(
    value: description,
    maxWidth: 900,
    maxHeight: descriptionMaxHeight,
    maxFontSize: 27,
    minFontSize: 16,
    lineHeight: 1.18,
    maxLines: null,
  );

  final totalHeight = fixedHeight + descriptionMetrics.size.height;
  var y = (blockBottom - totalHeight).clamp(minBlockTop, maxBlockTop).toDouble();

  final titleSize = _paintText(
    canvas,
    book.title,
    y,
    title,
    width: 900,
    color: ink,
    weight: FontWeight.w800,
    lineHeight: 1.06,
    maxLines: 2,
  );
  y += titleSize.height;

  if (hasAuthor) {
    y += gapTitleAuthor;
    final authorSize = _paintText(
      canvas,
      book.author.trim(),
      y,
      author,
      width: 800,
      color: const Color(0xFF52656B),
      lineHeight: 1.02,
      maxLines: 1,
    );
    y += authorSize.height;
  }

  y += gapAuthorPrice;
  final priceSize = _paintText(
    canvas,
    storyPrice(book),
    y,
    price,
    width: 760,
    color: teal,
    weight: FontWeight.w900,
    lineHeight: 1,
    maxLines: 1,
  );
  y += priceSize.height + gapPriceDelivery;

  // Delivery-fee sticker. The truck is drawn as vector lines so it renders
  // reliably in exported PNGs on Safari/iPhone instead of depending on emoji.
  const deliveryLabel = 'Yetkazib berish: ₩4,000';
  final deliveryPainter = TextPainter(
    text: const TextSpan(
      text: deliveryLabel,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: deliveryText,
        height: 1,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
  )..layout(maxWidth: 700);

  const truckWidth = 27.0;
  const truckGap = 10.0;
  final deliveryContentWidth = truckWidth + truckGap + deliveryPainter.width;
  final deliveryWidth =
      (deliveryContentWidth + 42).clamp(300.0, 620.0).toDouble();
  final deliveryCenterY = y + deliveryHeight / 2;
  final deliveryRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(540, deliveryCenterY),
      width: deliveryWidth,
      height: deliveryHeight,
    ),
    const Radius.circular(22),
  );
  canvas.drawRRect(deliveryRect, Paint()..color = deliverySoft);

  final contentLeft = (1080 - deliveryContentWidth) / 2;
  final truckLeft = contentLeft;
  final truckTop = deliveryCenterY - 10;
  final truckPaint = Paint()
    ..color = deliveryText
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(truckLeft, truckTop + 3, 16, 11),
      const Radius.circular(2),
    ),
    truckPaint,
  );
  canvas.drawPath(
    Path()
      ..moveTo(truckLeft + 16, truckTop + 6)
      ..lineTo(truckLeft + 21, truckTop + 6)
      ..lineTo(truckLeft + 26, truckTop + 11)
      ..lineTo(truckLeft + 26, truckTop + 14)
      ..lineTo(truckLeft + 16, truckTop + 14)
      ..close(),
    truckPaint,
  );
  canvas.drawCircle(Offset(truckLeft + 6, truckTop + 16), 3, truckPaint);
  canvas.drawCircle(Offset(truckLeft + 21, truckTop + 16), 3, truckPaint);

  deliveryPainter.paint(
    canvas,
    Offset(
      contentLeft + truckWidth + truckGap,
      deliveryCenterY - deliveryPainter.height / 2,
    ),
  );
  deliveryPainter.dispose();
  y += deliveryHeight + gapDeliveryStock;

  final stockLabel =
      book.stock > 0 ? 'Omborda: ${book.stock} dona' : 'Hozircha mavjud emas';
  final stockForeground = book.stock > 0 ? green : red;
  final stockBackground = book.stock > 0 ? greenSoft : redSoft;
  final stockPainter = TextPainter(
    text: TextSpan(
      text: stockLabel,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: stockForeground,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
  )..layout(maxWidth: 700);
  final pillWidth = (stockPainter.width + 58).clamp(290.0, 720.0).toDouble();
  final pillCenterY = y + stockHeight / 2;
  final pillRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(540, pillCenterY),
      width: pillWidth,
      height: stockHeight,
    ),
    const Radius.circular(30),
  );
  canvas.drawRRect(pillRect, Paint()..color = stockBackground);
  stockPainter.paint(
    canvas,
    Offset((1080 - stockPainter.width) / 2, pillCenterY - stockPainter.height / 2),
  );
  stockPainter.dispose();
  y += stockHeight;

  if (hasPublisher) {
    y += gapStockPublisher;
    final publisherSize = _paintText(
      canvas,
      publisher,
      y,
      publisherMetrics,
      width: 850,
      color: muted,
      lineHeight: 1.06,
      maxLines: 1,
    );
    y += publisherSize.height + gapPublisherDescription;
  } else {
    y += gapStockDescription;
  }

  final descriptionSize = _paintText(
    canvas,
    description,
    y,
    descriptionMetrics,
    width: 900,
    color: ink,
    lineHeight: 1.18,
    maxLines: null,
  );
  y += descriptionSize.height + gapDescriptionCta;

  final cta = _fitText(
    value: book.inStock ? storyOrderLabel : 'Kitob haqida batafsil',
    maxWidth: 820,
    maxHeight: ctaHeight,
    maxFontSize: 37,
    minFontSize: 27,
    lineHeight: 1,
    maxLines: 1,
    weight: FontWeight.w800,
  );
  final ctaSize = _paintText(
    canvas,
    book.inStock ? storyOrderLabel : 'Kitob haqida batafsil',
    y,
    cta,
    width: 820,
    color: teal,
    weight: FontWeight.w800,
    lineHeight: 1,
    maxLines: 1,
  );
  y += ctaSize.height + 8;

  final arrow = Paint()
    ..color = teal
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(Offset(540, y), Offset(540, y + 38), arrow);
  canvas.drawPath(
    Path()
      ..moveTo(526, y + 24)
      ..lineTo(540, y + 38)
      ..lineTo(554, y + 24),
    arrow,
  );

  simpleText('@muhajeerbooks', 1810, 28);

  final picture = recorder.endRecording();
  final image = await picture.toImage(1080, 1920);
  picture.dispose();
  // Safari/CanvasKit ayrim iPhone'larda toByteData() tugaguncha source texture
  // kerak bo‘ladi. Cover'ni bundan oldin dispose qilish qora to‘rtburchak beradi.
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  cover.dispose();
  if (png == null) throw StateError('Image unavailable');
  return png.buffer.asUint8List();
}


Future<Uint8List> _renderAlternativeBookStory(
  Book book,
  BookStoryTemplate template, {
  Uint8List? coverBytes,
}) async {
  Uint8List? bytes = coverBytes ?? await _downloadStoryCover(book);
  bytes ??= (await rootBundle.load('assets/images/muhajeer_logo.jpg')).buffer.asUint8List();
  ui.Image cover;
  try {
    cover = await _decodeStoryCover(bytes);
  } catch (_) {
    cover = await _decodeStoryCover(
      (await rootBundle.load('assets/images/muhajeer_logo.jpg')).buffer.asUint8List(),
    );
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const navy = Color(0xFF123F49);
  const teal = Color(0xFF08786E);
  const cream = Color(0xFFF7F2E7);
  const muted = Color(0xFF5F6F72);
  final dark = template == BookStoryTemplate.library ||
      template == BookStoryTemplate.emerald ||
      template == BookStoryTemplate.noir ||
      template == BookStoryTemplate.geometric ||
      template == BookStoryTemplate.coverFocus;
  final fg = dark ? Colors.white : navy;

  void textBox(String value, Rect rect, double size, {FontWeight weight = FontWeight.w600,
      Color? color, TextAlign align = TextAlign.center, int maxLines = 2,
      String fontFamily = 'Roboto', FontStyle fontStyle = FontStyle.normal,
      double letterSpacing = 0}) {
    var s = size;
    TextPainter p;
    while (true) {
      p = TextPainter(
        text: TextSpan(text: value, style: TextStyle(fontFamily: fontFamily, fontSize: s,
          fontWeight: weight, fontStyle: fontStyle, letterSpacing: letterSpacing,
          color: color ?? fg, height: 1.08)),
        textDirection: ui.TextDirection.ltr, textAlign: align, maxLines: maxLines, ellipsis: '…',
      )..layout(maxWidth: rect.width);
      if ((!p.didExceedMaxLines && p.height <= rect.height) || s <= 15) break;
      p.dispose(); s -= 1;
    }
    final x = align == TextAlign.left ? rect.left : rect.left + (rect.width - p.width) / 2;
    p.paint(canvas, Offset(x, rect.top + (rect.height - p.height) / 2));
    p.dispose();
  }

  void rounded(Rect rect, Color color, {double radius = 28, Color? stroke}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rr, Paint()..color = color);
    if (stroke != null) canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = stroke);
  }

  switch (template) {
    case BookStoryTemplate.editorial:
      canvas.drawColor(const Color(0xFFF5F0E5), BlendMode.src);
      canvas.drawCircle(const Offset(1000, 250), 310, Paint()..color = const Color(0xFFE1EFE7));
      canvas.drawCircle(const Offset(80, 1530), 260, Paint()..color = const Color(0xFFEBDDBB));
      break;
    case BookStoryTemplate.library:
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0, 0), const Offset(1080, 1920), [const Color(0xFF160E0A), const Color(0xFF5B321D)]));
      break;
    case BookStoryTemplate.arch:
      canvas.drawColor(const Color(0xFFF7F2E7), BlendMode.src);
      final arch = Path()..moveTo(190, 770)..lineTo(190, 420)..quadraticBezierTo(540, 80, 890, 420)..lineTo(890, 770)..close();
      canvas.drawPath(arch, Paint()..color = const Color(0xFFE7E0D0));
      break;
    case BookStoryTemplate.emerald:
      canvas.drawColor(const Color(0xFF063B39), BlendMode.src);
      canvas.drawCircle(const Offset(930, 170), 330, Paint()..color = const Color(0xFF0A514B));
      canvas.drawCircle(const Offset(80, 1600), 300, Paint()..color = const Color(0xFF0B4B47));
      break;
    case BookStoryTemplate.minimal:
      canvas.drawColor(cream, BlendMode.src);
      canvas.drawCircle(const Offset(1040, 120), 350, Paint()..color = const Color(0xFF77B5A4));
      break;
    case BookStoryTemplate.sunset:
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0, 0), const Offset(0, 1920), [const Color(0xFFE9B77D), const Color(0xFF6B351F), const Color(0xFF21130E)]));
      canvas.drawCircle(const Offset(210, 320), 180, Paint()..color = const Color(0x55FFE3A1));
      break;
    case BookStoryTemplate.magazine:
      canvas.drawColor(const Color(0xFFF0ECE2), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 105), Paint()..color = const Color(0xFF132E35));
      canvas.drawRect(const Rect.fromLTWH(72, 205, 12, 1500), Paint()..color = const Color(0xFFD94B3D));
      break;
    case BookStoryTemplate.classic:
      canvas.drawColor(const Color(0xFFF3E8D3), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(42, 42, 996, 1836),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFF8C6A3B));
      canvas.drawRect(const Rect.fromLTWH(58, 58, 964, 1804),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0xFFBDA47B));
      break;
    case BookStoryTemplate.poster:
      canvas.drawColor(const Color(0xFFE94E3D), BlendMode.src);
      canvas.drawCircle(const Offset(915, 260), 250, Paint()..color = const Color(0xFFF4C84A));
      canvas.drawRect(const Rect.fromLTWH(0, 1570, 1080, 350), Paint()..color = const Color(0xFF153F48));
      break;
    case BookStoryTemplate.noir:
      canvas.drawColor(const Color(0xFF101010), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.radial(
        const Offset(540, 780), 950, [const Color(0xFF353535), const Color(0xFF080808)]));
      canvas.drawRect(const Rect.fromLTWH(80, 180, 920, 4), Paint()..color = const Color(0xFFD6B56B));
      break;
    case BookStoryTemplate.geometric:
      canvas.drawColor(const Color(0xFF153F58), BlendMode.src);
      canvas.drawPath(Path()..moveTo(0, 0)..lineTo(520, 0)..lineTo(0, 650)..close(),
        Paint()..color = const Color(0xFFEEB64C));
      canvas.drawPath(Path()..moveTo(1080, 1920)..lineTo(560, 1920)..lineTo(1080, 1260)..close(),
        Paint()..color = const Color(0xFF0B293A));
      break;
    case BookStoryTemplate.paper:
      canvas.drawColor(const Color(0xFFF1E5CC), BlendMode.src);
      for (var yy = 130.0; yy < 1820; yy += 58) {
        canvas.drawLine(Offset(70, yy), Offset(1010, yy), Paint()..color = const Color(0x18A47F50)..strokeWidth = 1);
      }
      canvas.drawLine(const Offset(150, 110), const Offset(150, 1810),
        Paint()..color = const Color(0x44C56B5B)..strokeWidth = 2);
      break;
    case BookStoryTemplate.split:
      canvas.drawColor(const Color(0xFFF6F0E5), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 470, 1920), Paint()..color = const Color(0xFF173F49));
      canvas.drawRect(const Rect.fromLTWH(470, 0, 18, 1920), Paint()..color = const Color(0xFFD4A74E));
      break;
    case BookStoryTemplate.polaroid:
      canvas.drawColor(const Color(0xFFDCE5D7), BlendMode.src);
      canvas.drawCircle(const Offset(100, 280), 210, Paint()..color = const Color(0x55F2C66D));
      canvas.drawCircle(const Offset(970, 1540), 260, Paint()..color = const Color(0x4484A98C));
      canvas.drawRect(const Rect.fromLTWH(0, 1710, 1080, 210), Paint()..color = const Color(0xFFF3E8D5));
      break;
    case BookStoryTemplate.collage:
      canvas.drawColor(const Color(0xFFF4C94F), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 190), Paint()..color = const Color(0xFFED5A43));
      canvas.drawPath(Path()..moveTo(0, 1280)..lineTo(1080, 1080)..lineTo(1080, 1920)..lineTo(0, 1920)..close(),
        Paint()..color = const Color(0xFF174652));
      canvas.drawCircle(const Offset(930, 330), 120, Paint()..color = const Color(0xFFF8EFE0));
      break;
    case BookStoryTemplate.coverFocus:
      canvas.drawColor(const Color(0xFF171717), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0, 0), const Offset(1080, 1920), [const Color(0xFF111111), const Color(0xFF34302B)]));
      canvas.drawRect(const Rect.fromLTWH(55, 70, 8, 1780), Paint()..color = const Color(0xFFCDAA63));
      break;
    case BookStoryTemplate.current:
      canvas.drawColor(cream, BlendMode.src);
      break;
  }

  final serif = template == BookStoryTemplate.classic ||
      template == BookStoryTemplate.paper ||
      template == BookStoryTemplate.polaroid;
  final mono = template == BookStoryTemplate.poster ||
      template == BookStoryTemplate.geometric ||
      template == BookStoryTemplate.collage;
  final displayFont = serif ? 'serif' : (mono ? 'monospace' : 'Roboto');
  final headerColor = template == BookStoryTemplate.poster ? const Color(0xFF153F48) : fg;
  if (template == BookStoryTemplate.split) {
    textBox('MUHAJEER', const Rect.fromLTWH(45, 72, 380, 55), 29,
        weight: FontWeight.w900, color: Colors.white, maxLines: 1, letterSpacing: 4);
    textBox('BOOKS', const Rect.fromLTWH(45, 120, 380, 55), 29,
        weight: FontWeight.w300, color: const Color(0xFFD8B56C), maxLines: 1, letterSpacing: 8);
  } else if (template == BookStoryTemplate.coverFocus) {
    textBox('MUHAJEER BOOKS  /  KITOB TAVSIYASI', const Rect.fromLTWH(95, 70, 890, 55), 24,
        weight: FontWeight.w600, color: const Color(0xFFD8BE86), maxLines: 1, letterSpacing: 2);
  } else {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 70, 920, 70), 40,
        weight: template == BookStoryTemplate.classic ? FontWeight.w500 : FontWeight.w900,
        color: headerColor, maxLines: 1, fontFamily: displayFont,
        letterSpacing: template == BookStoryTemplate.magazine ? 7 : (serif ? 3 : 0));
    textBox('Koreyadagi o‘zbek kitob do‘koni', const Rect.fromLTWH(80, 132, 920, 44), 23,
        color: dark ? const Color(0xFFE8E0D7) : navy, maxLines: 1,
        fontFamily: displayFont,
        fontStyle: serif ? FontStyle.italic : FontStyle.normal);
  }

  Rect coverFrame;
  Rect coverRect;
  if (template == BookStoryTemplate.library) {
    textBox(book.title, const Rect.fromLTWH(120, 205, 840, 160), 58, weight: FontWeight.w900, color: Colors.white);
    coverFrame = const Rect.fromLTWH(315, 390, 450, 650);
    coverRect = const Rect.fromLTWH(340, 415, 400, 600);
  } else if (template == BookStoryTemplate.arch) {
    textBox('“Qalbingiz xotirjam bo‘lsin.”', const Rect.fromLTWH(130, 190, 820, 75), 31,
      color: navy, maxLines: 1);
    coverFrame = const Rect.fromLTWH(285, 360, 510, 690);
    coverRect = const Rect.fromLTWH(315, 390, 450, 630);
  } else if (template == BookStoryTemplate.emerald) {
    coverFrame = const Rect.fromLTWH(175, 250, 730, 860);
    coverRect = const Rect.fromLTWH(210, 285, 660, 790);
  } else if (template == BookStoryTemplate.minimal) {
    textBox(book.title, const Rect.fromLTWH(90, 230, 500, 145), 54, weight: FontWeight.w900, align: TextAlign.left);
    if (book.author.trim().isNotEmpty) textBox(book.author, const Rect.fromLTWH(90, 365, 500, 48), 25, align: TextAlign.left);
    coverFrame = const Rect.fromLTWH(545, 235, 430, 690);
    coverRect = const Rect.fromLTWH(570, 260, 380, 640);
  } else if (template == BookStoryTemplate.sunset) {
    textBox(book.title, const Rect.fromLTWH(120, 190, 840, 150), 58, weight: FontWeight.w900, color: const Color(0xFF24150E));
    coverFrame = const Rect.fromLTWH(290, 360, 500, 760);
    coverRect = const Rect.fromLTWH(320, 390, 440, 700);
  } else if (template == BookStoryTemplate.magazine) {
    textBox('YANGI KITOB', const Rect.fromLTWH(115, 190, 300, 48), 22, weight: FontWeight.w900,
      color: const Color(0xFFD94B3D), align: TextAlign.left, maxLines: 1, letterSpacing: 3);
    textBox(book.title.toUpperCase(), const Rect.fromLTWH(115, 235, 850, 155), 57, weight: FontWeight.w900,
      align: TextAlign.left, maxLines: 2, letterSpacing: 1.2);
    coverFrame = const Rect.fromLTWH(330, 410, 600, 650);
    coverRect = const Rect.fromLTWH(360, 440, 540, 590);
  } else if (template == BookStoryTemplate.classic) {
    textBox(book.title, const Rect.fromLTWH(120, 205, 840, 145), 54, weight: FontWeight.w600,
      fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(300, 375, 480, 680);
    coverRect = const Rect.fromLTWH(328, 403, 424, 624);
  } else if (template == BookStoryTemplate.poster) {
    textBox(book.title.toUpperCase(), const Rect.fromLTWH(90, 190, 900, 150), 64, weight: FontWeight.w900,
      color: const Color(0xFF153F48), fontFamily: 'monospace', letterSpacing: -1);
    coverFrame = const Rect.fromLTWH(215, 375, 650, 700);
    coverRect = const Rect.fromLTWH(245, 405, 590, 640);
  } else if (template == BookStoryTemplate.noir) {
    textBox(book.title, const Rect.fromLTWH(120, 205, 840, 140), 56, weight: FontWeight.w300,
      color: const Color(0xFFF2E6CF), letterSpacing: 2.5);
    coverFrame = const Rect.fromLTWH(300, 385, 480, 690);
    coverRect = const Rect.fromLTWH(325, 410, 430, 640);
  } else if (template == BookStoryTemplate.geometric) {
    textBox(book.title.toUpperCase(), const Rect.fromLTWH(120, 205, 840, 145), 55, weight: FontWeight.w900,
      color: Colors.white, fontFamily: 'monospace', letterSpacing: 2);
    coverFrame = const Rect.fromLTWH(240, 390, 600, 670);
    coverRect = const Rect.fromLTWH(270, 420, 540, 610);
  } else if (template == BookStoryTemplate.paper) {
    textBox(book.title, const Rect.fromLTWH(180, 205, 760, 145), 52, weight: FontWeight.w600,
      color: const Color(0xFF5C432A), fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(315, 385, 480, 675);
    coverRect = const Rect.fromLTWH(345, 415, 420, 615);
  } else if (template == BookStoryTemplate.split) {
    textBox(book.title, const Rect.fromLTWH(525, 245, 470, 260), 58, weight: FontWeight.w900,
      color: navy, align: TextAlign.left, maxLines: 3);
    if (book.author.trim().isNotEmpty) {
      textBox(book.author, const Rect.fromLTWH(525, 515, 450, 65), 24,
        color: const Color(0xFF6B6A64), align: TextAlign.left, maxLines: 1, fontStyle: FontStyle.italic);
    }
    textBox(storyPrice(book), const Rect.fromLTWH(525, 610, 420, 90), 52,
      weight: FontWeight.w900, color: teal, align: TextAlign.left, maxLines: 1);
    coverFrame = const Rect.fromLTWH(75, 285, 350, 720);
    coverRect = const Rect.fromLTWH(95, 305, 310, 680);
  } else if (template == BookStoryTemplate.polaroid) {
    textBox('BUGUNGI TANLOV', const Rect.fromLTWH(160, 190, 760, 55), 25,
      weight: FontWeight.w900, color: const Color(0xFF49664F), letterSpacing: 5, maxLines: 1);
    textBox(book.title, const Rect.fromLTWH(130, 1010, 820, 145), 55, weight: FontWeight.w600,
      color: const Color(0xFF304B38), fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(255, 300, 570, 700);
    coverRect = const Rect.fromLTWH(290, 335, 500, 590);
  } else if (template == BookStoryTemplate.collage) {
    textBox('O‘QISHGA ARZIYDI!', const Rect.fromLTWH(80, 60, 920, 90), 50,
      weight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace', letterSpacing: -1);
    textBox(book.title.toUpperCase(), const Rect.fromLTWH(520, 290, 500, 260), 54,
      weight: FontWeight.w900, color: navy, align: TextAlign.left, maxLines: 3,
      fontFamily: 'monospace', letterSpacing: -1);
    textBox(storyPrice(book), const Rect.fromLTWH(555, 590, 390, 90), 48,
      weight: FontWeight.w900, color: const Color(0xFFED5A43), align: TextAlign.left, maxLines: 1,
      fontFamily: 'monospace');
    coverFrame = const Rect.fromLTWH(85, 285, 390, 720);
    coverRect = const Rect.fromLTWH(110, 310, 340, 670);
  } else if (template == BookStoryTemplate.coverFocus) {
    coverFrame = const Rect.fromLTWH(190, 170, 700, 930);
    coverRect = const Rect.fromLTWH(220, 200, 640, 870);
    textBox(book.title, const Rect.fromLTWH(110, 1115, 860, 145), 58,
      weight: FontWeight.w300, color: const Color(0xFFF4EBDD), letterSpacing: 1.5);
    textBox(storyPrice(book), const Rect.fromLTWH(160, 1265, 760, 85), 49,
      weight: FontWeight.w800, color: const Color(0xFFD6B56B), maxLines: 1);
  } else {
    coverFrame = const Rect.fromLTWH(205, 260, 670, 760);
    coverRect = const Rect.fromLTWH(235, 290, 610, 700);
  }

  if (template == BookStoryTemplate.polaroid) {
    canvas.save();
    final center = coverFrame.center;
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.065);
    canvas.translate(-center.dx, -center.dy);
    rounded(coverFrame, Colors.white, radius: 8, stroke: const Color(0x22000000));
    paintImage(canvas: canvas, rect: coverRect, image: cover, fit: BoxFit.contain, filterQuality: FilterQuality.high);
    canvas.restore();
  } else {
    rounded(coverFrame, dark ? const Color(0xFFF2E8DA) : Colors.white,
        radius: template == BookStoryTemplate.collage ? 6 : 32,
        stroke: dark ? const Color(0x33FFFFFF) : const Color(0xFFE8E0D2));
    paintImage(canvas: canvas, rect: coverRect, image: cover, fit: BoxFit.contain, filterQuality: FilterQuality.high);
  }

  var infoTop = template == BookStoryTemplate.coverFocus
      ? 1370.0
      : (template == BookStoryTemplate.emerald ? 1140.0 : 1080.0);
  final titleAlreadyShown = template == BookStoryTemplate.library ||
      template == BookStoryTemplate.minimal ||
      template == BookStoryTemplate.sunset ||
      template == BookStoryTemplate.magazine ||
      template == BookStoryTemplate.classic ||
      template == BookStoryTemplate.poster ||
      template == BookStoryTemplate.noir ||
      template == BookStoryTemplate.geometric ||
      template == BookStoryTemplate.paper ||
      template == BookStoryTemplate.split ||
      template == BookStoryTemplate.polaroid ||
      template == BookStoryTemplate.collage ||
      template == BookStoryTemplate.coverFocus;
  if (!titleAlreadyShown) {
    textBox(book.title, Rect.fromLTWH(90, infoTop, 900, 90), 45, weight: FontWeight.w900, color: fg);
    infoTop += 84;
  }
  if (book.author.trim().isNotEmpty &&
      book.author != 'Ko‘rsatilmagan' &&
      template != BookStoryTemplate.minimal &&
      template != BookStoryTemplate.split) {
    textBox(book.author.trim(), Rect.fromLTWH(120, infoTop, 840, 42), 22, color: dark ? const Color(0xFFE5DED4) : muted, maxLines: 1);
    infoTop += 45;
  }

  final cardBg = dark ? const Color(0x22FFFFFF) : Colors.white;
  final cardStroke = dark ? const Color(0x55FFFFFF) : const Color(0xFFE3DDD0);
  const gap = 18.0;
  const cardW = 275.0;
  final left = (1080 - (cardW * 3 + gap * 2)) / 2;
  for (var i = 0; i < 3; i++) {
    rounded(Rect.fromLTWH(left + i * (cardW + gap), infoTop + 18, cardW, 112), cardBg, radius: 22, stroke: cardStroke);
  }
  textBox(storyPrice(book), Rect.fromLTWH(left + 10, infoTop + 32, cardW - 20, 80), 31, weight: FontWeight.w900, color: dark ? Colors.white : teal, maxLines: 1);
  textBox('Yetkazib berish:\n₩4,000', Rect.fromLTWH(left + cardW + gap + 10, infoTop + 28, cardW - 20, 88), 22, weight: FontWeight.w800, color: fg);
  textBox(book.stock > 0 ? 'Omborda:\n${book.stock} dona' : 'Hozircha\nmavjud emas',
      Rect.fromLTWH(left + (cardW + gap) * 2 + 10, infoTop + 28, cardW - 20, 88), 22, weight: FontWeight.w800,
      color: book.stock > 0 ? (dark ? const Color(0xFFB8F0D1) : const Color(0xFF187A55)) : const Color(0xFFB53B3B));

  final description = _storyDescription(book);
  textBox(description, Rect.fromLTWH(100, infoTop + 155, 880, 190), 23,
      color: dark ? const Color(0xFFF1ECE5) : navy, maxLines: 5);

  final buttonY = infoTop + 365;
  rounded(Rect.fromLTWH(170, buttonY, 740, 76), dark ? const Color(0xFFF1E4CC) : teal, radius: 38);
  textBox(book.inStock ? 'Buyurtma berish uchun bosing  →' : 'Kitob haqida batafsil  →',
      Rect.fromLTWH(195, buttonY + 8, 690, 60), 27, weight: FontWeight.w900,
      color: dark ? const Color(0xFF2C1A10) : Colors.white, maxLines: 1);
  textBox('@muhajeerbooks', const Rect.fromLTWH(100, 1810, 880, 44), 24,
      color: dark ? const Color(0xFFE7DDD1) : muted, maxLines: 1);

  final picture = recorder.endRecording();
  final image = await picture.toImage(1080, 1920);
  picture.dispose();
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  cover.dispose();
  if (png == null) throw StateError('Image unavailable');
  return png.buffer.asUint8List();
}
