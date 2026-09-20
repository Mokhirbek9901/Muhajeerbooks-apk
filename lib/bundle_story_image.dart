import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'app_state.dart';

final _bundleMoney = NumberFormat('#,###', 'en_US');
String _wonBundle(int value) => '₩${_bundleMoney.format(value)}';

Future<ui.Image?> _loadBundleCover(Book book) async {
  final candidates = <String>[
    book.previewImageUrl,
    book.imageUrl,
    ...book.imageUrls,
  ].map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  for (final url in candidates) {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) continue;
      final codec =
          await ui.instantiateImageCodec(response.bodyBytes, targetWidth: 320);
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // Thumbnail ishlamasa asl muqova manzilini sinab ko‘ramiz.
    }
  }
  return null;
}

void _bundleText(
  Canvas canvas,
  String value,
  Rect box, {
  double size = 30,
  FontWeight weight = FontWeight.w600,
  Color color = const Color(0xFF174652),
  TextAlign align = TextAlign.center,
  int maxLines = 2,
  TextDecoration? decoration,
}) {
  var fontSize = size;
  TextPainter painter;
  while (true) {
    painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
          height: 1.08,
          decoration: decoration,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: box.width);
    if ((!painter.didExceedMaxLines && painter.height <= box.height) || fontSize <= 16) break;
    painter.dispose();
    fontSize -= 1;
  }
  final x = align == TextAlign.left ? box.left : box.left + (box.width - painter.width) / 2;
  painter.paint(canvas, Offset(x, box.top + (box.height - painter.height) / 2));
  painter.dispose();
}

Future<Uint8List> renderBundleStory(
  Map<String, dynamic> bundle,
  List<Book> books,
) async {
  final rawItems = ((bundle['items'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  final entries = <({Book book, int qty})>[];
  var regularTotal = 0;
  for (final item in rawItems) {
    final id = (item['book_id'] ?? '').toString();
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    Book? found;
    for (final book in books) {
      if (book.id == id) { found = book; break; }
    }
    if (found != null) {
      entries.add((book: found, qty: qty));
      regularTotal += found.price * qty;
    }
  }

  final covers = <ui.Image?>[];
  for (final entry in entries.take(6)) {
    covers.add(await _loadBundleCover(entry.book));
  }

  final setPrice = (bundle['price'] as num?)?.toInt() ?? regularTotal;
  final saving = (regularTotal - setPrice).clamp(0, regularTotal).toInt();
  final percent = regularTotal > 0 ? (saving * 100 / regularTotal).round() : 0;
  final deliveryIncluded = bundle['delivery_included'] == true;
  final title = (bundle['title'] ?? 'Kitoblar seti').toString();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const cream = Color(0xFFF8F4E9);
  const navy = Color(0xFF174652);
  const teal = Color(0xFF0D625C);
  const muted = Color(0xFF66787D);
  const green = Color(0xFF187A55);
  const goldSoft = Color(0xFFF1E5CA);
  canvas.drawColor(cream, BlendMode.src);
  canvas.drawCircle(const Offset(1030, 170), 390, Paint()..color = const Color(0xFFDFEEE7));
  canvas.drawCircle(const Offset(20, 1150), 300, Paint()..color = goldSoft);

  _bundleText(canvas, 'MUHAJEER BOOKS', const Rect.fromLTWH(90, 85, 900, 70),
      size: 45, weight: FontWeight.w900);
  _bundleText(canvas, 'KITOBLAR SETI', const Rect.fromLTWH(90, 150, 900, 48),
      size: 24, weight: FontWeight.w800, color: teal);

  _bundleText(canvas, title, const Rect.fromLTWH(90, 215, 900, 135),
      size: 54, weight: FontWeight.w900, maxLines: 2);

  const gridLeft = 105.0;
  const gridTop = 385.0;
  const cardW = 270.0;
  const cardH = 385.0;
  const gapX = 30.0;
  const gapY = 30.0;
  final shown = entries.take(6).toList();

  for (var i = 0; i < shown.length; i++) {
    final row = i ~/ 3;
    final col = i % 3;
    final x = gridLeft + col * (cardW + gapX);
    final y = gridTop + row * (cardH + gapY);
    final card = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, cardW, cardH), const Radius.circular(22));
    canvas.drawShadow(Path()..addRRect(card), const Color(0x25174652), 12, false);
    canvas.drawRRect(card, Paint()..color = Colors.white);

    final image = covers.length > i ? covers[i] : null;
    if (image != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(x + 18, y + 18, cardW - 36, 245),
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + 18, y + 18, cardW - 36, 245), const Radius.circular(14)),
        Paint()..color = const Color(0xFFEAF1F0),
      );
    }
    _bundleText(canvas, shown[i].book.title, Rect.fromLTWH(x + 14, y + 270, cardW - 28, 58),
        size: 22, weight: FontWeight.w800, maxLines: 2);
    final qty = shown[i].qty;
    _bundleText(canvas, '${_wonBundle(shown[i].book.price)}${qty > 1 ? ' ×$qty' : ''}',
        Rect.fromLTWH(x + 14, y + 330, cardW - 28, 38),
        size: 21, weight: FontWeight.w800, color: teal, maxLines: 1);
  }
  for (final image in covers) { image?.dispose(); }

  final afterGrid = gridTop + (shown.length > 3 ? 2 : 1) * cardH + (shown.length > 3 ? gapY : 0);
  var y = afterGrid + 38;
  if (entries.length > 6) {
    _bundleText(canvas, '+ yana ${entries.length - 6} turdagi kitob',
        Rect.fromLTWH(100, y, 880, 42), size: 23, weight: FontWeight.w800, color: muted);
    y += 55;
  }

  if (saving > 0) {
    _bundleText(canvas, 'Oddiy narxi: ${_wonBundle(regularTotal)}',
        Rect.fromLTWH(100, y, 880, 46), size: 26, color: muted,
        decoration: TextDecoration.lineThrough, maxLines: 1);
    y += 50;
    _bundleText(canvas, '-$percent%  •  ${_wonBundle(saving)} tejaysiz',
        Rect.fromLTWH(100, y, 880, 52), size: 29, weight: FontWeight.w900, color: green, maxLines: 1);
    y += 62;
  }
  _bundleText(canvas, _wonBundle(setPrice), Rect.fromLTWH(100, y, 880, 82),
      size: 66, weight: FontWeight.w900, color: teal, maxLines: 1);
  y += 88;
  _bundleText(canvas, deliveryIncluded ? 'Yetkazib berish set narxida' : 'Yetkazib berish alohida',
      Rect.fromLTWH(100, y, 880, 48), size: 25, weight: FontWeight.w800,
      color: deliveryIncluded ? green : muted, maxLines: 1);

  _bundleText(canvas, 'Setni ko‘rish va buyurtma berish uchun bosing',
      const Rect.fromLTWH(90, 1720, 900, 65), size: 30, weight: FontWeight.w900, color: teal, maxLines: 2);
  _bundleText(canvas, '@muhajeerbooks', const Rect.fromLTWH(90, 1825, 900, 45),
      size: 27, weight: FontWeight.w700, color: muted, maxLines: 1);

  final picture = recorder.endRecording();
  final image = await picture.toImage(1080, 1920);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('Story image unavailable');
  return data.buffer.asUint8List();
}
