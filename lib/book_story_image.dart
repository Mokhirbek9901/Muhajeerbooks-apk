import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'app_state.dart';

const storyOrderLabel = 'Buyurtma berish uchun bosing';

String storyPrice(Book book) => book.price > 0
    ? '₩${NumberFormat('#,###').format(book.currentPrice)}'
    : 'Narxi aniqlanmoqda';

String _storyDescription(Book book) {
  final value = book.description
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (value.isEmpty || value == 'Ma’lumot kiritilmagan.') {
    final fallback = <String>[
      if (book.category.trim().isNotEmpty) book.category.trim(),
      if (book.publisher.trim().isNotEmpty) book.publisher.trim(),
      if (book.coverType.trim().isNotEmpty &&
          book.coverType != 'Ko‘rsatilmagan')
        book.coverType.trim(),
    ];
    return fallback.isEmpty
        ? 'Kitob haqida batafsil ma’lumotni ilovada ko‘ring.'
        : fallback.join(' · ');
  }
  return value;
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

  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 700);
  final cover = (await codec.getNextFrame()).image;
  codec.dispose();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const ink = Color(0xFF174652);
  const teal = Color(0xFF0D625C);
  const cream = Color(0xFFF8F4E9);
  const green = Color(0xFF187A55);
  const greenSoft = Color(0xFFE4F4EC);
  const red = Color(0xFFB53B3B);
  const redSoft = Color(0xFFFBE8E8);

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

  Size text(
    String value,
    double y,
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w500,
    int lines = 1,
    double width = 900,
    double height = 1.12,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, Offset((1080 - painter.width) / 2, y));
    final result = Size(painter.width, painter.height);
    painter.dispose();
    return result;
  }

  void stockPill() {
    final label = book.stock > 0
        ? 'Omborda: ${book.stock} dona'
        : 'Hozircha mavjud emas';
    final foreground = book.stock > 0 ? green : red;
    final background = book.stock > 0 ? greenSoft : redSoft;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 29,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: 700);

    final pillWidth = (painter.width + 58).clamp(290.0, 720.0).toDouble();
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(540, 1322),
        width: pillWidth,
        height: 62,
      ),
      const Radius.circular(31),
    );
    canvas.drawRRect(pillRect, Paint()..color = background);
    painter.paint(
      canvas,
      Offset((1080 - painter.width) / 2, 1322 - painter.height / 2),
    );
    painter.dispose();
  }

  text('MUHAJEER BOOKS', 120, 46, weight: FontWeight.w800);
  text('Koreyadagi o‘zbek kitob do‘koni', 182, 28);

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

  text(book.title, 1012, 54, weight: FontWeight.w800, lines: 2, height: 1.08);
  if (book.author.trim().isNotEmpty && book.author != 'Ko‘rsatilmagan') {
    text(book.author, 1135, 29, color: const Color(0xFF52656B));
  }

  text(
    storyPrice(book),
    1190,
    book.price > 0 ? 72 : 44,
    color: teal,
    weight: FontWeight.w900,
  );

  stockPill();

  final info = <String>[
    if (book.category.trim().isNotEmpty) book.category.trim(),
    if (book.publisher.trim().isNotEmpty) book.publisher.trim(),
  ].join(' · ');
  if (info.isNotEmpty) {
    text(info, 1370, 25, color: const Color(0xFF66787D));
  }

  text('KITOB HAQIDA', 1425, 22, color: teal, weight: FontWeight.w800);
  text(
    _storyDescription(book),
    1464,
    27,
    color: ink,
    weight: FontWeight.w500,
    lines: 3,
    width: 890,
    height: 1.22,
  );

  text(
    book.inStock ? storyOrderLabel : 'Kitob haqida batafsil',
    1615,
    38,
    color: teal,
    weight: FontWeight.w800,
  );

  final arrow = Paint()
    ..color = teal
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(const Offset(540, 1672), const Offset(540, 1710), arrow);
  canvas.drawPath(
    Path()
      ..moveTo(526, 1696)
      ..lineTo(540, 1710)
      ..lineTo(554, 1696),
    arrow,
  );

  // Blank area below the arrow is reserved for Instagram's real Link sticker.
  text('@muhajeerbooks', 1810, 28);

  final picture = recorder.endRecording();
  final image = await picture.toImage(1080, 1920);
  picture.dispose();
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (png == null) throw StateError('Image unavailable');
  return png.buffer.asUint8List();
}
