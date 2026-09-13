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

/// A full-resolution portrait image, independent of the preview screen size.
Future<Uint8List> renderBookStory(Book book, {Uint8List? coverBytes}) async {
  Uint8List bytes;
  if (coverBytes != null) {
    bytes = coverBytes;
  } else if (book.galleryImages.isNotEmpty) {
    final response = await http.get(Uri.parse(book.galleryImages.first))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('Cover unavailable');
    bytes = response.bodyBytes;
  } else {
    bytes = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer.asUint8List();
  }
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 700);
  final cover = (await codec.getNextFrame()).image;
  codec.dispose();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const ink = Color(0xFF174652);
  const teal = Color(0xFF0D625C);
  const cream = Color(0xFFF8F4E9);
  canvas.drawColor(cream, BlendMode.src);
  canvas.drawCircle(const Offset(1050, 150), 380,
      Paint()..color = const Color(0xFFDFEEE7));
  canvas.drawCircle(const Offset(30, 1100), 290,
      Paint()..color = const Color(0xFFF1E5CA));

  void text(String value, double y, double size, {
    Color color = ink, FontWeight weight = FontWeight.w500,
    int lines = 1, double width = 900,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: TextStyle(
        fontFamily: 'Roboto', fontSize: size, fontWeight: weight, color: color, height: 1.12,
      )),
      textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center,
      maxLines: lines, ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, Offset((1080 - painter.width) / 2, y));
    painter.dispose();
  }

  text('MUHAJEER BOOKS', 170, 46, weight: FontWeight.w800);
  text('Koreyadagi o‘zbek kitob do‘koni', 232, 28);
  final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(182, 320, 716, 810), const Radius.circular(38));
  canvas.drawShadow(Path()..addRRect(frame), const Color(0x33174652), 18, false);
  canvas.drawRRect(frame, Paint()..color = Colors.white);
  paintImage(canvas: canvas, rect: const Rect.fromLTWH(214, 350, 652, 750),
      image: cover, fit: BoxFit.contain, filterQuality: FilterQuality.high);
  cover.dispose();

  text(book.title, 1170, 58, weight: FontWeight.w800, lines: 3);
  if (book.author.trim().isNotEmpty && book.author != 'Ko‘rsatilmagan') {
    text(book.author, 1380, 30);
  }
  text(storyPrice(book), 1440, book.price > 0 ? 84 : 48,
      color: teal, weight: FontWeight.w900);
  final info = [book.category, book.publisher]
      .where((s) => s.trim().isNotEmpty).join(' · ');
  text(info, 1545, 27);
  text(book.inStock ? storyOrderLabel : 'Kitob haqida batafsil',
      1630, 39, color: teal, weight: FontWeight.w700);
  final arrow = Paint()..color = teal..strokeWidth = 5
      ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
  canvas.drawLine(const Offset(540, 1684), const Offset(540, 1718), arrow);
  canvas.drawPath(Path()..moveTo(526, 1704)..lineTo(540, 1718)
      ..lineTo(554, 1704), arrow);
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
