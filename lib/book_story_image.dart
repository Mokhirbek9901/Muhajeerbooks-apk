import 'dart:async';
import 'dart:math' as Math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'app_state.dart';

const storyOrderLabel = 'Buyurtma berish uchun bosing';

enum BookStoryTemplate { current, oldCurrent, smartMatch, decorative, spring, summer, autumn, winter, editorial, library, arch, emerald, minimal, sunset, magazine, classic, poster, noir, geometric, paper, split, polaroid, collage, coverFocus, editorialPage, lifestyle, cleanStudio, goldArch, scrapbook, silk, botanical, mosaic, midnight, gallery, atlas, marble, cinema, terracotta, royal, ornament, adras, kokand, khiva, turon, yurt, heritage }

String bookStoryTemplateName(BookStoryTemplate value) => switch (value) {
  BookStoryTemplate.current => 'Avto dizayn',
  BookStoryTemplate.oldCurrent => 'Hozir',
  BookStoryTemplate.smartMatch => 'Mos dizayn',
  BookStoryTemplate.decorative => 'Klassik',
  BookStoryTemplate.spring => 'Bahor',
  BookStoryTemplate.summer => 'Yoz',
  BookStoryTemplate.autumn => 'Kuz',
  BookStoryTemplate.winter => 'Qish',
  BookStoryTemplate.editorial => 'Yorug‘',
  BookStoryTemplate.library => 'Kutubxona',
  BookStoryTemplate.arch => 'Sharqona',
  BookStoryTemplate.emerald => 'Zumrad',
  BookStoryTemplate.minimal => 'Minimal',
  BookStoryTemplate.sunset => 'Oqshom',
  BookStoryTemplate.magazine => 'Jurnal',
  BookStoryTemplate.classic => 'Klassik',
  BookStoryTemplate.poster => 'Poster',
  BookStoryTemplate.noir => 'Zamonaviy',
  BookStoryTemplate.geometric => 'Geometrik',
  BookStoryTemplate.paper => 'Qog‘oz',
  BookStoryTemplate.split => 'Ikki qism',
  BookStoryTemplate.polaroid => 'Polaroid',
  BookStoryTemplate.collage => 'Kollaj',
  BookStoryTemplate.coverFocus => 'Muqova',
  BookStoryTemplate.editorialPage => 'Sahifa',
  BookStoryTemplate.lifestyle => 'Lifestyle',
  BookStoryTemplate.cleanStudio => 'Clean',
  BookStoryTemplate.goldArch => 'Premium',
  BookStoryTemplate.scrapbook => 'Scrapbook',
  BookStoryTemplate.silk => 'Ipak',
  BookStoryTemplate.botanical => 'Botanika',
  BookStoryTemplate.mosaic => 'Paxta',
  BookStoryTemplate.midnight => 'Tun',
  BookStoryTemplate.gallery => 'Galereya',
  BookStoryTemplate.atlas => 'Bahor',
  BookStoryTemplate.marble => 'Registon',
  BookStoryTemplate.cinema => 'Tun va shahar',
  BookStoryTemplate.terracotta => 'Gulshan',
  BookStoryTemplate.royal => 'Koshin',
  BookStoryTemplate.ornament => 'Sado',
  BookStoryTemplate.adras => 'Naqqosh',
  BookStoryTemplate.kokand => 'Qo‘qon',
  BookStoryTemplate.khiva => 'Xiva',
  BookStoryTemplate.turon => 'Turon',
  BookStoryTemplate.yurt => 'Xattotlik',
  BookStoryTemplate.heritage => 'Chorsu',
};

Color bookStoryTemplateColor(BookStoryTemplate value) => switch (value) {
  BookStoryTemplate.current => const Color(0xFFF8F4E9),
  BookStoryTemplate.oldCurrent => const Color(0xFFF8F4E9),
  BookStoryTemplate.smartMatch => const Color(0xFFEDE8DC),
  BookStoryTemplate.decorative => const Color(0xFFF0E1D1),
  BookStoryTemplate.spring => const Color(0xFFF5E7EC),
  BookStoryTemplate.summer => const Color(0xFFFFE6A3),
  BookStoryTemplate.autumn => const Color(0xFFB9673B),
  BookStoryTemplate.winter => const Color(0xFFDDEBF2),
  BookStoryTemplate.editorial => const Color(0xFFF4EFE4),
  BookStoryTemplate.library => const Color(0xFF24150E),
  BookStoryTemplate.arch => const Color(0xFFF5F0E5),
  BookStoryTemplate.emerald => const Color(0xFF073D3B),
  BookStoryTemplate.minimal => const Color(0xFFF7F4EA),
  BookStoryTemplate.sunset => const Color(0xFF9A5A31),
  BookStoryTemplate.magazine => const Color(0xFFEDE8DC),
  BookStoryTemplate.classic => const Color(0xFFF2E7D2),
  BookStoryTemplate.poster => const Color(0xFFE64A3B),
  BookStoryTemplate.noir => const Color(0xFFE9E7E2),
  BookStoryTemplate.geometric => const Color(0xFF184D68),
  BookStoryTemplate.paper => const Color(0xFFF0E5CC),
  BookStoryTemplate.split => const Color(0xFFE8D7BD),
  BookStoryTemplate.polaroid => const Color(0xFFCCD8C8),
  BookStoryTemplate.collage => const Color(0xFFF1C64B),
  BookStoryTemplate.coverFocus => const Color(0xFF242424),
  BookStoryTemplate.editorialPage => const Color(0xFFF1E7D2),
  BookStoryTemplate.lifestyle => const Color(0xFFB56E43),
  BookStoryTemplate.cleanStudio => const Color(0xFFF4F4F0),
  BookStoryTemplate.goldArch => const Color(0xFF17110D),
  BookStoryTemplate.scrapbook => const Color(0xFFE9D8B9),
  BookStoryTemplate.silk => const Color(0xFFF3D8D4),
  BookStoryTemplate.botanical => const Color(0xFFE8E3CF),
  BookStoryTemplate.mosaic => const Color(0xFFF4EEE2),
  BookStoryTemplate.midnight => const Color(0xFF17152B),
  BookStoryTemplate.gallery => const Color(0xFFF2EEE7),
  BookStoryTemplate.atlas => const Color(0xFFE8D7DD),
  BookStoryTemplate.marble => const Color(0xFFE8F0E9),
  BookStoryTemplate.cinema => const Color(0xFF101C2B),
  BookStoryTemplate.terracotta => const Color(0xFFF2D9CC),
  BookStoryTemplate.royal => const Color(0xFF073F48),
  BookStoryTemplate.ornament => const Color(0xFFE9E0D0),
  BookStoryTemplate.adras => const Color(0xFF6B3E22),
  BookStoryTemplate.kokand => const Color(0xFFF0D7B0),
  BookStoryTemplate.khiva => const Color(0xFF116A72),
  BookStoryTemplate.turon => const Color(0xFF173B32),
  BookStoryTemplate.yurt => const Color(0xFFF2E7D2),
  BookStoryTemplate.heritage => const Color(0xFF1F6570),
};

String storyPrice(Book book) {
  if (book.preorderEnabled) {
    final min = book.currentPrice;
    final max = book.preorderPriceMax;
    if (min <= 0 && max <= 0) return 'Taxminiy narxi aniqlanmoqda';
    final minText = NumberFormat('#,###').format(min > 0 ? min : max);
    if (max > min && min > 0) {
      return 'Taxminiy narxi: ₩$minText ~ ₩${NumberFormat('#,###').format(max)}';
    }
    return 'Taxminiy narxi: ₩$minText';
  }
  return book.price > 0
      ? '₩${NumberFormat('#,###').format(book.currentPrice)}'
      : 'Narxi aniqlanmoqda';
}

String _storyActionLabel(Book book) =>
    book.preorderEnabled
        ? 'Oldindan buyurtma uchun bosing'
        : (book.inStock ? storyOrderLabel : 'Kitob haqida batafsil');

String _storyDescription(Book book) {
  final value = book.description.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (book.preorderEnabled) {
    final arrival = book.preorderArrivalNote.trim().isEmpty
        ? 'kelish muddati aniqlanmoqda'
        : 'taxminiy kelishi: ${book.preorderArrivalNote.trim()}';
    final min = NumberFormat('#,###').format(book.preorderDepositMin);
    final max = NumberFormat('#,###').format(book.preorderDepositMax);
    final base = 'OLDINDAN BUYURTMA • $arrival • oldindan to‘lov ₩$min–₩$max • yakuniy narx kitob kelganda aniq bo‘ladi.';
    if (value.isEmpty || value == 'Ma’lumot kiritilmagan.') return base;
    return '$base $value';
  }
  if (value.isEmpty || value == 'Ma’lumot kiritilmagan.') {
    return 'Kitob haqida batafsil ma’lumotni ilovada ko‘ring.';
  }
  return value;
}

Future<Uint8List> _exportStoryPng(ui.Image image) async {
  // Safari/CanvasKit ba'zan PNG encoder bosqichida null/xato qaytaradi.
  // Native PNG ishlamasa raw RGBA ni CPU orqali PNGga aylantiramiz.
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png != null && png.lengthInBytes > 0) {
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    }
  } catch (_) {}

  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (rgba == null || rgba.lengthInBytes == 0) {
    throw StateError('Story export unavailable');
  }
  final raster = img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodePng(raster, level: 4));
}

class _CoverPalette {
  const _CoverPalette({
    required this.background,
    required this.ink,
    required this.accent,
    required this.softAccent,
    required this.softWarm,
    required this.brightness,
    required this.saturation,
    required this.warmth,
    required this.isPortrait,
  });

  final Color background;
  final Color ink;
  final Color accent;
  final Color softAccent;
  final Color softWarm;
  final double brightness;
  final double saturation;
  final double warmth;
  final bool isPortrait;
}

_CoverPalette _paletteFromCover(Uint8List encoded) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) {
    return const _CoverPalette(
      background: Color(0xFFF8F4E9),
      ink: Color(0xFF174652),
      accent: Color(0xFF0D625C),
      softAccent: Color(0xFFDFEEE7),
      softWarm: Color(0xFFF1E5CA),
      brightness: 0.75,
      saturation: 0.25,
      warmth: 0.0,
      isPortrait: true,
    );
  }

  final sample = img.copyResize(decoded, width: 28, height: 28);
  var r = 0.0, g = 0.0, b = 0.0, weight = 0.0;
  for (var y = 0; y < sample.height; y++) {
    for (var x = 0; x < sample.width; x++) {
      final p = sample.getPixel(x, y);
      final pr = p.r.toDouble();
      final pg = p.g.toDouble();
      final pb = p.b.toDouble();
      final maxC = [pr, pg, pb].reduce((a, b) => a > b ? a : b);
      final minC = [pr, pg, pb].reduce((a, b) => a < b ? a : b);
      final saturation = (maxC - minC) / 255.0;
      // Oqartirilgan sahifa fonlari dominant bo‘lib ketmasin:
      // rangli piksellarga biroz ko‘proq vazn beramiz.
      final w = 0.35 + saturation * 1.65;
      r += pr * w;
      g += pg * w;
      b += pb * w;
      weight += w;
    }
  }

  final base = Color.fromARGB(
    255,
    (r / weight).round().clamp(0, 255),
    (g / weight).round().clamp(0, 255),
    (b / weight).round().clamp(0, 255),
  );
  final hsl = HSLColor.fromColor(base);
  final accentHsl = hsl.withSaturation((hsl.saturation * 1.35).clamp(0.38, 0.82))
      .withLightness(hsl.lightness.clamp(0.28, 0.46));
  final accent = accentHsl.toColor();
  final ink = accentHsl.withLightness(0.20).withSaturation(
    (accentHsl.saturation * 0.72).clamp(0.28, 0.70),
  ).toColor();
  final background = hsl.withSaturation(
    (hsl.saturation * 0.28).clamp(0.06, 0.22),
  ).withLightness(0.955).toColor();
  final softAccent = accentHsl.withSaturation(
    (accentHsl.saturation * 0.30).clamp(0.08, 0.24),
  ).withLightness(0.90).toColor();
  final warmHue = (hsl.hue + 34) % 360;
  final softWarm = HSLColor.fromAHSL(1, warmHue, 0.22, 0.89).toColor();

  final brightness = ((r + g + b) / weight) / (255.0 * 3.0);
  final saturation = hsl.saturation;
  final warmth = (((r / weight) - (b / weight)) / 255.0).clamp(-1.0, 1.0);
  return _CoverPalette(
    background: background,
    ink: ink,
    accent: accent,
    softAccent: softAccent,
    softWarm: softWarm,
    brightness: brightness,
    saturation: saturation,
    warmth: warmth,
    isPortrait: decoded.height >= decoded.width,
  );
}

String _storySemanticText(Book book) {
  return [
    book.title,
    book.author,
    book.publisher,
    book.description,
  ].join(' ').toLowerCase();
}

int _storyTheme(Book book) {
  final t = _storySemanticText(book);
  bool has(List<String> words) => words.any(t.contains);

  if (has(['alloh', 'qur’on', 'quron', 'islom', 'musulmon', 'namoz', 'rasul',
           'payg‘ambar', 'paygambar', 'sahoba', 'tobein', 'hadis', 'duo',
           'iymon', 'imon', 'halol', 'jannat', 'oxirat', 'diniy', 'qiroat',
           'qiraat', 'tajvid', 'arab tili', 'arabcha', 'mabda', 'mabdaul',
           'fiqh', 'aqida', 'siyrat'])) return 1;
  if (has(['qotillik', 'jinoyat', 'sir', 'detektiv', 'o‘lim', 'olim',
           'qotil', 'tergov', 'mahbus', 'jinoyatchi'])) return 2;
  if (has(['sevgi', 'muhabbat', 'qalb', 'nikoh', 'oila', 'ayol', 'er-xotin',
           'romantik', 'sog‘inch', 'hijron'])) return 3;
  if (has(['pul', 'boy', 'biznes', 'moliya', 'savdo', 'strategiya', 'muvaffaqiyat',
           'lider', 'marketing', 'boylik', 'invest'])) return 4;
  if (has(['bola', 'bolalar', 'ertak', 'sarguzasht', 'maktab', 'o‘smir',
           'osmir', 'farzand'])) return 5;
  if (has(['tarix', 'amir', 'sulton', 'xon', 'temur', 'jadid', 'istiqlol',
           'urush', 'davlat', 'saltanat'])) return 6;
  if (has(['psixolog', 'fikrlash', 'odat', 'ego', 'ruhiyat', 'motiv',
           'o‘zini', 'ozini', 'tafakkur'])) return 7;
  if (has(['she’r', 'sher', 'poeziya', 'hikoya', 'roman', 'qissa',
           'adabiyot'])) return 8;
  return 0;
}

BookStoryTemplate _bestExistingTemplate(Book book, Uint8List encoded) {
  final p = _paletteFromCover(encoded);
  final theme = _storyTheme(book);

  // Avval mazmun: kitob nimaga oid ekanini nomi/tavsifi orqali aniqlaymiz.
  switch (theme) {
    case 1: // diniy
      return p.brightness < 0.48 ? BookStoryTemplate.goldArch : BookStoryTemplate.arch;
    case 2: // detektiv / jinoyat
      return p.brightness < 0.58 ? BookStoryTemplate.cinema : BookStoryTemplate.noir;
    case 3: // sevgi / oila
      return p.saturation > 0.38 ? BookStoryTemplate.terracotta : BookStoryTemplate.botanical;
    case 4: // biznes / pul
      return p.brightness < 0.45 ? BookStoryTemplate.goldArch : BookStoryTemplate.cleanStudio;
    case 5: // bolalar / sarguzasht
      return p.saturation > 0.42 ? BookStoryTemplate.lifestyle : BookStoryTemplate.polaroid;
    case 6: // tarix
      return p.warmth > 0 ? BookStoryTemplate.adras : BookStoryTemplate.marble;
    case 7: // psixologiya / self-help
      return p.saturation > 0.35 ? BookStoryTemplate.royal : BookStoryTemplate.cleanStudio;
    case 8: // badiiy
      return p.warmth > 0.08 ? BookStoryTemplate.scrapbook : BookStoryTemplate.ornament;
  }

  // Mavzu aniq topilmasa, muqova vizual xarakteri bo‘yicha.
  if (p.brightness < 0.30) return p.saturation > 0.40 ? BookStoryTemplate.cinema : BookStoryTemplate.goldArch;
  if (p.saturation > 0.62) return p.warmth > 0.08 ? BookStoryTemplate.lifestyle : BookStoryTemplate.royal;
  if (p.warmth > 0.20) return p.saturation > 0.32 ? BookStoryTemplate.adras : BookStoryTemplate.scrapbook;
  if (p.warmth < -0.14) return p.saturation > 0.30 ? BookStoryTemplate.royal : BookStoryTemplate.marble;
  if (p.brightness > 0.80 && p.saturation < 0.22) return BookStoryTemplate.cleanStudio;
  if (p.brightness > 0.66) return p.saturation > 0.30 ? BookStoryTemplate.botanical : BookStoryTemplate.ornament;
  return p.saturation > 0.32 ? BookStoryTemplate.terracotta : BookStoryTemplate.noir;
}

int _coverVisualSignature(Uint8List encoded) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) return 0;
  final s = img.copyResize(decoded, width: 12, height: 12);
  var hash = 17;
  for (var y = 0; y < s.height; y += 2) {
    for (var x = 0; x < s.width; x += 2) {
      final p = s.getPixel(x, y);
      hash = (hash * 31 + p.r.toInt() * 3 + p.g.toInt() * 5 + p.b.toInt() * 7 + x * 11 + y * 13) & 0x7fffffff;
    }
  }
  return hash;
}

int _autoStoryVariant(Book book, _CoverPalette p) {
  final theme = _storyTheme(book);

  // Avto dizayn bir mavzu uchun ham bitta qolipga qamalib qolmaydi.
  // Nom/tavsif mavzuni beradi; muqovaning yorqinligi, to‘yinganligi va
  // issiq-sovuqligi esa shu mavzu ichidagi boshqa kompozitsiyani tanlaydi.
  switch (theme) {
    case 1: // diniy/qiroat
      if (p.brightness < 0.42) return 12; // qoramtir: premium masjid
      if (p.saturation > 0.42) return 13; // rangli: koshin/geometrik
      return 4;                           // och: mihrab
    case 2: // detektiv
      return p.brightness < 0.42 ? 5 : 14; // noir / kesik poster
    case 3: // sevgi/oila
      return p.warmth > 0.08 ? 6 : 15;     // iliq organik / nafis botanika
    case 4: // biznes
      return p.brightness < 0.44 ? 16 : 7; // qora premium / grid
    case 5: // bolalar
      return p.saturation > 0.48 ? 8 : 17; // rangli / yumshoq polaroid
    case 6: // tarix
      return p.warmth > 0.05 ? 9 : 18;     // klassik / koshin tarixiy
    case 7: // psixologiya
      return p.saturation > 0.38 ? 19 : 10;// gradient / minimal
    case 8: // badiiy
      return p.warmth > 0.06 ? 11 : 20;    // jurnal / galereya
  }

  if (p.saturation > 0.48) return 0;
  if (p.brightness < 0.43) return 1;
  if (p.warmth > 0.10) return 2;
  return 3;
}

Future<ui.Image> _decodeStoryCover(Uint8List encoded) async {
  // iPhone/Safari uchun compressed JPEG/WebP/PNG teksturasini CanvasKit'ga
  // bevosita uzatmaymiz. Muqovani avval oddiy RGBA pikselga aylantiramiz.
  // Bu usul avvalgi barqaror Story rendererda qora frame va raster xatolarini
  // bartaraf qilgan; 360px limit esa xotira sarfini past ushlab turadi.
  final decoded = img.decodeImage(encoded);
  if (decoded == null) throw StateError('Cover decode failed');

  final resized = decoded.width > 360
      ? img.copyResize(
          decoded,
          width: 360,
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

Future<Uint8List?> _generateAiStoryBackground(Book book, Uint8List coverBytes, {String? adminCode}) async {
  // Never call the paid image API for ordinary customers.
  if (adminCode == null || adminCode.trim().isEmpty) return null;
  try {
    final request = http.MultipartRequest(
      'POST',
      kIsWeb
          ? Uri.base.resolve('/api/ai-story-background')
          : Uri.parse('https://muhajeer-books-live-production.up.railway.app/api/ai-story-background'),
    );
    request.fields['admin_code'] = adminCode.trim();
    request.fields['title'] = book.title;
    request.fields['category'] = book.category;
    request.fields['description'] = _storyDescription(book);
    final decodedCover = img.decodeImage(coverBytes);
    if (decodedCover == null) return null;
    // APIga format nomuvofiqligi ketmasligi uchun muqovani doim haqiqiy JPEG qilib yuboramiz.
    final aiCover = Uint8List.fromList(img.encodeJpg(decodedCover, quality: 90));
    request.files.add(http.MultipartFile.fromBytes(
      'cover',
      aiCover,
      filename: 'cover.jpg',
    ));
    final streamed = await request.send().timeout(const Duration(minutes: 4));
    if (streamed.statusCode != 200) return null;
    final bytes = await streamed.stream.toBytes();
    return bytes.isEmpty ? null : Uint8List.fromList(bytes);
  } catch (_) {
    // AI vaqtincha ishlamasa odatiy Avto dizayn avtomatik fallback bo‘ladi.
    return null;
  }
}

Future<Uint8List> _renderAiStory(
  Book book, {
  required Uint8List coverBytes,
  required Uint8List backgroundBytes,
  double renderScale = 1.0,
}) async {
  final safeScale = renderScale.clamp(0.5, 1.0).toDouble();
  final cover = await _decodeStoryCover(coverBytes);
  final background = await _decodeStoryCover(backgroundBytes);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(safeScale);

  paintImage(
    canvas: canvas,
    rect: const Rect.fromLTWH(0, 0, 1080, 1920),
    image: background,
    fit: BoxFit.cover,
    filterQuality: FilterQuality.high,
  );
  // Matn qismi AI fonidan qat'i nazar doim o‘qilishi uchun yumshoq panel.
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(70, 940, 940, 840), const Radius.circular(46)),
    Paint()..color = const Color(0xF5F8F5EC),
  );

  const coverRect = Rect.fromLTWH(250, 165, 580, 700);
  final card = RRect.fromRectAndRadius(coverRect.inflate(20), const Radius.circular(34));
  canvas.drawShadow(Path()..addRRect(card), const Color(0x55000000), 22, false);
  canvas.drawRRect(card, Paint()..color = Colors.white);
  paintImage(canvas: canvas, rect: coverRect, image: cover, fit: BoxFit.contain, filterQuality: FilterQuality.high);

  void center(String value, double y, double size, Color color, FontWeight weight, {double width=880, int lines=2}) {
    final p=TextPainter(
      text:TextSpan(text:value,style:TextStyle(fontFamily:'Roboto',fontSize:size,fontWeight:weight,color:color,height:1.08)),
      textDirection:ui.TextDirection.ltr,textAlign:TextAlign.center,maxLines:lines,ellipsis:'…',
    )..layout(maxWidth:width);
    p.paint(canvas,Offset((1080-p.width)/2,y)); p.dispose();
  }
  const ink=Color(0xFF174652), teal=Color(0xFF08786E);
  center('MUHAJEER BOOKS', 975, 25, ink, FontWeight.w900, lines:1);
  center(book.title, 1035, 48, ink, FontWeight.w900);
  center(storyPrice(book), 1155, 66, teal, FontWeight.w900, lines:1);
  center('🚚  Yetkazib berish: ₩4,000', 1250, 22, const Color(0xFF49666E), FontWeight.w700, lines:1);
  center(book.preorderEnabled ? 'Oldindan sotuvda' : (book.stock > 0 ? 'Omborda: ${book.stock} dona' : 'Hozircha mavjud emas'), 1300, 28,
      book.stock > 0 ? const Color(0xFF187A55) : const Color(0xFFB53B3B), FontWeight.w800, lines:1);
  center(_storyDescription(book), 1365, 22, ink, FontWeight.w500, width:840, lines:3);
  center(_storyActionLabel(book), 1515, 33, teal, FontWeight.w900, lines:1);
  final arrow=Paint()..color=teal..strokeWidth=5..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;
  canvas.drawLine(const Offset(540,1570),const Offset(540,1618),arrow);
  canvas.drawPath(Path()..moveTo(522,1600)..lineTo(540,1618)..lineTo(558,1600),arrow);
  center('@muhajeerbooks', 1695, 26, ink, FontWeight.w500, lines:1);

  final picture=recorder.endRecording();
  final image=await picture.toImage((1080*safeScale).round(),(1920*safeScale).round());
  picture.dispose();
  final png=await _exportStoryPng(image);
  image.dispose(); cover.dispose(); background.dispose();
  return png;
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

Future<Uint8List> renderBookStoryCpuFallback(
  Book book, {
  BookStoryTemplate template = BookStoryTemplate.current,
}) async {
  // Oxirgi xavfsiz yo‘l: Flutter Canvas/CanvasKit umuman ishlamasa ham
  // Story'ni sof CPU raster orqali yaratamiz. Bu iPhone Safari GPU/raster
  // xatolariga bog‘liq emas.
  Uint8List? source = await _downloadStoryCover(book);
  source ??= (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
      .buffer
      .asUint8List();

  img.Image? decoded = img.decodeImage(source);
  if (decoded == null) {
    final fallback = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer
        .asUint8List();
    decoded = img.decodeImage(fallback);
  }
  if (decoded == null) throw StateError('CPU story cover unavailable');

  final out = img.Image(width: 540, height: 960, numChannels: 3);
  img.fill(out, color: img.ColorRgb8(248, 244, 233));

  // Milliy dizaynlar uchun yengil, GPU talab qilmaydigan ramka.
  final accent = switch (template) {
    BookStoryTemplate.smartMatch => img.ColorRgb8(18, 99, 93),
    BookStoryTemplate.adras => img.ColorRgb8(123, 36, 72),
    BookStoryTemplate.kokand => img.ColorRgb8(142, 88, 42),
    BookStoryTemplate.khiva => img.ColorRgb8(17, 106, 114),
    BookStoryTemplate.turon => img.ColorRgb8(23, 59, 50),
    BookStoryTemplate.yurt => img.ColorRgb8(171, 52, 45),
    BookStoryTemplate.heritage => img.ColorRgb8(139, 61, 46),
    _ => img.ColorRgb8(18, 63, 73),
  };
  img.drawRect(out, x1: 18, y1: 18, x2: 521, y2: 941, color: accent, thickness: 8);
  img.drawRect(out, x1: 32, y1: 32, x2: 507, y2: 927, color: accent, thickness: 2);

  final cover = img.copyResize(
    decoded,
    width: 300,
    interpolation: img.Interpolation.average,
  );
  final maxH = 520;
  final fitted = cover.height > maxH
      ? img.copyResize(cover, height: maxH, interpolation: img.Interpolation.average)
      : cover;
  final x = ((540 - fitted.width) / 2).round();
  final y = 155 + ((520 - fitted.height) / 2).round();
  img.fillRect(out, x1: x - 10, y1: y - 10, x2: x + fitted.width + 9,
      y2: y + fitted.height + 9, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(out, fitted, dstX: x, dstY: y);

  // Pastki bloklar dizaynning asosiy rangini saqlaydi; matn UI'dagi
  // tanlangan kitob ma'lumotlarida baribir ko‘rinadi.
  img.fillRect(out, x1: 70, y1: 735, x2: 469, y2: 805, color: accent);
  img.fillRect(out, x1: 120, y1: 830, x2: 419, y2: 842, color: accent);

  return Uint8List.fromList(img.encodePng(out, level: 4));
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
  double renderScale = 1.0,
  String? adminCode,
}) async {
  final safeScale = renderScale.clamp(0.5, 1.0).toDouble();

  Uint8List? bytes = coverBytes;
  if (template == BookStoryTemplate.oldCurrent) {
    Uint8List? oldBytes = coverBytes;
    oldBytes ??= await _downloadStoryCover(book);
    oldBytes ??= (await rootBundle.load('assets/images/muhajeer_logo.jpg')).buffer.asUint8List();
    return _renderOldCurrentStory(
      book,
      coverBytes: oldBytes,
      renderScale: safeScale,
    );
  }

  if (template == BookStoryTemplate.smartMatch) {
    bytes ??= await _downloadStoryCover(book);
    bytes ??= (await rootBundle.load('assets/images/muhajeer_logo.jpg')).buffer.asUint8List();
    final matched = _bestExistingTemplate(book, bytes);
    return _renderAlternativeBookStory(
      book,
      matched,
      coverBytes: bytes,
      renderScale: safeScale,
    );
  }

  if (template != BookStoryTemplate.current) {
    return _renderAlternativeBookStory(
      book,
      template,
      coverBytes: coverBytes,
      renderScale: safeScale,
    );
  }
  bytes ??= await _downloadStoryCover(book);
  bytes ??= (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
      .buffer
      .asUint8List();

  // Avto dizayn avval muqovani AI bilan ko‘rib, aynan shu kitobga mos
  // yangi fon yaratadi. API/billing/tarmoq xatosida eski lokal Avto davom etadi.
  final aiBackground = await _generateAiStoryBackground(book, bytes, adminCode: adminCode);
  if (aiBackground != null) {
    try {
      return await _renderAiStory(
        book,
        coverBytes: bytes,
        backgroundBytes: aiBackground,
        renderScale: safeScale,
      );
    } catch (_) {
      // Render xatosida ham mavjud lokal Avto dizaynni yo‘qotmaymiz.
    }
  }

  ui.Image cover;
  try {
    cover = await _decodeStoryCover(bytes);
  } catch (_) {
    final fallback = (await rootBundle.load('assets/images/muhajeer_logo.jpg'))
        .buffer
        .asUint8List();
    cover = await _decodeStoryCover(fallback);
  }

  final palette = _paletteFromCover(bytes);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(safeScale);
  final ink = palette.ink;
  final teal = palette.accent;
  final cream = palette.background;
  const green = Color(0xFF187A55);
  const greenSoft = Color(0xFFE4F4EC);
  const red = Color(0xFFB53B3B);
  const redSoft = Color(0xFFFBE8E8);
  const muted = Color(0xFF66787D);
  const deliveryText = Color(0xFF49666E);
  const deliverySoft = Color(0xFFEAF1F0);

  void simpleText(
    String value,
    double y,
    double size, {
    Color? color,
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
          color: color ?? ink,
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

  // AVTO DIZAYN: muqovaning yorqinligi, rang to‘yinganligi, issiq/sovuq
  // palitrasi va formatiga qarab nafaqat rang, balki kompozitsiya ham almashadi.
  final autoVariant = _autoStoryVariant(book, palette);
  final visualSignature = _coverVisualSignature(bytes);
  final motif = visualSignature % 7;
  final motif2 = (visualSignature ~/ 7) % 5;

  late final Rect coverRect;
  late final double contentStart;
  if (autoVariant == 0) {
    canvas.drawColor(cream, BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 410, 1920), Paint()..color = ink);
    canvas.drawCircle(const Offset(1020, 120), 330, Paint()..color = palette.softAccent);
    canvas.drawRect(const Rect.fromLTWH(410, 0, 16, 1920), Paint()..color = teal);
    simpleText('MUHAJEER', 82, 34, color: Colors.white, weight: FontWeight.w900, width: 330);
    simpleText('BOOKS', 126, 25, color: palette.softWarm, weight: FontWeight.w700, width: 330);
    coverRect = const Rect.fromLTWH(150, 245, 780, 680);
    contentStart = 952;
  } else if (autoVariant == 1) {
    canvas.drawColor(ink, BlendMode.src);
    canvas.drawCircle(const Offset(890, 220), 430, Paint()..color = teal.withAlpha(95));
    canvas.drawCircle(const Offset(150, 780), 260, Paint()..color = palette.accent.withAlpha(70));
    canvas.drawRect(const Rect.fromLTWH(0, 930, 1080, 990), Paint()..color = cream);
    simpleText('MUHAJEER BOOKS', 90, 38, color: Colors.white, weight: FontWeight.w800);
    coverRect = const Rect.fromLTWH(245, 225, 590, 650);
    contentStart = 966;
  } else if (autoVariant == 2) {
    canvas.drawColor(cream, BlendMode.src);
    final arch = Path()
      ..moveTo(115, 925)
      ..lineTo(115, 430)
      ..quadraticBezierTo(540, 60, 965, 430)
      ..lineTo(965, 925)
      ..close();
    canvas.drawPath(arch, Paint()..color = palette.softWarm);
    canvas.drawPath(arch, Paint()..style = PaintingStyle.stroke..strokeWidth = 9..color = teal);
    canvas.drawCircle(const Offset(540, 145), 20, Paint()..color = teal);
    simpleText('MUHAJEER BOOKS', 92, 36, weight: FontWeight.w800);
    coverRect = const Rect.fromLTWH(245, 245, 590, 640);
    contentStart = 958;
  } else if (autoVariant == 3) {
    canvas.drawColor(cream, BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 220), Paint()..color = palette.softAccent);
    canvas.drawRect(const Rect.fromLTWH(70, 255, 940, 650), Paint()..color = Colors.white);
    canvas.drawLine(const Offset(70, 935), const Offset(1010, 935), Paint()..color = teal..strokeWidth = 3);
    simpleText('MUHAJEER BOOKS', 72, 42, weight: FontWeight.w900);
    coverRect = const Rect.fromLTWH(170, 285, 740, 590);
    contentStart = 968;
  } else if (autoVariant == 4) {
    // Diniy/qiroat: mihrab va islomiy geometrik ruh. Dekor matnga tegmaydi.
    canvas.drawColor(const Color(0xFFF6F1E5), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..color = const Color(0xFFF6F1E5));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 188), Paint()..color = const Color(0xFF244F45));
    simpleText('MUHAJEER BOOKS', 48, 34, color: Colors.white, weight: FontWeight.w900);

    final arch = Path()
      ..moveTo(185, 845)
      ..lineTo(185, 420)
      ..quadraticBezierTo(540, 105, 895, 420)
      ..lineTo(895, 845)
      ..close();
    canvas.drawPath(arch, Paint()..color = const Color(0xFFE8DDC1));
    canvas.drawPath(arch, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..color = const Color(0xFFB08A48));

    // Geometrik yulduzlar faqat bo‘sh yon zonalarda.
    for (final center in [const Offset(105, 350), const Offset(975, 350), const Offset(105, 720), const Offset(975, 720)]) {
      final star = Path();
      for (var i = 0; i < 8; i++) {
        final a = i * 3.141592653589793 / 4;
        final rr = i.isEven ? 28.0 : 13.0;
        final point = Offset(center.dx + rr * Math.cos(a), center.dy + rr * Math.sin(a));
        if (i == 0) star.moveTo(point.dx, point.dy); else star.lineTo(point.dx, point.dy);
      }
      star.close();
      canvas.drawPath(star, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFFB08A48));
    }
    coverRect = const Rect.fromLTWH(285, 245, 510, 555);
    contentStart = 875;
  } else if (autoVariant == 5) {
    // Detektiv: kino afishasi kabi keskin qorong‘i kompozitsiya.
    canvas.drawColor(const Color(0xFF10141A), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(0, 790, 1080, 1130), Paint()..color = cream);
    canvas.drawRect(const Rect.fromLTWH(70, 70, 12, 650), Paint()..color = const Color(0xFFC63D32));
    coverRect = const Rect.fromLTWH(195, 150, 690, 590);
    contentStart = 845;
  } else if (autoVariant == 6) {
    // Sevgi/oila: yumshoq, iliq va organik shakllar.
    canvas.drawColor(const Color(0xFFF8EDEA), BlendMode.src);
    canvas.drawCircle(const Offset(90, 260), 300, Paint()..color = palette.softWarm);
    canvas.drawCircle(const Offset(1010, 650), 350, Paint()..color = palette.softAccent);
    simpleText('MUHAJEER BOOKS', 70, 31, color: const Color(0xFF7B4B50), weight: FontWeight.w800);
    coverRect = const Rect.fromLTWH(230, 190, 620, 650);
    contentStart = 925;
  } else if (autoVariant == 7) {
    // Biznes: qat’iy grid/editorial.
    canvas.drawColor(const Color(0xFFF1F0EB), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 355, 900), Paint()..color = const Color(0xFF18252B));
    canvas.drawRect(const Rect.fromLTWH(355, 0, 16, 900), Paint()..color = teal);
    simpleText('MUHAJEER', 74, 31, color: Colors.white, weight: FontWeight.w900, width: 290);
    coverRect = const Rect.fromLTWH(420, 130, 570, 680);
    contentStart = 930;
  } else if (autoVariant == 8) {
    // Bolalar/sarguzasht: rangli kartochkali ko‘rinish.
    canvas.drawColor(const Color(0xFFFFF7DE), BlendMode.src);
    canvas.drawCircle(const Offset(120, 130), 125, Paint()..color = const Color(0xFFFFD05A));
    canvas.drawCircle(const Offset(950, 230), 155, Paint()..color = const Color(0xFF8ED5C2));
    canvas.drawCircle(const Offset(930, 780), 110, Paint()..color = const Color(0xFFF29A8A));
    simpleText('MUHAJEER BOOKS', 68, 34, color: const Color(0xFF294C55), weight: FontWeight.w900);
    coverRect = const Rect.fromLTWH(210, 190, 660, 650);
    contentStart = 925;
  } else if (autoVariant == 9) {
    // Tarix: milliy, vazmin klassik ramka.
    canvas.drawColor(const Color(0xFFEDE0C6), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(55, 55, 970, 820), Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = const Color(0xFF6A432A));
    canvas.drawRect(const Rect.fromLTWH(75, 75, 930, 780), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFFB28A57));
    simpleText('MUHAJEER BOOKS', 82, 31, color: const Color(0xFF5A3927), weight: FontWeight.w900);
    coverRect = const Rect.fromLTWH(255, 190, 570, 620);
    contentStart = 925;
  } else if (autoVariant == 10) {
    // Psixologiya/self-help: toza zamonaviy minimal.
    canvas.drawColor(const Color(0xFFF5F6F2), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 150), Paint()..color = ink);
    canvas.drawCircle(const Offset(900, 700), 250, Paint()..color = palette.softAccent);
    simpleText('MUHAJEER BOOKS', 50, 31, color: Colors.white, weight: FontWeight.w900);
    coverRect = const Rect.fromLTWH(185, 210, 710, 620);
    contentStart = 915;
  } else if (autoVariant == 11) {
    // Badiiy/adabiy: jurnal sahifasi.
    canvas.drawColor(const Color(0xFFF3EBDD), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(65, 60, 950, 820), Paint()..color = Colors.white);
    canvas.drawLine(const Offset(120, 150), const Offset(960, 150), Paint()..color = ink..strokeWidth = 3);
    coverRect = const Rect.fromLTWH(235, 205, 610, 620);
    contentStart = 930;
  } else if (autoVariant == 12) {
    canvas.drawColor(const Color(0xFF102E29), BlendMode.src);
    canvas.drawCircle(const Offset(540, 390), 350, Paint()..color = const Color(0xFF1B493E));
    canvas.drawCircle(const Offset(540, 390), 305, Paint()..style=PaintingStyle.stroke..strokeWidth=8..color=const Color(0xFFC8A65C));
    coverRect = const Rect.fromLTWH(285, 185, 510, 600);
    contentStart = 875;
  } else if (autoVariant == 13) {
    canvas.drawColor(const Color(0xFFEAF2ED), BlendMode.src);
    for (var x=60.0; x<1080; x+=120) {
      canvas.drawCircle(Offset(x, 410), 42, Paint()..style=PaintingStyle.stroke..strokeWidth=5..color=teal.withAlpha(130));
    }
    canvas.drawRect(const Rect.fromLTWH(0,0,1080,165), Paint()..color=teal);
    coverRect = const Rect.fromLTWH(245, 215, 590, 590);
    contentStart = 885;
  } else if (autoVariant == 14) {
    canvas.drawColor(const Color(0xFFF0EEE8), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(0,0,1080,720), Paint()..color=const Color(0xFF25272C));
    canvas.drawRect(const Rect.fromLTWH(0,620,1080,100), Paint()..color=const Color(0xFFB43D34));
    coverRect = const Rect.fromLTWH(330, 145, 600, 610);
    contentStart = 835;
  } else if (autoVariant == 15) {
    canvas.drawColor(const Color(0xFFF6F0ED), BlendMode.src);
    canvas.drawCircle(const Offset(120,250), 260, Paint()..color=const Color(0xFFDDE7D5));
    canvas.drawCircle(const Offset(980,650), 310, Paint()..color=const Color(0xFFEACFD4));
    coverRect = const Rect.fromLTWH(260, 180, 560, 650);
    contentStart = 915;
  } else if (autoVariant == 16) {
    canvas.drawColor(const Color(0xFF15191C), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(0,0,1080,150), Paint()..color=const Color(0xFFC49A4A));
    coverRect = const Rect.fromLTWH(220, 205, 640, 610);
    contentStart = 900;
  } else if (autoVariant == 17) {
    canvas.drawColor(const Color(0xFFFFF8E8), BlendMode.src);
    canvas.drawCircle(const Offset(130,180), 90, Paint()..color=const Color(0xFFFFD66B));
    canvas.drawCircle(const Offset(930,260), 120, Paint()..color=const Color(0xFFA9D9CF));
    canvas.drawCircle(const Offset(130,760), 75, Paint()..color=const Color(0xFFE7B5C8));
    coverRect = const Rect.fromLTWH(230, 190, 620, 630);
    contentStart = 910;
  } else if (autoVariant == 18) {
    canvas.drawColor(const Color(0xFFE8EFEA), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(45,45,990,820), Paint()..style=PaintingStyle.stroke..strokeWidth=8..color=const Color(0xFF17646B));
    canvas.drawRect(const Rect.fromLTWH(68,68,944,774), Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=const Color(0xFFB99250));
    coverRect = const Rect.fromLTWH(255, 190, 570, 620);
    contentStart = 915;
  } else if (autoVariant == 19) {
    canvas.drawRect(const Rect.fromLTWH(0,0,1080,1920), Paint()..shader=ui.Gradient.linear(
      const Offset(0,0), const Offset(1080,900), [palette.softAccent, palette.softWarm]));
    canvas.drawCircle(const Offset(900,160), 240, Paint()..color=teal.withAlpha(55));
    coverRect = const Rect.fromLTWH(205, 185, 670, 640);
    contentStart = 910;
  } else {
    canvas.drawColor(const Color(0xFFF7F5F0), BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(75,75,930,760), Paint()..color=Colors.white);
    canvas.drawLine(const Offset(100,135), const Offset(980,135), Paint()..color=teal..strokeWidth=4);
    coverRect = const Rect.fromLTWH(185, 185, 710, 600);
    contentStart = 890;
  }

  // Muqovaning o‘z piksel tuzilishidan olinadigan fingerprint har kitobda
  // dekor, ritm va joylashuvni boshqacha qiladi. Bu tasodifiy emas:
  // bir xil kitob bir xil, boshqa muqova esa boshqa kompozitsiya oladi.
  final motifPaint = Paint()
    ..color = teal.withAlpha(55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  if (motif == 0) {
    for (var i=0;i<5;i++) canvas.drawCircle(Offset(90+i*55.0, 185+motif2*18.0), 18+i*4.0, motifPaint);
  } else if (motif == 1) {
    for (var i=0;i<6;i++) canvas.drawLine(Offset(45+i*42.0,210),Offset(150+i*42.0,90),motifPaint);
  } else if (motif == 2) {
    final p=Path()..moveTo(65,180)..quadraticBezierTo(150,80,235,180)..quadraticBezierTo(320,280,405,180);
    canvas.drawPath(p,motifPaint);
  } else if (motif == 3) {
    for (var i=0;i<4;i++) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(55+i*48.0,120+i*20.0,90,90),const Radius.circular(18)),motifPaint);
  } else if (motif == 4) {
    canvas.drawArc(const Rect.fromLTWH(55,80,300,240),0.2,2.5,false,motifPaint);
    canvas.drawArc(const Rect.fromLTWH(725,80,300,240),0.4,2.3,false,motifPaint);
  } else if (motif == 5) {
    for (var i=0;i<7;i++) canvas.drawCircle(Offset(70+i*45.0,140+(i%2)*35),7,motifPaint..style=PaintingStyle.fill);
    motifPaint.style=PaintingStyle.stroke;
  } else {
    canvas.drawPath(Path()..moveTo(55,150)..lineTo(160,85)..lineTo(265,150)..lineTo(370,85),motifPaint);
  }

  final frame = RRect.fromRectAndRadius(
    coverRect.inflate(autoVariant == 0 ? 22 : 24),
    Radius.circular(autoVariant == 0 ? 18 : 34),
  );
  canvas.drawShadow(Path()..addRRect(frame), palette.ink.withAlpha(58), 18, false);
  canvas.drawRRect(frame, Paint()..color = Colors.white);
  canvas.drawRect(coverRect, Paint()..color = Colors.white);
  paintImage(
    canvas: canvas,
    rect: coverRect,
    image: cover,
    fit: autoVariant >= 3 ? BoxFit.contain : BoxFit.cover,
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
  const gapAuthorPrice = 13.0;
  const gapPriceDelivery = 6.0;
  const gapDeliveryStock = 10.0;
  const gapStockPublisher = 11.0;
  const gapPublisherDescription = 16.0;
  const gapStockDescription = 18.0;
  const gapDescriptionCta = 22.0;
  const ctaHeight = 46.0;
  const arrowArea = 62.0;

  final minBlockTop = contentStart;
  final maxBlockTop = contentStart + 38;
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
    value: _storyActionLabel(book),
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
    _storyActionLabel(book),
    y,
    cta,
    width: 820,
    color: teal,
    weight: FontWeight.w800,
    lineHeight: 1,
    maxLines: 1,
  );
  y += ctaSize.height + 16;

  final arrow = Paint()
    ..color = teal
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(Offset(540, y), Offset(540, y + 46), arrow);
  canvas.drawPath(
    Path()
      ..moveTo(523, y + 29)
      ..lineTo(540, y + 46)
      ..lineTo(557, y + 29),
    arrow,
  );

  simpleText('@muhajeerbooks', 1748, 28);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (1080 * safeScale).round(),
    (1920 * safeScale).round(),
  );
  picture.dispose();
  // Safari/CanvasKit ayrim iPhone'larda toByteData() tugaguncha source texture
  // kerak bo‘ladi. Cover'ni bundan oldin dispose qilish qora to‘rtburchak beradi.
  final png = await _exportStoryPng(image);
  image.dispose();
  cover.dispose();
  return png;
}


Future<Uint8List> _renderOldCurrentStory(
  Book book, {
  required Uint8List coverBytes,
  double renderScale = 1.0,
}) async {
  final safeScale = renderScale.clamp(0.5, 1.0).toDouble();
  ui.Image cover;
  try {
    cover = await _decodeStoryCover(coverBytes);
  } catch (_) {
    cover = await _decodeStoryCover(
      (await rootBundle.load('assets/images/muhajeer_logo.jpg')).buffer.asUint8List(),
    );
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(safeScale);
  const bg = Color(0xFFF8F6ED);
  const ink = Color(0xFF174E5A);
  const teal = Color(0xFF08786E);
  canvas.drawColor(bg, BlendMode.src);

  // Eski "Hozir": katta pastel organik doiralar.
  canvas.drawCircle(const Offset(1030, 165), 360, Paint()..color = const Color(0xFFDDEEE8));
  canvas.drawCircle(const Offset(20, 1010), 300, Paint()..color = const Color(0xFFF2DFC0));

  void centerText(String value, double y, double size, Color color, FontWeight weight, {double width=900}) {
    final p=TextPainter(
      text: TextSpan(text:value, style:TextStyle(fontFamily:'Roboto',fontSize:size,fontWeight:weight,color:color,height:1.05)),
      textDirection:ui.TextDirection.ltr,textAlign:TextAlign.center,maxLines:2,
    )..layout(maxWidth:width);
    p.paint(canvas,Offset((1080-p.width)/2,y));
    p.dispose();
  }

  centerText('MUHAJEER BOOKS', 82, 43, ink, FontWeight.w900);

  const coverRect=Rect.fromLTWH(185,255,710,650);
  final card=RRect.fromRectAndRadius(coverRect.inflate(28),const Radius.circular(34));
  canvas.drawShadow(Path()..addRRect(card),const Color(0x33000000),18,false);
  canvas.drawRRect(card,Paint()..color=Colors.white);
  paintImage(canvas:canvas,rect:coverRect,image:cover,fit:BoxFit.contain,filterQuality:FilterQuality.high);

  final title=_fitText(value:book.title,maxWidth:900,maxHeight:88,maxFontSize:48,minFontSize:32,lineHeight:1.02,maxLines:2,weight:FontWeight.w800);
  _paintText(canvas,book.title,955,title,width:900,color:ink,weight:FontWeight.w800,lineHeight:1.02,maxLines:2);

  final price=_fitText(value:storyPrice(book),maxWidth:760,maxHeight:72,maxFontSize:68,minFontSize:46,lineHeight:1,maxLines:1,weight:FontWeight.w900);
  _paintText(canvas,storyPrice(book),1020,price,width:760,color:teal,weight:FontWeight.w900,lineHeight:1,maxLines:1);

  centerText('🚚  Yetkazib berish: ₩4,000', 1100, 20, const Color(0xFF49666E), FontWeight.w700);
  centerText(book.preorderEnabled?'Oldindan sotuvda':(book.stock>0?'Omborda: ${book.stock} dona':'Hozircha mavjud emas'), 1152, 27, book.stock>0?const Color(0xFF187A55):const Color(0xFFB53B3B), FontWeight.w800);
  centerText(_storyDescription(book), 1220, 24, ink, FontWeight.w500, width:900);
  centerText(_storyActionLabel(book), 1295, 34, teal, FontWeight.w900);

  final arrow=Paint()..color=teal..strokeWidth=5..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;
  canvas.drawLine(const Offset(540,1350),const Offset(540,1395),arrow);
  canvas.drawPath(Path()..moveTo(523,1378)..lineTo(540,1395)..lineTo(557,1378),arrow);
  centerText('@muhajeerbooks', 1790, 27, ink, FontWeight.w500);

  final picture=recorder.endRecording();
  final image=await picture.toImage((1080*safeScale).round(),(1920*safeScale).round());
  picture.dispose();
  final png=await _exportStoryPng(image);
  image.dispose();
  cover.dispose();
  return png;
}

Future<Uint8List> _renderAlternativeBookStory(
  Book book,
  BookStoryTemplate template, {
  Uint8List? coverBytes,
  double renderScale = 1.0,
}) async {
  final safeScale = renderScale.clamp(0.5, 1.0).toDouble();
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
  canvas.scale(safeScale);
  const navy = Color(0xFF123F49);
  const teal = Color(0xFF08786E);
  const cream = Color(0xFFF7F2E7);
  const muted = Color(0xFF5F6F72);
  final dark = template == BookStoryTemplate.autumn ||
      template == BookStoryTemplate.library ||
      template == BookStoryTemplate.emerald ||
      template == BookStoryTemplate.geometric ||
      template == BookStoryTemplate.coverFocus ||
      template == BookStoryTemplate.lifestyle ||
      template == BookStoryTemplate.goldArch ||
      template == BookStoryTemplate.midnight ||
      template == BookStoryTemplate.cinema ||
      template == BookStoryTemplate.royal ||
      template == BookStoryTemplate.adras ||
      template == BookStoryTemplate.khiva ||
      template == BookStoryTemplate.turon ||
      false;
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

  void twoToneTextBox(
    String value, Rect rect, double size, {
    required Color leftColor,
    required Color rightColor,
    double splitX = 540,
    FontWeight weight = FontWeight.w600,
    TextAlign align = TextAlign.center,
    int maxLines = 2,
    String fontFamily = 'Roboto',
    FontStyle fontStyle = FontStyle.normal,
    double letterSpacing = 0,
  }) {
    var s = size;
    TextPainter p;
    while (true) {
      p = TextPainter(
        text: TextSpan(text: value, style: TextStyle(
          fontFamily: fontFamily, fontSize: s, fontWeight: weight,
          fontStyle: fontStyle, letterSpacing: letterSpacing,
          color: leftColor, height: 1.08)),
        textDirection: ui.TextDirection.ltr, textAlign: align,
        maxLines: maxLines, ellipsis: '…',
      )..layout(maxWidth: rect.width);
      if ((!p.didExceedMaxLines && p.height <= rect.height) || s <= 15) break;
      p.dispose();
      s -= 1;
    }
    final x = align == TextAlign.left ? rect.left : rect.left + (rect.width - p.width) / 2;
    final y = rect.top + (rect.height - p.height) / 2;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(rect.left, rect.top, splitX, rect.bottom));
    p.paint(canvas, Offset(x, y));
    canvas.restore();

    final p2 = TextPainter(
      text: TextSpan(text: value, style: TextStyle(
        fontFamily: fontFamily, fontSize: s, fontWeight: weight,
        fontStyle: fontStyle, letterSpacing: letterSpacing,
        color: rightColor, height: 1.08)),
      textDirection: ui.TextDirection.ltr, textAlign: align,
      maxLines: maxLines, ellipsis: '…',
    )..layout(maxWidth: rect.width);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(splitX, rect.top, rect.right, rect.bottom));
    p2.paint(canvas, Offset(x, y));
    canvas.restore();
    p2.dispose();
    p.dispose();
  }

  void rounded(Rect rect, Color color, {double radius = 28, Color? stroke}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rr, Paint()..color = color);
    if (stroke != null) canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = stroke);
  }

  switch (template) {
    case BookStoryTemplate.oldCurrent:
      canvas.drawColor(cream, BlendMode.src);
      break;
    case BookStoryTemplate.smartMatch:
      canvas.drawColor(cream, BlendMode.src);
      canvas.drawCircle(const Offset(980, 180), 320, Paint()..color = const Color(0xFFE1EFE7));
      break;
    case BookStoryTemplate.decorative:
      canvas.drawColor(const Color(0xFFF7F0E1), BlendMode.src);
      // Klassik: nafis sharqona arka, oltin chiziqlar va simmetrik ornament.
      final classicArch = Path()
        ..moveTo(105, 880)
        ..lineTo(105, 390)
        ..quadraticBezierTo(540, 20, 975, 390)
        ..lineTo(975, 880);
      canvas.drawPath(classicArch, Paint()..style=PaintingStyle.stroke..strokeWidth=7..color=const Color(0xFFB58A46));
      canvas.drawPath(
        Path()..moveTo(132,880)..lineTo(132,410)..quadraticBezierTo(540,75,948,410)..lineTo(948,880),
        Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=const Color(0xFFD4B77D));
      for (final x in [85.0, 995.0]) {
        canvas.drawCircle(Offset(x,300), 34, Paint()..style=PaintingStyle.stroke..strokeWidth=3..color=const Color(0xFFB58A46));
        canvas.drawCircle(Offset(x,300), 12, Paint()..color=const Color(0xFFD4B77D));
      }
      canvas.drawRect(const Rect.fromLTWH(42,42,996,1836), Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=const Color(0xFFD4B77D));
      break;
    case BookStoryTemplate.spring:
      canvas.drawColor(const Color(0xFFF9EEF2), BlendMode.src);
      canvas.drawCircle(const Offset(100, 180), 280, Paint()..color = const Color(0xFFF1C9D7));
      canvas.drawCircle(const Offset(1000, 520), 330, Paint()..color = const Color(0xFFDDE9C9));
      for (final o in [const Offset(120,250), const Offset(185,315), const Offset(920,160), const Offset(975,225)]) {
        canvas.drawCircle(o, 22, Paint()..color = const Color(0xFFE79AB2));
        canvas.drawCircle(o.translate(20, 8), 15, Paint()..color = const Color(0xFFF7C6D4));
      }
      break;
    case BookStoryTemplate.summer:
      canvas.drawRect(const Rect.fromLTWH(0,0,1080,1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0,0), const Offset(0,1920), [const Color(0xFF86D9E8), const Color(0xFFFFE8A8)]));
      canvas.drawCircle(const Offset(900, 170), 120, Paint()..color = const Color(0xFFFFC83D));
      canvas.drawPath(Path()..moveTo(0,720)..quadraticBezierTo(260,620,540,730)..quadraticBezierTo(820,840,1080,700)..lineTo(1080,930)..lineTo(0,930)..close(),
        Paint()..color = const Color(0xFF59BFA8));
      break;
    case BookStoryTemplate.autumn:
      canvas.drawRect(const Rect.fromLTWH(0,0,1080,1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0,0), const Offset(1080,1920), [const Color(0xFF4A2B24), const Color(0xFFD68B45)]));
      for (final o in [const Offset(100,160), const Offset(920,230), const Offset(130,760), const Offset(980,690)]) {
        final leaf=Path()..moveTo(o.dx,o.dy)..quadraticBezierTo(o.dx+70,o.dy-45,o.dx+95,o.dy+30)..quadraticBezierTo(o.dx+35,o.dy+70,o.dx,o.dy)..close();
        canvas.drawPath(leaf, Paint()..color = const Color(0xFFE3A24B));
      }
      break;
    case BookStoryTemplate.winter:
      canvas.drawRect(const Rect.fromLTWH(0,0,1080,1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0,0), const Offset(0,1920), [const Color(0xFFB9D7E6), const Color(0xFFF7FBFD)]));
      for (final o in [const Offset(120,150),const Offset(260,90),const Offset(850,130),const Offset(970,300),const Offset(120,700),const Offset(940,760)]) {
        canvas.drawCircle(o, 9, Paint()..color = Colors.white);
        canvas.drawLine(o.translate(-18,0),o.translate(18,0),Paint()..color=Colors.white..strokeWidth=4);
        canvas.drawLine(o.translate(0,-18),o.translate(0,18),Paint()..color=Colors.white..strokeWidth=4);
      }
      break;
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
      // ZAMONAVIY — editorial asymmetry, monochrome + amber.
      canvas.drawColor(const Color(0xFFF0EEE9), BlendMode.src);
      canvas.drawPath(Path()..moveTo(0,0)..lineTo(720,0)..lineTo(500,1920)..lineTo(0,1920)..close(),
        Paint()..color=const Color(0xFF171717));
      canvas.drawRect(const Rect.fromLTWH(720,0,360,1920),Paint()..color=const Color(0xFFF5F2EC));
      canvas.drawRect(const Rect.fromLTWH(740,130,18,470),Paint()..color=const Color(0xFFD18B32));
      canvas.drawCircle(const Offset(900,1540),115,Paint()..color=const Color(0xFFD18B32));
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
    case BookStoryTemplate.editorialPage:
      canvas.drawColor(const Color(0xFFF2E8D5), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(54, 54, 972, 1812),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFFB9A88B));
      canvas.drawLine(const Offset(92, 545), const Offset(500, 545),
        Paint()..strokeWidth = 2..color = const Color(0xFF6D5B43));
      canvas.drawCircle(const Offset(930, 1640), 145, Paint()..color = const Color(0x22A77D4F));
      break;
    case BookStoryTemplate.lifestyle:
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0, 0), const Offset(1080, 1920),
        [const Color(0xFF6A3C25), const Color(0xFFD39A62), const Color(0xFF302018)]));
      canvas.drawRect(const Rect.fromLTWH(620, 120, 330, 680), Paint()..color = const Color(0x557BC5D0));
      canvas.drawRect(const Rect.fromLTWH(650, 150, 270, 620), Paint()..color = const Color(0x55F4D28B));
      canvas.drawLine(const Offset(785, 150), const Offset(785, 770), Paint()..strokeWidth = 12..color = const Color(0x9970462E));
      canvas.drawLine(const Offset(650, 455), const Offset(920, 455), Paint()..strokeWidth = 12..color = const Color(0x9970462E));
      canvas.drawCircle(const Offset(155, 1480), 230, Paint()..color = const Color(0x3325140E));
      break;
    case BookStoryTemplate.cleanStudio:
      canvas.drawColor(const Color(0xFFF7F7F3), BlendMode.src);
      canvas.drawCircle(const Offset(955, 690), 250, Paint()..color = const Color(0xFFE2EEE2));
      canvas.drawCircle(const Offset(1020, 930), 135, Paint()..color = const Color(0xFFCADDC9));
      canvas.drawRect(const Rect.fromLTWH(0, 1240, 1080, 680), Paint()..color = const Color(0xFFF0F1EC));
      break;
    case BookStoryTemplate.goldArch:
      canvas.drawColor(const Color(0xFF120E0B), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.radial(
        const Offset(540, 700), 900, [const Color(0xFF49341F), const Color(0xFF0D0A08)]));
      final premiumArch = Path()
        ..moveTo(165, 1110)
        ..lineTo(165, 520)
        ..quadraticBezierTo(540, 115, 915, 520)
        ..lineTo(915, 1110);
      canvas.drawPath(premiumArch, Paint()..style = PaintingStyle.stroke..strokeWidth = 14..color = const Color(0xFFD7A947));
      canvas.drawPath(premiumArch, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFFFFE3A0));
      break;
    case BookStoryTemplate.scrapbook:
      canvas.drawColor(const Color(0xFFEAD9B9), BlendMode.src);
      for (var y = 40.0; y < 1920; y += 85) {
        canvas.drawLine(Offset(0, y), Offset(1080, y + 35), Paint()..strokeWidth = 1..color = const Color(0x22906F45));
      }
      canvas.drawRect(const Rect.fromLTWH(80, 215, 390, 420), Paint()..color = const Color(0x55FFFFFF));
      canvas.drawRect(const Rect.fromLTWH(720, 230, 230, 300), Paint()..color = const Color(0x66F8E9C7));
      canvas.drawCircle(const Offset(160, 1540), 115, Paint()..color = const Color(0x55718D5D));
      canvas.drawCircle(const Offset(920, 1460), 170, Paint()..color = const Color(0x33A56C46));
      break;
    case BookStoryTemplate.silk:
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0, 0), const Offset(1080, 1920),
        [const Color(0xFFFFF7F0), const Color(0xFFF0C9C6), const Color(0xFFD8A7B1)]));
      final silk1 = Path()
        ..moveTo(0, 360)..cubicTo(260, 250, 390, 470, 620, 360)
        ..cubicTo(820, 265, 930, 310, 1080, 210)..lineTo(1080, 0)..lineTo(0, 0)..close();
      canvas.drawPath(silk1, Paint()..color = const Color(0x55FFFFFF));
      final silk2 = Path()
        ..moveTo(0, 1460)..cubicTo(260, 1330, 470, 1570, 700, 1440)
        ..cubicTo(880, 1340, 980, 1420, 1080, 1360)..lineTo(1080, 1920)..lineTo(0, 1920)..close();
      canvas.drawPath(silk2, Paint()..color = const Color(0x449C586A));
      break;
    case BookStoryTemplate.botanical:
      canvas.drawColor(const Color(0xFFF3F0E3), BlendMode.src);
      canvas.drawCircle(const Offset(100, 260), 230, Paint()..color = const Color(0xFFD8E0C7));
      canvas.drawCircle(const Offset(1010, 1030), 300, Paint()..color = const Color(0xFFC9D6B8));
      for (final leaf in <Rect>[
        const Rect.fromLTWH(60, 150, 120, 250),
        const Rect.fromLTWH(875, 720, 125, 260),
        const Rect.fromLTWH(820, 910, 110, 230),
      ]) {
        canvas.save();
        canvas.translate(leaf.center.dx, leaf.center.dy);
        canvas.rotate(leaf.left < 500 ? -0.45 : 0.5);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: leaf.width, height: leaf.height),
          Paint()..color = const Color(0xFF6F8B62));
        canvas.drawLine(Offset(0, -leaf.height * .35), Offset(0, leaf.height * .35),
          Paint()..color = const Color(0x99F3F0E3)..strokeWidth = 3);
        canvas.restore();
      }
      break;
    case BookStoryTemplate.mosaic:
      // PAXTA — tabiiy mato va paxta shoxlari.
      canvas.drawColor(const Color(0xFFF6F0E4), BlendMode.src);
      for (final base in <Offset>[const Offset(85,300),const Offset(975,430),const Offset(105,1540),const Offset(955,1450)]) {
        canvas.drawLine(base,base+const Offset(120,-190),Paint()..strokeWidth=9..color=const Color(0xFF8B6949));
        for(final d in <Offset>[const Offset(75,-120),const Offset(120,-185),const Offset(38,-72)]){
          final p=base+d;
          canvas.drawCircle(p,42,Paint()..color=const Color(0xFFFFFEF8));
          canvas.drawCircle(p+const Offset(28,8),35,Paint()..color=const Color(0xFFFDFBF4));
          canvas.drawCircle(p+const Offset(-24,10),34,Paint()..color=const Color(0xFFFFFEF8));
        }
      }
      canvas.drawRect(const Rect.fromLTWH(42,42,996,1836),Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=const Color(0xFFB99A70));
      break;
    case BookStoryTemplate.midnight:
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.radial(
        const Offset(540, 600), 1050,
        [const Color(0xFF35305E), const Color(0xFF17152B), const Color(0xFF090A16)]));
      for (final star in <Offset>[
        const Offset(120, 210), const Offset(245, 330), const Offset(890, 190),
        const Offset(970, 420), const Offset(150, 760), const Offset(925, 920),
        const Offset(790, 120), const Offset(330, 110), const Offset(1010, 1180),
      ]) {
        canvas.drawCircle(star, 4, Paint()..color = const Color(0xFFEAD9A1));
      }
      canvas.drawArc(const Rect.fromLTWH(70, 160, 940, 940), 0.15, 2.75, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0x55D8C27A));
      break;
    case BookStoryTemplate.gallery:
      canvas.drawColor(const Color(0xFFF4F0E8), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 155), Paint()..color = const Color(0xFF202020));
      canvas.drawRect(const Rect.fromLTWH(0, 155, 270, 285), Paint()..color = const Color(0xFFC45E43));
      canvas.drawRect(const Rect.fromLTWH(810, 155, 270, 285), Paint()..color = const Color(0xFF315D5A));
      canvas.drawRect(const Rect.fromLTWH(70, 470, 940, 8), Paint()..color = const Color(0xFF202020));
      canvas.drawCircle(const Offset(920, 1010), 115, Paint()..color = const Color(0xFFE2B84E));
      break;
    case BookStoryTemplate.atlas:
      // BAHOR — och osmon va gullagan novdalar.
      canvas.drawRect(const Rect.fromLTWH(0,0,1080,1920),Paint()..shader=ui.Gradient.linear(
        const Offset(0,0),const Offset(0,1920),[const Color(0xFFDCEAF2),const Color(0xFFF7E7E8),const Color(0xFFF8F3E8)]));
      for(final pair in <List<Offset>>[[const Offset(0,250),const Offset(390,500)],[const Offset(1080,170),const Offset(720,460)],[const Offset(0,1600),const Offset(350,1400)]]){
        final a=pair[0],b=pair[1];
        canvas.drawLine(a,b,Paint()..strokeWidth=12..color=const Color(0xFF735544));
        for(var i=1;i<=5;i++){final p=Offset(a.dx+(b.dx-a.dx)*i/6,a.dy+(b.dy-a.dy)*i/6);canvas.drawCircle(p,34,Paint()..color=const Color(0xFFE7A9B2));}
      }
      break;
    case BookStoryTemplate.marble:
      // REGISTON — peshtoq, koshin ranglari va mayda rombsimon bezaklar.
      canvas.drawColor(const Color(0xFFF3E8CF), BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0, 0), const Offset(1080, 1920),
        [const Color(0xFFF6EBD4), const Color(0xFFD9ECE6), const Color(0xFFF2DFC1)]));
      final regArch = Path()
        ..moveTo(115, 1080)..lineTo(115, 420)
        ..quadraticBezierTo(540, 35, 965, 420)..lineTo(965, 1080);
      canvas.drawPath(regArch, Paint()..style = PaintingStyle.stroke..strokeWidth = 28..color = const Color(0xFF2C8C91));
      canvas.drawPath(regArch, Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = const Color(0xFFD2A846));
      for (var x = 95.0; x < 1020; x += 115) {
        final d = Path()..moveTo(x, 150)..lineTo(x + 45, 195)..lineTo(x, 240)..lineTo(x - 45, 195)..close();
        canvas.drawPath(d, Paint()..color = const Color(0xFF3E9DA0));
        canvas.drawPath(d, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFFD5A84C));
      }
      break;
    case BookStoryTemplate.cinema:
      // TUN VA SHAHAR — yarim oy va sharqona shahar silueti.
      canvas.drawRect(const Rect.fromLTWH(0,0,1080,1920),Paint()..shader=ui.Gradient.linear(
        const Offset(0,0),const Offset(0,1920),[const Color(0xFF07182C),const Color(0xFF102C48),const Color(0xFF07111D)]));
      canvas.drawCircle(const Offset(850,250),92,Paint()..color=const Color(0xFFF4E8C3));
      canvas.drawCircle(const Offset(885,225),92,Paint()..color=const Color(0xFF0B2138));
      for(final s in <Offset>[const Offset(120,180),const Offset(250,310),const Offset(480,150),const Offset(690,360),const Offset(970,410),const Offset(350,520)]) canvas.drawCircle(s,4,Paint()..color=const Color(0xFFEADAA7));
      canvas.drawRect(const Rect.fromLTWH(0,1640,1080,280),Paint()..color=const Color(0xFF03080E));
      for(final x in <double>[90,260,440,650,850,1010]){canvas.drawRect(Rect.fromLTWH(x-42,1510,84,160),Paint()..color=const Color(0xFF03080E));canvas.drawCircle(Offset(x,1510),42,Paint()..color=const Color(0xFF03080E));}
      break;
    case BookStoryTemplate.terracotta:
      // GULSHAN — pastel fon va katta akvarelga o‘xshash gul yaproqlari.
      canvas.drawColor(const Color(0xFFFFF4E9), BlendMode.src);
      for (final flower in <Offset>[const Offset(90, 270), const Offset(965, 315), const Offset(90, 1580), const Offset(970, 1500)]) {
        for (final petal in <Offset>[
          const Offset(0, -72), const Offset(66, -22), const Offset(42, 58),
          const Offset(-42, 58), const Offset(-66, -22),
        ]) {
          canvas.drawOval(Rect.fromCenter(center: flower + petal, width: 105, height: 145),
            Paint()..color = const Color(0x66D87979));
        }
        canvas.drawCircle(flower, 42, Paint()..color = const Color(0xCCCF9A3A));
      }
      canvas.drawPath(Path()..moveTo(0, 1180)..cubicTo(250, 1040, 410, 1280, 610, 1160)..cubicTo(810, 1040, 930, 1110, 1080, 1010),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 18..color = const Color(0x3374A06D));
      break;
    case BookStoryTemplate.royal:
      // KOSHIN — ko‘k-yashil sharqona geometrik naqsh va oltin markaziy ramka.
      canvas.drawColor(const Color(0xFF073F48), BlendMode.src);
      for (var y = 80.0; y < 1840; y += 220) {
        for (var x = 70.0; x < 1040; x += 220) {
          final diamond = Path()..moveTo(x, y - 55)..lineTo(x + 55, y)..lineTo(x, y + 55)..lineTo(x - 55, y)..close();
          canvas.drawPath(diamond, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0x4468C7C1));
          canvas.drawCircle(Offset(x, y), 18, Paint()..color = const Color(0x55D6B253));
        }
      }
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(120, 190, 840, 960), const Radius.circular(190)),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 9..color = const Color(0xFFD6B253));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(145, 215, 790, 910), const Radius.circular(170)),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0x99E8D89B));
      break;
    case BookStoryTemplate.ornament:
      // SADO — sokin me'moriy soyalar va minimal arka.
      canvas.drawColor(const Color(0xFFF1E7D6), BlendMode.src);
      final sadoArch=Path()..moveTo(155,1180)..lineTo(155,520)..quadraticBezierTo(540,120,925,520)..lineTo(925,1180);
      canvas.drawPath(sadoArch,Paint()..style=PaintingStyle.stroke..strokeWidth=34..color=const Color(0xFFD8C3A2));
      canvas.drawPath(sadoArch,Paint()..style=PaintingStyle.stroke..strokeWidth=3..color=const Color(0xFF9B7A51));
      canvas.drawCircle(const Offset(940,340),230,Paint()..color=const Color(0x22A47E55));
      break;
    case BookStoryTemplate.adras:
      // NAQQOSH — yog‘och o‘ymakor eshik va geometrik naqsh.
      canvas.drawRect(const Rect.fromLTWH(0,0,1080,1920),Paint()..shader=ui.Gradient.linear(
        const Offset(0,0),const Offset(1080,1920),[const Color(0xFF9B673D),const Color(0xFF5B351F),const Color(0xFF2E1B12)]));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(85,70,910,1780),const Radius.circular(220)),
        Paint()..style=PaintingStyle.stroke..strokeWidth=22..color=const Color(0xFFD2A56A));
      for(var y=160.0;y<1780;y+=170){for(var x=130.0;x<980;x+=170){final d=Path()..moveTo(x,y-38)..lineTo(x+38,y)..lineTo(x,y+38)..lineTo(x-38,y)..close();canvas.drawPath(d,Paint()..style=PaintingStyle.stroke..strokeWidth=5..color=const Color(0x88E0B87D));}}
      break;
    case BookStoryTemplate.kokand:
      // QO‘QON — ganch va saroy bezaklaridan ilhomlangan yengil gul naqshi.
      canvas.drawColor(const Color(0xFFF6E7CC), BlendMode.src);
      for (final center in <Offset>[const Offset(110, 250), const Offset(970, 250), const Offset(110, 1580), const Offset(970, 1580)]) {
        for (var i = 0; i < 8; i++) {
          final dx = 70.0 * (i == 0 || i == 4 ? 0.0 : (i < 4 ? 1.0 : -1.0));
          final dy = 70.0 * (i == 2 || i == 6 ? 0.0 : (i < 2 || i > 6 ? -1.0 : 1.0));
          canvas.drawOval(Rect.fromCenter(center: center + Offset(dx, dy), width: 58, height: 118),
            Paint()..color = const Color(0x557B9D72));
        }
        canvas.drawCircle(center, 42, Paint()..color = const Color(0xFFB66B4B));
      }
      canvas.drawRect(const Rect.fromLTWH(48, 48, 984, 1824), Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = const Color(0xFFB88A46));
      canvas.drawRect(const Rect.fromLTWH(65, 65, 950, 1790), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0x887B9D72));
      break;
    case BookStoryTemplate.khiva:
      // XIVA — Ichan-Qal'a koshinlari: turkuaz, ko‘k va qum rang.
      canvas.drawColor(const Color(0xFF0C626B), BlendMode.src);
      for (var y = 80.0; y < 1860; y += 180) {
        for (var x = 70.0; x < 1050; x += 180) {
          final star = Path()
            ..moveTo(x, y - 52)..lineTo(x + 20, y - 20)..lineTo(x + 52, y)
            ..lineTo(x + 20, y + 20)..lineTo(x, y + 52)
            ..lineTo(x - 20, y + 20)..lineTo(x - 52, y)
            ..lineTo(x - 20, y - 20)..close();
          canvas.drawPath(star, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = const Color(0x668FD2C9));
          canvas.drawCircle(Offset(x, y), 9, Paint()..color = const Color(0x99E3B85F));
        }
      }
      canvas.drawRect(const Rect.fromLTWH(80, 120, 920, 1010), Paint()..color = const Color(0x5510353A));
      canvas.drawRect(const Rect.fromLTWH(95, 135, 890, 980), Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = const Color(0xFFD9B45B));
      break;
    case BookStoryTemplate.turon:
      // TURON — qadimiy turkiy tamg‘alardan ilhomlangan kuchli geometrik kompozitsiya.
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 1920), Paint()..shader = ui.Gradient.linear(
        const Offset(0, 0), const Offset(0, 1920),
        [const Color(0xFF234E42), const Color(0xFF102E29), const Color(0xFF071B18)]));
      for (var x = 80.0; x < 1040; x += 160) {
        final tamga = Path()..moveTo(x, 115)..lineTo(x + 55, 170)..lineTo(x, 225)
          ..moveTo(x, 115)..lineTo(x - 55, 170)..lineTo(x, 225);
        canvas.drawPath(tamga, Paint()..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round..color = const Color(0x88D8B35C));
      }
      canvas.drawCircle(const Offset(540, 650), 420, Paint()..style = PaintingStyle.stroke..strokeWidth = 12..color = const Color(0x5579B9A5));
      canvas.drawCircle(const Offset(540, 650), 390, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xAAD8B35C));
      break;
    case BookStoryTemplate.yurt:
      // XATTOTLIK — siyoh, qog‘oz va kalligrafik harakat.
      canvas.drawColor(const Color(0xFFF4E9D6), BlendMode.src);
      canvas.drawPath(Path()..moveTo(80,300)..cubicTo(280,120,430,500,620,260)..cubicTo(770,80,930,220,1030,120),
        Paint()..color=const Color(0xFF231B17)..style=PaintingStyle.stroke..strokeWidth=15..strokeCap=StrokeCap.round);
      canvas.drawPath(Path()..moveTo(60,1550)..cubicTo(300,1300,520,1750,760,1450)..cubicTo(880,1320,970,1390,1060,1280),
        Paint()..color=const Color(0x55231B17)..style=PaintingStyle.stroke..strokeWidth=11);
      canvas.drawCircle(const Offset(900,1660),95,Paint()..color=const Color(0xFF8A342E));
      break;
    case BookStoryTemplate.heritage:
      // CHORSU — turkuaz gumbaz va bozor ranglari.
      canvas.drawColor(const Color(0xFFF5E5C8), BlendMode.src);
      canvas.drawCircle(const Offset(540,610),420,Paint()..color=const Color(0xFF2E8E91));
      canvas.drawCircle(const Offset(540,610),340,Paint()..color=const Color(0xFF56AAA6));
      canvas.drawRect(const Rect.fromLTWH(115,610,850,430),Paint()..color=const Color(0xFFF2D39B));
      for(var x=120.0;x<1000;x+=145) canvas.drawPath(Path()..moveTo(x,1040)..lineTo(x+70,930)..lineTo(x+140,1040)..close(),Paint()..color=const Color(0xFFB34F3F));
      canvas.drawRect(const Rect.fromLTWH(55,55,970,1810),Paint()..style=PaintingStyle.stroke..strokeWidth=4..color=const Color(0xFF7E5C32));
      break;
    case BookStoryTemplate.current:
      canvas.drawColor(cream, BlendMode.src);
      break;
  }

  final serif = template == BookStoryTemplate.classic ||
      template == BookStoryTemplate.paper ||
      template == BookStoryTemplate.polaroid ||
      template == BookStoryTemplate.editorialPage ||
      template == BookStoryTemplate.scrapbook ||
      template == BookStoryTemplate.silk ||
      template == BookStoryTemplate.botanical ||
      template == BookStoryTemplate.midnight ||
      template == BookStoryTemplate.atlas ||
      template == BookStoryTemplate.marble ||
      template == BookStoryTemplate.terracotta ||
      template == BookStoryTemplate.royal ||
      template == BookStoryTemplate.ornament ||
      template == BookStoryTemplate.adras ||
      template == BookStoryTemplate.kokand ||
      template == BookStoryTemplate.khiva ||
      template == BookStoryTemplate.turon ||
      template == BookStoryTemplate.yurt ||
      template == BookStoryTemplate.heritage;
  final mono = template == BookStoryTemplate.poster ||
      template == BookStoryTemplate.geometric ||
      template == BookStoryTemplate.collage ||
      template == BookStoryTemplate.cleanStudio ||
      template == BookStoryTemplate.gallery ||
      template == BookStoryTemplate.cinema;
  final displayFont = serif ? 'serif' : (mono ? 'monospace' : 'Roboto');
  final headerColor = template == BookStoryTemplate.poster
      ? const Color(0xFF153F48)
      : (template == BookStoryTemplate.sunset ? Colors.white : fg);
  if (template == BookStoryTemplate.split) {
    textBox('MUHAJEER', const Rect.fromLTWH(45, 72, 380, 55), 29,
        weight: FontWeight.w900, color: Colors.white, maxLines: 1, letterSpacing: 4);
    textBox('BOOKS', const Rect.fromLTWH(45, 120, 380, 55), 29,
        weight: FontWeight.w300, color: const Color(0xFFD8B56C), maxLines: 1, letterSpacing: 8);
  } else if (template == BookStoryTemplate.collage) {
    // Kollajning o‘z sarlavhasi pastroqda chiziladi. Bu yerda ikkinchi
    // MUHAJEER BOOKS sarlavhasini chizmaymiz — matnlar ustma-ust tushmaydi.
  } else if (template == BookStoryTemplate.coverFocus) {
  } else if (template == BookStoryTemplate.editorialPage) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(85, 70, 420, 48), 25,
        weight: FontWeight.w700, color: const Color(0xFF4D4234), align: TextAlign.left,
        maxLines: 1, fontFamily: 'serif', letterSpacing: 2);
  } else if (template == BookStoryTemplate.lifestyle) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(90, 70, 900, 55), 27,
        weight: FontWeight.w900, color: Colors.white, maxLines: 1, letterSpacing: 4);
  } else if (template == BookStoryTemplate.cleanStudio) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 65, 920, 55), 26,
        weight: FontWeight.w900, color: navy, maxLines: 1, letterSpacing: 3);
  } else if (template == BookStoryTemplate.goldArch) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 70, 920, 55), 26,
        weight: FontWeight.w700, color: const Color(0xFFE5C26E), maxLines: 1, letterSpacing: 5);
  } else if (template == BookStoryTemplate.scrapbook) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 65, 920, 55), 27,
        weight: FontWeight.w900, color: const Color(0xFF3C4935), maxLines: 1,
        fontFamily: 'serif', letterSpacing: 2);
  } else if (template == BookStoryTemplate.silk) {
    textBox('MUHAJEER  BOOKS', const Rect.fromLTWH(90, 66, 900, 58), 28,
        weight: FontWeight.w600, color: const Color(0xFF6B3E4A), maxLines: 1,
        fontFamily: 'serif', fontStyle: FontStyle.italic, letterSpacing: 4);
  } else if (template == BookStoryTemplate.botanical) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(95, 68, 890, 55), 27,
        weight: FontWeight.w700, color: const Color(0xFF40583C), maxLines: 1,
        fontFamily: 'serif', letterSpacing: 3);
  } else if (template == BookStoryTemplate.mosaic) {
    twoToneTextBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 68, 920, 58), 27,
      leftColor: const Color(0xFF4C3524), rightColor: const Color(0xFF8B6949),
      weight: FontWeight.w700, maxLines: 1, fontFamily: 'serif', letterSpacing: 4);
  } else if (template == BookStoryTemplate.midnight) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 68, 920, 58), 27,
        weight: FontWeight.w500, color: const Color(0xFFE8D8A2), maxLines: 1,
        fontFamily: 'serif', letterSpacing: 5);
  } else if (template == BookStoryTemplate.gallery) {
    textBox('MUHAJEER / BOOKS', const Rect.fromLTWH(70, 45, 940, 65), 31,
        weight: FontWeight.w900, color: Colors.white, maxLines: 1,
        fontFamily: 'monospace', letterSpacing: 3);
  } else if (template == BookStoryTemplate.atlas) {
    twoToneTextBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 26,
      leftColor: const Color(0xFF4E3B4A), rightColor: const Color(0xFF9A6077),
      weight: FontWeight.w700, maxLines: 1, fontFamily: 'serif', fontStyle: FontStyle.italic, letterSpacing: 4);
  } else if (template == BookStoryTemplate.marble) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 25,
        weight: FontWeight.w700, color: const Color(0xFF246E73), maxLines: 1,
        fontFamily: 'serif', letterSpacing: 3);
  } else if (template == BookStoryTemplate.cinema) {
    twoToneTextBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 25,
      leftColor: const Color(0xFFF7EED8), rightColor: const Color(0xFFE5C56D),
      weight: FontWeight.w700, maxLines: 1, fontFamily: 'serif', letterSpacing: 5);
  } else if (template == BookStoryTemplate.terracotta) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 25,
        weight: FontWeight.w700, color: const Color(0xFF7A4548), maxLines: 1,
        fontFamily: 'serif', letterSpacing: 3);
  } else if (template == BookStoryTemplate.royal) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 25,
        weight: FontWeight.w700, color: const Color(0xFFF0D58B), maxLines: 1,
        fontFamily: 'serif', letterSpacing: 5);
  } else if (template == BookStoryTemplate.ornament) {
    twoToneTextBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 24,
      leftColor: const Color(0xFF493C30), rightColor: const Color(0xFF9B7A51),
      weight: FontWeight.w600, maxLines: 1, fontFamily: 'serif', fontStyle: FontStyle.italic, letterSpacing: 3);
  } else if (template == BookStoryTemplate.noir) {
    twoToneTextBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 27,
      leftColor: const Color(0xFFF5F2EC), rightColor: const Color(0xFF171717), splitX: 700,
      weight: FontWeight.w900, maxLines: 1, fontFamily: 'monospace', letterSpacing: 3);
  } else if (template == BookStoryTemplate.adras) {
    twoToneTextBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 25,
      leftColor: const Color(0xFFFFEACB), rightColor: const Color(0xFFD2A56A),
      weight: FontWeight.w700, maxLines: 1, fontFamily: 'serif', letterSpacing: 4);
  } else if (template == BookStoryTemplate.heritage) {
    twoToneTextBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 25,
      leftColor: const Color(0xFF155B60), rightColor: const Color(0xFF9B4A36),
      weight: FontWeight.w900, maxLines: 1, fontFamily: 'monospace', letterSpacing: 3);
  } else if (template == BookStoryTemplate.yurt) {
    twoToneTextBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 25,
      leftColor: const Color(0xFF231B17), rightColor: const Color(0xFF8A342E),
      weight: FontWeight.w500, maxLines: 1, fontFamily: 'serif', fontStyle: FontStyle.italic, letterSpacing: 4);
  } else if (template == BookStoryTemplate.khiva ||
             template == BookStoryTemplate.turon) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 25,
      weight: FontWeight.w700, color: const Color(0xFFF1D18A), maxLines: 1,
      fontFamily: 'serif', letterSpacing: 4);
  } else if (template == BookStoryTemplate.kokand) {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 62, 920, 60), 25,
      weight: FontWeight.w700, color: const Color(0xFF69443B), maxLines: 1,
      fontFamily: 'serif', letterSpacing: 4);
  } else {
    textBox('MUHAJEER BOOKS', const Rect.fromLTWH(80, 70, 920, 70), 40,
        weight: template == BookStoryTemplate.classic ? FontWeight.w500 : FontWeight.w900,
        color: headerColor, maxLines: 1, fontFamily: displayFont,
        letterSpacing: template == BookStoryTemplate.magazine ? 7 : (serif ? 3 : 0));
  }

  // Oldindan sotuvdagi kitob Storysi ekanini bir qarashda ko‘rsatamiz.
  // Barcha dizaynlarda yuqori qismda bir xil, aniq banner chiqadi.
  if (book.preorderEnabled) {
    rounded(
      const Rect.fromLTWH(190, 112, 700, 46),
      const Color(0xEE0A6F66),
      radius: 23,
      stroke: const Color(0x55FFFFFF),
    );
    textBox(
      'OLDINDAN BUYURTMA YIG‘YAPMIZ',
      const Rect.fromLTWH(215, 120, 650, 28),
      20,
      weight: FontWeight.w900,
      color: Colors.white,
      maxLines: 1,
      letterSpacing: 1.2,
    );
  }

  Rect coverFrame;
  Rect coverRect;
  if (template == BookStoryTemplate.library) {
    textBox(book.title, const Rect.fromLTWH(120, 205, 840, 160), 58, weight: FontWeight.w900, color: Colors.white);
    coverFrame = const Rect.fromLTWH(315, 390, 450, 650);
    coverRect = const Rect.fromLTWH(340, 415, 400, 600);
  } else if (template == BookStoryTemplate.arch) {
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
    twoToneTextBox(book.title, const Rect.fromLTWH(120, 205, 840, 140), 56,
      leftColor: const Color(0xFFF5F2EC), rightColor: const Color(0xFF171717), splitX: 665,
      weight: FontWeight.w700, fontFamily: 'monospace', letterSpacing: 1.5);
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
    textBox(book.title, const Rect.fromLTWH(130, 1010, 820, 145), 55, weight: FontWeight.w600,
      color: const Color(0xFF304B38), fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(255, 300, 570, 700);
    coverRect = const Rect.fromLTWH(290, 335, 500, 590);
  } else if (template == BookStoryTemplate.collage) {
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
  } else if (template == BookStoryTemplate.editorialPage) {
    textBox(book.title, const Rect.fromLTWH(85, 175, 560, 260), 68,
      weight: FontWeight.w500, color: const Color(0xFF2D2922), align: TextAlign.left,
      maxLines: 3, fontFamily: 'serif');
    if (book.author.trim().isNotEmpty && book.author != 'Ko‘rsatilmagan') {
      textBox(book.author, const Rect.fromLTWH(85, 445, 500, 46), 22,
        color: const Color(0xFF6D5B43), align: TextAlign.left, maxLines: 1,
        fontFamily: 'serif', fontStyle: FontStyle.italic);
    }
    textBox(storyPrice(book), const Rect.fromLTWH(85, 545, 330, 70), 43,
      weight: FontWeight.w700, color: const Color(0xFF2F5B52), align: TextAlign.left,
      maxLines: 1, fontFamily: 'serif');
    coverFrame = const Rect.fromLTWH(500, 540, 470, 590);
    coverRect = const Rect.fromLTWH(525, 565, 420, 540);
  } else if (template == BookStoryTemplate.lifestyle) {
    coverFrame = const Rect.fromLTWH(315, 535, 450, 575);
    coverRect = const Rect.fromLTWH(340, 560, 400, 525);
    textBox(book.title, const Rect.fromLTWH(120, 1115, 840, 90), 39,
      weight: FontWeight.w700, color: Colors.white, maxLines: 2, fontFamily: 'serif');
    if (book.author.trim().isNotEmpty && book.author != 'Ko‘rsatilmagan') {
      textBox(book.author.trim(), const Rect.fromLTWH(160, 1205, 760, 36), 20,
        color: const Color(0xFFE8DED5), maxLines: 1, fontFamily: 'serif',
        fontStyle: FontStyle.italic);
    }
  } else if (template == BookStoryTemplate.cleanStudio) {
    textBox('“', const Rect.fromLTWH(70, 155, 130, 110), 100,
      weight: FontWeight.w900, color: const Color(0xFFD6D9D3), align: TextAlign.left,
      maxLines: 1, fontFamily: 'serif');
    textBox(book.title, const Rect.fromLTWH(145, 195, 790, 195), 63,
      weight: FontWeight.w900, color: navy, align: TextAlign.left, maxLines: 3);
    if (book.author.trim().isNotEmpty && book.author != 'Ko‘rsatilmagan') {
      textBox(book.author, const Rect.fromLTWH(150, 400, 520, 42), 22,
        color: muted, align: TextAlign.left, maxLines: 1);
    }
    coverFrame = const Rect.fromLTWH(285, 490, 510, 610);
    coverRect = const Rect.fromLTWH(315, 520, 450, 550);
  } else if (template == BookStoryTemplate.goldArch) {
    coverFrame = const Rect.fromLTWH(330, 455, 420, 570);
    coverRect = const Rect.fromLTWH(355, 480, 370, 520);
    textBox(book.title, const Rect.fromLTWH(120, 1050, 840, 110), 44,
      weight: FontWeight.w500, color: const Color(0xFFF4E8CE), maxLines: 2,
      fontFamily: 'serif');
    textBox(storyPrice(book), const Rect.fromLTWH(200, 1160, 680, 65), 39,
      weight: FontWeight.w800, color: const Color(0xFFE5B84F), maxLines: 1);
  } else if (template == BookStoryTemplate.scrapbook) {
    coverFrame = const Rect.fromLTWH(190, 430, 610, 590);
    coverRect = const Rect.fromLTWH(225, 465, 540, 520);
    textBox(book.title, const Rect.fromLTWH(180, 1035, 720, 95), 38,
      weight: FontWeight.w600, color: const Color(0xFF4B3B2A), maxLines: 2,
      fontFamily: 'serif', fontStyle: FontStyle.italic);
    textBox(storyPrice(book), const Rect.fromLTWH(700, 1135, 280, 65), 35,
      weight: FontWeight.w900, color: const Color(0xFF126653), maxLines: 1);
  } else if (template == BookStoryTemplate.silk) {
    textBox(book.title, const Rect.fromLTWH(110, 165, 860, 150), 56,
      weight: FontWeight.w600, color: const Color(0xFF56333D), maxLines: 2,
      fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(260, 335, 560, 735);
    coverRect = const Rect.fromLTWH(292, 367, 496, 671);
  } else if (template == BookStoryTemplate.botanical) {
    textBox(book.title, const Rect.fromLTWH(145, 175, 790, 145), 54,
      weight: FontWeight.w600, color: const Color(0xFF354A33), maxLines: 2,
      fontFamily: 'serif');
    coverFrame = const Rect.fromLTWH(285, 345, 510, 715);
    coverRect = const Rect.fromLTWH(315, 375, 450, 655);
  } else if (template == BookStoryTemplate.mosaic) {
    twoToneTextBox(book.title, const Rect.fromLTWH(120, 165, 840, 155), 55,
      leftColor: const Color(0xFF4C3524), rightColor: const Color(0xFF8B6949),
      weight: FontWeight.w700, maxLines: 2, fontFamily: 'serif');
    coverFrame = const Rect.fromLTWH(285, 345, 510, 720);
    coverRect = const Rect.fromLTWH(315, 375, 450, 660);
  } else if (template == BookStoryTemplate.midnight) {
    textBox(book.title, const Rect.fromLTWH(120, 210, 840, 130), 52,
      weight: FontWeight.w500, color: const Color(0xFFF7F0DE), maxLines: 2,
      fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(300, 365, 480, 700);
    coverRect = const Rect.fromLTWH(328, 393, 424, 644);
  } else if (template == BookStoryTemplate.gallery) {
    textBox(book.title.toUpperCase(), const Rect.fromLTWH(70, 235, 940, 130), 51,
      weight: FontWeight.w900, color: const Color(0xFF202020), align: TextAlign.left,
      maxLines: 2, fontFamily: 'monospace', letterSpacing: -0.5);
    coverFrame = const Rect.fromLTWH(245, 500, 590, 565);
    coverRect = const Rect.fromLTWH(275, 530, 530, 505);
  } else if (template == BookStoryTemplate.atlas) {
    // Dekor kuchli bo‘lsa ham kitob nomi har doim aniq o‘qiladi.
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xDD351020), radius: 30,
      stroke: const Color(0x77E3C46D));
    twoToneTextBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52,
      leftColor: const Color(0xFF4E3B4A), rightColor: const Color(0xFF9A6077),
      weight: FontWeight.w700, maxLines: 2, fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(290, 370, 500, 690);
    coverRect = const Rect.fromLTWH(320, 400, 440, 630);
  } else if (template == BookStoryTemplate.marble) {
    // Dekor kuchli bo‘lsa ham kitob nomi har doim aniq o‘qiladi.
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xF2FFFFFF), radius: 30,
      stroke: const Color(0x33246E73));
    textBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52,
      weight: FontWeight.w700, color: const Color(0xFF244F53), maxLines: 2,
      fontFamily: 'serif', fontStyle: FontStyle.normal);
    coverFrame = const Rect.fromLTWH(290, 370, 500, 690);
    coverRect = const Rect.fromLTWH(320, 400, 440, 630);
  } else if (template == BookStoryTemplate.cinema) {
    // Dekor kuchli bo‘lsa ham kitob nomi har doim aniq o‘qiladi.
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xE618130D), radius: 30,
      stroke: const Color(0x77E3C46D));
    twoToneTextBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52,
      leftColor: const Color(0xFFF7EED8), rightColor: const Color(0xFFE5C56D),
      weight: FontWeight.w700, maxLines: 2, fontFamily: 'serif');
    coverFrame = const Rect.fromLTWH(295, 370, 490, 690);
    coverRect = const Rect.fromLTWH(325, 400, 430, 630);
  } else if (template == BookStoryTemplate.terracotta) {
    // Dekor kuchli bo‘lsa ham kitob nomi har doim aniq o‘qiladi.
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xF2FFFFFF), radius: 30,
      stroke: const Color(0x339A5B5D));
    textBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52,
      weight: FontWeight.w700, color: const Color(0xFF673D40), maxLines: 2,
      fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(290, 370, 500, 690);
    coverRect = const Rect.fromLTWH(320, 400, 440, 630);
  } else if (template == BookStoryTemplate.royal) {
    // Dekor kuchli bo‘lsa ham kitob nomi har doim aniq o‘qiladi.
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xE607343B), radius: 30,
      stroke: const Color(0x77E1C56F));
    textBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52,
      weight: FontWeight.w700, color: const Color(0xFFFFF4D1), maxLines: 2,
      fontFamily: 'serif', fontStyle: FontStyle.normal);
    coverFrame = const Rect.fromLTWH(300, 370, 480, 695);
    coverRect = const Rect.fromLTWH(328, 398, 424, 639);
  } else if (template == BookStoryTemplate.ornament) {
    // Dekor kuchli bo‘lsa ham kitob nomi har doim aniq o‘qiladi.
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xF2FFFFFF), radius: 30,
      stroke: const Color(0x442B7777));
    twoToneTextBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52,
      leftColor: const Color(0xFF493C30), rightColor: const Color(0xFF9B7A51),
      weight: FontWeight.w500, maxLines: 2, fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(300, 370, 480, 695);
    coverRect = const Rect.fromLTWH(328, 398, 424, 639);
  } else if (template == BookStoryTemplate.adras) {
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xE6311022), radius: 30, stroke: const Color(0x88E3C56D));
    twoToneTextBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52,
      leftColor: const Color(0xFFFFEACB), rightColor: const Color(0xFFD2A56A),
      weight: FontWeight.w700, maxLines: 2, fontFamily: 'serif');
    coverFrame = const Rect.fromLTWH(290, 370, 500, 690);
    coverRect = const Rect.fromLTWH(320, 400, 440, 630);
  } else if (template == BookStoryTemplate.kokand) {
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xF4FFF9EE), radius: 30, stroke: const Color(0x558B6840));
    textBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52, weight: FontWeight.w700,
      color: const Color(0xFF68453A), maxLines: 2, fontFamily: 'serif');
    coverFrame = const Rect.fromLTWH(290, 370, 500, 690);
    coverRect = const Rect.fromLTWH(320, 400, 440, 630);
  } else if (template == BookStoryTemplate.khiva) {
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xE60B3940), radius: 30, stroke: const Color(0x88E0BA61));
    textBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52, weight: FontWeight.w700,
      color: const Color(0xFFFFF2D0), maxLines: 2, fontFamily: 'serif');
    coverFrame = const Rect.fromLTWH(290, 370, 500, 690);
    coverRect = const Rect.fromLTWH(320, 400, 440, 630);
  } else if (template == BookStoryTemplate.turon) {
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xE60B2823), radius: 30, stroke: const Color(0x88D8B35C));
    textBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52, weight: FontWeight.w700,
      color: const Color(0xFFFFF1CF), maxLines: 2, fontFamily: 'serif');
    coverFrame = const Rect.fromLTWH(300, 370, 480, 695);
    coverRect = const Rect.fromLTWH(328, 398, 424, 639);
  } else if (template == BookStoryTemplate.yurt) {
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xF5FFF9ED), radius: 30, stroke: const Color(0x558E3E35));
    twoToneTextBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52,
      leftColor: const Color(0xFF231B17), rightColor: const Color(0xFF8A342E),
      weight: FontWeight.w500, maxLines: 2, fontFamily: 'serif', fontStyle: FontStyle.italic);
    coverFrame = const Rect.fromLTWH(290, 370, 500, 690);
    coverRect = const Rect.fromLTWH(320, 400, 440, 630);
  } else if (template == BookStoryTemplate.heritage) {
    rounded(const Rect.fromLTWH(105, 160, 870, 175), const Color(0xE63B1D18), radius: 30, stroke: const Color(0x88DBB15A));
    twoToneTextBox(book.title, const Rect.fromLTWH(135, 182, 810, 130), 52,
      leftColor: const Color(0xFF155B60), rightColor: const Color(0xFF9B4A36),
      weight: FontWeight.w900, maxLines: 2, fontFamily: 'monospace', letterSpacing: 0.5);
    coverFrame = const Rect.fromLTWH(300, 370, 480, 695);
    coverRect = const Rect.fromLTWH(328, 398, 424, 639);
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
      ? 1350.0
      : ((template == BookStoryTemplate.editorialPage ||
              template == BookStoryTemplate.lifestyle ||
              template == BookStoryTemplate.cleanStudio ||
              template == BookStoryTemplate.goldArch ||
              template == BookStoryTemplate.scrapbook ||
              template == BookStoryTemplate.silk ||
              template == BookStoryTemplate.botanical ||
              template == BookStoryTemplate.mosaic ||
              template == BookStoryTemplate.midnight ||
              template == BookStoryTemplate.gallery ||
              template == BookStoryTemplate.atlas ||
              template == BookStoryTemplate.marble ||
              template == BookStoryTemplate.cinema ||
              template == BookStoryTemplate.terracotta ||
              template == BookStoryTemplate.royal ||
              template == BookStoryTemplate.ornament ||
              template == BookStoryTemplate.adras ||
              template == BookStoryTemplate.kokand ||
              template == BookStoryTemplate.khiva ||
              template == BookStoryTemplate.turon ||
              template == BookStoryTemplate.yurt ||
              template == BookStoryTemplate.heritage)
          ? 1245.0
          : (template == BookStoryTemplate.polaroid
              ? 1180.0
              : ((template == BookStoryTemplate.emerald ||
                      template == BookStoryTemplate.sunset)
                  ? 1140.0
                  : 1080.0)));
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
      template == BookStoryTemplate.coverFocus ||
      template == BookStoryTemplate.editorialPage ||
      template == BookStoryTemplate.lifestyle ||
      template == BookStoryTemplate.cleanStudio ||
      template == BookStoryTemplate.goldArch ||
      template == BookStoryTemplate.scrapbook ||
      template == BookStoryTemplate.silk ||
      template == BookStoryTemplate.botanical ||
      template == BookStoryTemplate.mosaic ||
      template == BookStoryTemplate.midnight ||
      template == BookStoryTemplate.gallery ||
      template == BookStoryTemplate.atlas ||
      template == BookStoryTemplate.marble ||
      template == BookStoryTemplate.cinema ||
      template == BookStoryTemplate.terracotta ||
      template == BookStoryTemplate.royal ||
      template == BookStoryTemplate.ornament ||
      template == BookStoryTemplate.adras ||
      template == BookStoryTemplate.kokand ||
      template == BookStoryTemplate.khiva ||
      template == BookStoryTemplate.turon ||
      template == BookStoryTemplate.yurt ||
      template == BookStoryTemplate.heritage;
  if (!titleAlreadyShown) {
    textBox(book.title, Rect.fromLTWH(90, infoTop, 900, 90), 45, weight: FontWeight.w900, color: fg);
    infoTop += 84;
  }
  if (book.author.trim().isNotEmpty &&
      book.author != 'Ko‘rsatilmagan' &&
      template != BookStoryTemplate.minimal &&
      template != BookStoryTemplate.split &&
      template != BookStoryTemplate.editorialPage &&
      template != BookStoryTemplate.lifestyle &&
      template != BookStoryTemplate.cleanStudio) {
    textBox(book.author.trim(), Rect.fromLTWH(120, infoTop, 840, 42), 22, color: dark ? const Color(0xFFE5DED4) : muted, maxLines: 1);
    infoTop += 45;
  }

  const cardBg = Color(0xFFFDFBF6);
  const cardStroke = Color(0xFFD8D0C2);
  const cardText = Color(0xFF123F49);
  const gap = 18.0;
  const cardW = 275.0;
  final left = (1080 - (cardW * 3 + gap * 2)) / 2;
  for (var i = 0; i < 3; i++) {
    rounded(Rect.fromLTWH(left + i * (cardW + gap), infoTop + 18, cardW, 112), cardBg, radius: 22, stroke: cardStroke);
  }
  textBox(storyPrice(book), Rect.fromLTWH(left + 10, infoTop + 32, cardW - 20, 80), 31, weight: FontWeight.w900, color: teal, maxLines: 1);
  textBox('Yetkazib berish:\n₩4,000', Rect.fromLTWH(left + cardW + gap + 10, infoTop + 28, cardW - 20, 88), 22, weight: FontWeight.w800, color: cardText);
  textBox(book.stock > 0 ? 'Omborda:\n${book.stock} dona' : 'Hozircha\nmavjud emas',
      Rect.fromLTWH(left + (cardW + gap) * 2 + 10, infoTop + 28, cardW - 20, 88), 22, weight: FontWeight.w800,
      color: book.stock > 0 ? const Color(0xFF187A55) : const Color(0xFFB53B3B));

  final description = _storyDescription(book);
  final descriptionOnDark = dark ||
      template == BookStoryTemplate.sunset ||
      template == BookStoryTemplate.poster ||
      template == BookStoryTemplate.collage ||
      template == BookStoryTemplate.lifestyle ||
      template == BookStoryTemplate.goldArch ||
      template == BookStoryTemplate.mosaic ||
      template == BookStoryTemplate.midnight ||
      template == BookStoryTemplate.atlas ||
      template == BookStoryTemplate.cinema ||
      template == BookStoryTemplate.royal ||
      template == BookStoryTemplate.adras ||
      template == BookStoryTemplate.khiva ||
      template == BookStoryTemplate.turon ||
      template == BookStoryTemplate.heritage;
  final descriptionRect = Rect.fromLTWH(90, infoTop + 150, 900, 200);
  final descriptionBg = descriptionOnDark
      ? const Color(0xCC102F36)
      : const Color(0xEFFFFFFF);
  final descriptionStroke = descriptionOnDark
      ? const Color(0x44FFFFFF)
      : const Color(0x22000000);
  final descriptionText = descriptionOnDark
      ? const Color(0xFFF8F3EA)
      : navy;
  rounded(descriptionRect, descriptionBg, radius: 24, stroke: descriptionStroke);
  textBox(
    description,
    Rect.fromLTWH(
      descriptionRect.left + 24,
      descriptionRect.top + 18,
      descriptionRect.width - 48,
      descriptionRect.height - 36,
    ),
    22,
    color: descriptionText,
    maxLines: 5,
  );

  final buttonY = infoTop + 370;
  final ctaOnDark = descriptionOnDark || template == BookStoryTemplate.coverFocus;
  final ctaBg = ctaOnDark ? const Color(0xFFF1E4CC) : teal;
  final ctaText = ctaOnDark ? const Color(0xFF2C1A10) : Colors.white;
  rounded(Rect.fromLTWH(170, buttonY, 740, 76), ctaBg, radius: 38);
  textBox(book.inStock ? 'Buyurtma berish uchun bosing  →' : 'Kitob haqida batafsil  →',
      Rect.fromLTWH(195, buttonY + 8, 690, 60), 27, weight: FontWeight.w900,
      color: ctaText, maxLines: 1);
  // Footer CTA bilan hech qachon ustma-ust tushmasin. Handle Storyning
  // eng pastidagi alohida footer zonasida turadi.
  textBox('@muhajeerbooks', const Rect.fromLTWH(100, 1860, 880, 34), 20,
      color: descriptionOnDark ? const Color(0xFFE7DDD1) : muted, maxLines: 1);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (1080 * safeScale).round(),
    (1920 * safeScale).round(),
  );
  picture.dispose();
  final png = await _exportStoryPng(image);
  image.dispose();
  cover.dispose();
  return png;
}