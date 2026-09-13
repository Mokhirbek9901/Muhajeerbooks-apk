import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'app_state.dart';

const storyOrderLabel = 'Buyurtma berish uchun bosing';

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
  final decoded = img.decodeImage(encoded);
  if (decoded == null) throw StateError('Cover decode failed');

  final resized = decoded.width > 700
      ? img.copyResize(
          decoded,
          width: 700,
          interpolation: img.Interpolation.average,
        )
      : decoded;
  final rgba = Uint8List.fromList(
    resized.getBytes(order: img.ChannelOrder.rgba),
  );

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    resized.width,
    resized.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
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
Future<Uint8List> renderBookStory(Book book, {Uint8List? coverBytes}) async {
  Uint8List bytes;
  if (coverBytes != null) {
    bytes = coverBytes;
  } else if (book.galleryImages.isNotEmpty) {
    final response = await http
        .get(Uri.parse(book.galleryImages.first))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('Cover unavailable');
    bytes = response.bodyBytes;
  } else {
    bytes = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer
        .asUint8List();
  }

  final cover = await _decodeStoryCover(bytes);

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
  paintImage(
    canvas: canvas,
    rect: const Rect.fromLTWH(214, 300, 652, 640),
    image: cover,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
  cover.dispose();

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
          maxHeight: 34,
          maxFontSize: 24,
          minFontSize: 18,
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

  const stockHeight = 58.0;
  const gapTitleAuthor = 13.0;
  const gapAuthorPrice = 3.0;
  const gapPriceStock = 13.0;
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
      gapPriceStock +
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
  y += priceSize.height + gapPriceStock;

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
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (png == null) throw StateError('Image unavailable');
  return png.buffer.asUint8List();
}
