import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'app_state.dart';

final _bundleMoney = NumberFormat('#,###', 'en_US');
String _wonBundle(int value) => '₩${_bundleMoney.format(value)}';

Future<ui.Image?> _loadBundleCover(Book book) async {
  final candidates = <String>[
    book.imageUrl,
    ...book.imageUrls,
    book.previewImageUrl,
  ].map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

  for (final url in candidates) {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) continue;

      final decoded = img.decodeImage(response.bodyBytes);
      if (decoded == null) continue;
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
    } catch (_) {
      // Keyingi rasm manzilini sinab ko‘ramiz.
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

  // Kitob soniga qarab coverlar story ekranini to‘ldiradi:
  // 1–2 ta — katta, 3 ta — o‘rtacha, 4–6 ta — ixcham grid.
  final shown = entries.take(6).toList();
  final count = shown.length;
  final columns = count <= 2 ? count.clamp(1, 2) : (count == 4 ? 2 : 3);
  final rows = count == 0 ? 1 : ((count + columns - 1) ~/ columns);
  final gridLeft = count == 1 ? 315.0 : (count == 2 ? 115.0 : (columns == 2 ? 190.0 : 105.0));
  const gridTop = 385.0;
  final cardW = count == 1
      ? 450.0
      : (count == 2 ? 410.0 : (columns == 2 ? 335.0 : 270.0));
  final cardH = count == 1
      ? 600.0
      : (count == 2 ? 555.0 : (columns == 2 ? 455.0 : 385.0));
  final gapX = count <= 2 ? 30.0 : (columns == 2 ? 30.0 : 30.0);
  const gapY = 30.0;
  final imageH = cardH * (count <= 2 ? .72 : .64);
  final titleTopRatio = count <= 2 ? .75 : .70;
  final titleHeight = count <= 2 ? 72.0 : 58.0;
  final titleSize = count == 1 ? 31.0 : (count == 2 ? 27.0 : 22.0);
  final priceSize = count <= 2 ? 26.0 : 21.0;

  for (var i = 0; i < shown.length; i++) {
    final row = i ~/ columns;
    final col = i % columns;
    // Oxirgi qatorda bitta kitob qolsa markazga joylaymiz.
    final itemsInRow = (row == rows - 1 && count % columns != 0)
        ? count % columns
        : columns;
    final rowWidth = itemsInRow * cardW + (itemsInRow - 1) * gapX;
    final rowLeft = (1080 - rowWidth) / 2;
    final x = rowLeft + col * (cardW + gapX);
    final y = gridTop + row * (cardH + gapY);
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, cardW, cardH),
      const Radius.circular(22),
    );
    canvas.drawShadow(
      Path()..addRRect(card),
      const Color(0x25174652),
      12,
      false,
    );
    canvas.drawRRect(card, Paint()..color = Colors.white);

    final image = covers.length > i ? covers[i] : null;
    final imageRect = Rect.fromLTWH(
      x + 18,
      y + 18,
      cardW - 36,
      imageH - 18,
    );
    if (image != null) {
      paintImage(
        canvas: canvas,
        rect: imageRect,
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(imageRect, const Radius.circular(14)),
        Paint()..color = const Color(0xFFEAF1F0),
      );
    }

    final titleTop = y + cardH * titleTopRatio;
    _bundleText(
      canvas,
      shown[i].book.title,
      Rect.fromLTWH(x + 14, titleTop, cardW - 28, titleHeight),
      size: titleSize,
      weight: FontWeight.w800,
      maxLines: 2,
    );
    final qty = shown[i].qty;
    _bundleText(
      canvas,
      '${_wonBundle(shown[i].book.price)}${qty > 1 ? ' ×$qty' : ''}',
      Rect.fromLTWH(x + 14, y + cardH - 48, cardW - 28, 38),
      size: priceSize,
      weight: FontWeight.w800,
      color: teal,
      maxLines: 1,
    );
  }
  for (final image in covers) { image?.dispose(); }

  final afterGrid = gridTop + rows * cardH + (rows - 1) * gapY;
  var y = afterGrid + 38;
  if (entries.length > 6) {
    _bundleText(canvas, '+ yana ${entries.length - 6} turdagi kitob',
        Rect.fromLTWH(100, y, 880, 42), size: 23, weight: FontWeight.w800, color: muted);
    y += 55;
  }

  _bundleText(
    canvas,
    _wonBundle(regularTotal),
    Rect.fromLTWH(100, y, 880, 52),
    size: 31,
    weight: FontWeight.w800,
    color: muted,
    decoration: TextDecoration.lineThrough,
    maxLines: 1,
  );
  y += 55;
  _bundleText(
    canvas,
    'SETDA  ${_wonBundle(setPrice)}',
    Rect.fromLTWH(100, y, 880, 82),
    size: 61,
    weight: FontWeight.w900,
    color: teal,
    maxLines: 1,
  );
  if (saving > 0) {
    y += 82;
    _bundleText(canvas, '-$percent%  •  ${_wonBundle(saving)} tejaysiz',
        Rect.fromLTWH(100, y, 880, 52), size: 29, weight: FontWeight.w900, color: green, maxLines: 1);
  }
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
