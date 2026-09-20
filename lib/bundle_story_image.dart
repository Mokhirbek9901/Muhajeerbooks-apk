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
  final deliveryIncluded = bundle['delivery_included'] == true;
  final comparisonTotal =
      regularTotal + (deliveryIncluded ? AppState.deliveryFee : 0);
  final saving =
      (comparisonTotal - setPrice).clamp(0, comparisonTotal).toInt();
  final percent = comparisonTotal > 0
      ? (saving * 100 / comparisonTotal).round()
      : 0;
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

  _bundleText(canvas, title, const Rect.fromLTWH(90, 215, 900, 115),
      size: 54, weight: FontWeight.w900, maxLines: 2);

  final totalBookQty = entries.fold<int>(0, (sum, entry) => sum + entry.qty);
  final countPill = RRect.fromRectAndRadius(
    const Rect.fromLTWH(205, 332, 670, 62),
    const Radius.circular(31),
  );
  canvas.drawRRect(countPill, Paint()..color = const Color(0xFFDDF0E7));
  _bundleText(
    canvas,
    '$totalBookQty ta kitobdan iborat maxsus to‘plam',
    const Rect.fromLTWH(225, 340, 630, 46),
    size: 27,
    weight: FontWeight.w800,
    color: teal,
    maxLines: 1,
  );

  // Coverlar doim yuqorida va markazda turadi. Kitob soni oshgani sari
  // kartalar avtomatik kichrayadi; hech qaysi cover story chetiga yopishmaydi.
  final shown = entries.take(6).toList();
  final count = shown.length;
  final columns = count <= 2 ? count.clamp(1, 2) : (count == 4 ? 2 : 3);
  final rows = count == 0 ? 1 : ((count + columns - 1) ~/ columns);
  const gridTop = 430.0;
  final cardW = count <= 1
      ? 360.0
      : (count == 2
          ? 315.0
          : (count == 3 ? 250.0 : (count == 4 ? 280.0 : 230.0)));
  final cardH = count <= 1
      ? 520.0
      : (count == 2
          ? 520.0
          : (count == 3 ? 410.0 : (count == 4 ? 390.0 : 350.0)));
  final gapX = count <= 2 ? 36.0 : 28.0;
  const gapY = 28.0;
  final imageH = cardH * (count <= 2 ? .70 : .62);
  final titleTopRatio = count <= 2 ? .72 : .66;
  final titleHeight = count <= 2 ? 68.0 : 54.0;
  final titleSize = count == 1 ? 29.0 : (count == 2 ? 25.0 : 20.0);
  final priceSize = count <= 2 ? 24.0 : 19.0;

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
    final coverW = (cardW * (count <= 2 ? .78 : .72)).clamp(120.0, 285.0);
    final imageRect = Rect.fromLTWH(
      x + (cardW - coverW) / 2,
      y + 16,
      coverW,
      imageH - 16,
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
  var y = afterGrid + 36;
  if (entries.length > 6) {
    _bundleText(canvas, '+ yana ${entries.length - 6} turdagi kitob',
        Rect.fromLTWH(100, y, 880, 42), size: 23, weight: FontWeight.w800, color: muted);
    y += 52;
  }

  const priceBoxLeft = 105.0;
  const priceBoxWidth = 870.0;
  const priceBoxHeight = 232.0;
  final priceBox = RRect.fromRectAndRadius(
    Rect.fromLTWH(priceBoxLeft, y, priceBoxWidth, priceBoxHeight),
    const Radius.circular(28),
  );
  canvas.drawRRect(priceBox, Paint()..color = const Color(0xFFF4F9F6));
  canvas.drawRRect(
    priceBox,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFD6E7DF),
  );

  _bundleText(canvas, 'Kitoblar narxi ($totalBookQty ta)',
      Rect.fromLTWH(145, y + 24, 555, 42),
      size: 27, weight: FontWeight.w700, color: navy, align: TextAlign.left, maxLines: 1);
  _bundleText(canvas, _wonBundle(regularTotal),
      Rect.fromLTWH(700, y + 24, 225, 42),
      size: 30, weight: FontWeight.w900, color: navy, align: TextAlign.right, maxLines: 1);

  _bundleText(canvas,
      deliveryIncluded ? 'Yetkazib berish (Koreya bo‘ylab)' : 'Yetkazib berish',
      Rect.fromLTWH(145, y + 76, 555, 42),
      size: 25, weight: FontWeight.w600, color: navy, align: TextAlign.left, maxLines: 1);
  _bundleText(canvas,
      deliveryIncluded ? _wonBundle(AppState.deliveryFee) : 'alohida',
      Rect.fromLTWH(700, y + 76, 225, 42),
      size: 29, weight: FontWeight.w900, color: navy, align: TextAlign.right, maxLines: 1);

  canvas.drawLine(Offset(145, y + 137), Offset(935, y + 137),
      Paint()..color = const Color(0xFFD6E7DF)..strokeWidth = 2);
  _bundleText(canvas, deliveryIncluded ? 'Jami (pochta bilan)' : 'Jami',
      Rect.fromLTWH(145, y + 158, 500, 46),
      size: 28, weight: FontWeight.w900, color: navy, align: TextAlign.left, maxLines: 1);
  _bundleText(canvas, _wonBundle(comparisonTotal),
      Rect.fromLTWH(665, y + 158, 260, 46),
      size: 32, weight: FontWeight.w900, color: muted, align: TextAlign.right,
      decoration: TextDecoration.lineThrough, maxLines: 1);

  y += priceBoxHeight + 28;
  // Pastga yo‘nalgan belgi.
  final arrow = Path()
    ..moveTo(510, y)
    ..lineTo(570, y)
    ..lineTo(540, y + 30)
    ..close();
  canvas.drawPath(arrow, Paint()..color = teal);
  y += 48;

  final setBanner = RRect.fromRectAndRadius(
    Rect.fromLTWH(145, y, 790, 108),
    const Radius.circular(26),
  );
  canvas.drawRRect(setBanner, Paint()..color = const Color(0xFF07877E));

  // Emoji shriftiga bog‘lanmaydigan sovg‘a ikonkasi — barcha qurilmada chiqadi.
  final giftPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final giftX = 188.0;
  final giftY = y + 29;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(giftX, giftY + 18, 52, 38),
      const Radius.circular(4),
    ),
    giftPaint,
  );
  canvas.drawLine(Offset(giftX - 5, giftY + 18), Offset(giftX + 57, giftY + 18), giftPaint);
  canvas.drawLine(Offset(giftX + 26, giftY + 18), Offset(giftX + 26, giftY + 56), giftPaint);
  canvas.drawOval(Rect.fromLTWH(giftX + 5, giftY - 1, 22, 20), giftPaint);
  canvas.drawOval(Rect.fromLTWH(giftX + 25, giftY - 1, 22, 20), giftPaint);

  _bundleText(canvas, 'SETDA  ${_wonBundle(setPrice)}',
      Rect.fromLTWH(255, y + 14, 635, 78),
      size: 50, weight: FontWeight.w900, color: Colors.white, maxLines: 1);

  if (saving > 0) {
    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(850, y - 28, 130, 66),
      const Radius.circular(30),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xFFDDF0E7));
    _bundleText(canvas, '-$percent%', Rect.fromLTWH(862, y - 18, 106, 46),
        size: 28, weight: FontWeight.w900, color: teal, maxLines: 1);
  }

  y += 124;
  final deliveryPill = RRect.fromRectAndRadius(
    Rect.fromLTWH(300, y, 480, 58),
    const Radius.circular(29),
  );
  canvas.drawRRect(deliveryPill, Paint()..color = const Color(0xFFDDF0E7));
  _bundleText(canvas,
      deliveryIncluded ? 'Yetkazib berish set narxida' : 'Yetkazib berish alohida',
      Rect.fromLTWH(320, y + 7, 440, 44), size: 24, weight: FontWeight.w800,
      color: deliveryIncluded ? green : muted, maxLines: 1);

  // CTA fixed koordinatada emas: pochta pillidan keyin joylashadi.
  // Ayniqsa 4 ta kitobli (2x2) setda pill bilan "buyurtma berish" yozuvi
  // endi bir-birining ustiga chiqmaydi.
  final ctaY = y + 82;
  _bundleText(canvas, 'Setni ko‘rish va buyurtma berish uchun bosing',
      Rect.fromLTWH(90, ctaY, 900, 58), size: 28, weight: FontWeight.w900,
      color: teal, maxLines: 1);
  final footerY = (ctaY + 76).clamp(0.0, 1870.0);
  _bundleText(canvas, '@muhajeerbooks', Rect.fromLTWH(90, footerY, 900, 36),
      size: 23, weight: FontWeight.w700, color: muted, maxLines: 1);

  final picture = recorder.endRecording();
  final image = await picture.toImage(1080, 1920);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('Story image unavailable');
  return data.buffer.asUint8List();
}
