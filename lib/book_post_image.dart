import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'book_story_image.dart';

/// A separate, edge-to-edge Instagram feed composition — NOT a resized Story.
/// Every Story template has a matching colour treatment, but the feed only
/// contains the book cover, its price, postage and a compact description.
Future<Uint8List> renderBookInstagramPost(
  Book book, {
  required BookStoryTemplate template,
  String? description,
  Uint8List? coverBytes,
}) async {
  const w = 1080;
  const h = 1350;
  Uint8List? source = coverBytes ?? await loadBookStoryCover(book);
  source ??= (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
      .buffer.asUint8List();

  ui.Codec? codec;
  ui.Image? cover;
  try {
    try {
      codec = await ui.instantiateImageCodec(source, targetWidth: 900);
      cover = (await codec.getNextFrame()).image;
    } catch (_) {
      codec?.dispose();
      codec = null;
      final fallback = (await rootBundle.load(
        'assets/images/muhajeer_logo.jpg',
      )).buffer.asUint8List();
      codec = await ui.instantiateImageCodec(fallback, targetWidth: 900);
      cover = (await codec.getNextFrame()).image;
    }

    final decodedCover = cover!;
    final base = bookStoryTemplateColor(template);
    final dark = base.computeLuminance() < 0.32;
    final ink = dark ? const Color(0xFFF9F2E7) : const Color(0xFF1F3036);
    final accent = switch (template) {
      BookStoryTemplate.obsidianEdition ||
      BookStoryTemplate.premiumEdition ||
      BookStoryTemplate.goldArch => const Color(0xFFE7C78B),
      BookStoryTemplate.sapphireEdition ||
      BookStoryTemplate.nightEdition ||
      BookStoryTemplate.cinema => const Color(0xFF8FC9EF),
      BookStoryTemplate.velvetEdition => const Color(0xFFF0B5A9),
      BookStoryTemplate.pearlEdition ||
      BookStoryTemplate.atlasLuxeEdition ||
      BookStoryTemplate.adras => const Color(0xFFB87B46),
      _ => dark ? const Color(0xFFD8C59B) : const Color(0xFF08786E),
    };

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const bounds = Rect.fromLTWH(0, 0, 1080, 1350);

    // The chosen design fills all 1080x1350 pixels, with no grey sidebars,
    // boxed 9:16 Story, or outer picture-frame.
    canvas.drawRect(bounds, Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(1080, 1350),
        [
          Color.lerp(base, dark ? Colors.white : Colors.black, 0.06)!,
          base,
          Color.lerp(base, dark ? Colors.black : Colors.white, 0.08)!,
        ],
        [0.0, 0.56, 1.0],
      ));

    // Light native geometry makes different template colour palettes feel
    // intentional without placing additional words on the post.
    final deco = Paint()
      ..color = accent.withValues(alpha: dark ? 0.12 : 0.095)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(const Offset(1060, 120), 310, deco);
    canvas.drawCircle(const Offset(20, 1260), 280, deco);
    canvas.drawLine(const Offset(85, 1066), const Offset(995, 1066),
      Paint()..color = accent.withValues(alpha: 0.55)..strokeWidth = 2);

    // Keep the actual full book-cover artwork; no cropping or false title
    // recreated outside the book itself.
    final coverRect = fittedStoryCoverRect(
      const Rect.fromLTWH(82, 42, 916, 840),
      Size(decodedCover.width.toDouble(), decodedCover.height.toDouble()),
    );
    final roundedCover = RRect.fromRectAndRadius(
      coverRect,
      const Radius.circular(13),
    );
    canvas.drawShadow(
      Path()..addRRect(roundedCover),
      const Color(0x85000000),
      30,
      false,
    );
    canvas.save();
    canvas.clipRRect(roundedCover);
    canvas.drawImageRect(
      decodedCover,
      Rect.fromLTWH(0, 0, decodedCover.width.toDouble(), decodedCover.height.toDouble()),
      coverRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    // Only two compact items on the same horizontal line.
    _paintPostText(
      canvas, storyPrice(book),
      x: 70, y: 946, maxWidth: 485, maxHeight: 92,
      maxFont: 66, minFont: 27,
      color: accent, weight: FontWeight.w900,
    );
    _paintPostText(
      canvas, 'Pochta: ₩4,000',
      x: 575, y: 958, maxWidth: 440, maxHeight: 80,
      maxFont: 38, minFont: 26,
      color: ink, weight: FontWeight.w700,
      align: TextAlign.right,
    );

    // No product title, author, publisher or stock information is painted.
    // The book title may naturally be visible on the actual cover.
    final copy = (description ?? book.description)
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    if (copy.isNotEmpty && copy != 'Ma’lumot kiritilmagan.') {
      _paintPostDescription(canvas, copy, ink);
    }

    final picture = recorder.endRecording();
    try {
      final output = await picture.toImage(w, h);
      try {
        final data = await output.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('Instagram post PNG export failed');
        }
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        output.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    cover?.dispose();
    codec?.dispose();
  }
}

void _paintPostText(
  Canvas canvas,
  String value, {
  required double x,
  required double y,
  required double maxWidth,
  required double maxHeight,
  required double maxFont,
  required double minFont,
  required Color color,
  required FontWeight weight,
  TextAlign align = TextAlign.left,
}) {
  TextPainter? painter;
  for (var size = maxFont; size >= minFont; size -= 1) {
    painter?.dispose();
    painter = TextPainter(
      text: TextSpan(text: value, style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: 1.12,
        color: color,
      )),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    if (painter.height <= maxHeight && !painter.didExceedMaxLines) break;
  }
  if (painter == null) return;
  painter.paint(canvas, Offset(x, y + (maxHeight - painter.height) / 2));
  painter.dispose();
}

void _paintPostDescription(Canvas canvas, String copy, Color ink) {
  const maxWidth = 915.0;
  const maxHeight = 222.0;
  TextPainter? painter;
  for (var size = 29.0; size >= 18.0; size -= 1) {
    painter?.dispose();
    painter = TextPainter(
      text: TextSpan(text: copy, style: TextStyle(
        fontSize: size,
        height: 1.22,
        fontWeight: FontWeight.w500,
        color: ink,
      )),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    if (painter.height <= maxHeight) break;
  }
  if (painter == null) return;
  // Very long descriptions are shortened at a complete line rather than
  // overflowing/cutting into the edge of the exported image.
  if (painter.height > maxHeight) {
    painter.dispose();
    painter = TextPainter(
      text: TextSpan(text: copy, style: TextStyle(
        fontSize: 18,
        height: 1.22,
        fontWeight: FontWeight.w500,
        color: ink,
      )),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: (maxHeight / (18 * 1.22)).floor(),
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }
  final y = 1090 + math.max(0, (222 - painter.height) / 2);
  painter.paint(canvas, Offset((1080 - maxWidth) / 2, y));
  painter.dispose();
}
