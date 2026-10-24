import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'admin_session.dart';
import 'owner_story_access.dart';
import 'app_state.dart';
import 'book_links.dart';
import 'book_story_image.dart';
import 'book_post_image.dart';
import 'catalog_resume.dart';

class BookStoryPage extends StatefulWidget {
  const BookStoryPage({super.key, required this.book});
  final Book book;
  @override
  State<BookStoryPage> createState() => _BookStoryPageState();
}

class _BookStoryPageState extends State<BookStoryPage> {
  late Future<Uint8List> _image;
  bool _sharing = false;
  bool _copied = false;
  BookStoryTemplate _template = BookStoryTemplate.current;
  late final List<String> _descriptionPages;
  int _descriptionPage = 0;

  // True full-frame PNG thumbnails. Render one at a time at quarter
  // resolution so several thumbnails cannot exhaust mobile GPU memory.
  final Map<BookStoryTemplate, Future<Uint8List>> _previewImages = {};
  Future<void> _previewRenderQueue = Future<void>.value();
  late final Future<Uint8List?> _previewCover;

  Future<Uint8List> _previewImageFor(BookStoryTemplate design) {
    return _previewImages.putIfAbsent(design, () {
      final result = Completer<Uint8List>();
      _previewRenderQueue = _previewRenderQueue.then((_) async {
        if (!mounted) {
          result.complete(Uint8List(0));
          return;
        }
        try {
          final cover = await _previewCover;
          final bytes = await renderBookStory(widget.book,
              coverBytes: cover, template: design,
              renderScale: 0.25, previewOnly: true);
          result.complete(bytes);
        } catch (error, stack) {
          result.completeError(error, stack);
        }
      });
      return result.future;
    });
  }

  int get _pageCount => bookStorySupportsDescriptionPages(_template)
      ? _descriptionPages.length : 1;

  String _filenameForPage(int page) {
    final suffix = _pageCount > 1 ? '-${page + 1}-of-$_pageCount' : '';
    return 'muhajeer-${widget.book.id}-${bookStoryTemplateName(_template).toLowerCase()}$suffix-story.png';
  }


  static const _templatePreferenceKey = 'book_story_template_v1';

  // Eng yangi dizaynlar tepada ko‘rinsin — foydalanuvchi ularni qidirib
  // pastga tushmasin. Qolganlari avvalgi tartibda saqlanadi.
  static const List<BookStoryTemplate> _templateOrder = [
    // Yangi o‘nta uslubni birinchi ko‘rsatamiz.
    BookStoryTemplate.novaEditorial,
    BookStoryTemplate.velvetRose,
    BookStoryTemplate.auroraInk,
    BookStoryTemplate.hanokPaper,
    BookStoryTemplate.serifLuxe,
    BookStoryTemplate.neonNight,
    BookStoryTemplate.galleryLine,
    BookStoryTemplate.goldenOrbit,
    BookStoryTemplate.pearlEdition,    // Marvarid, ipak va nozik chiziqlar
    BookStoryTemplate.quickPrice,       // Faqat muqova, narx va odatiy pochta narxi
    BookStoryTemplate.cleanEdition,    // Oq va toza
    BookStoryTemplate.premiumEdition,  // To‘q yashil va oltin
    BookStoryTemplate.saleEdition,     // Sotuv uchun yorqin
    // Muqova ranglarini o‘zi tahlil qilib, fon/yozuv/aksentlarni moslaydi.
    BookStoryTemplate.current,    // Avto dizayn — yangi kompozitsiyani o‘zi yaratadi
    BookStoryTemplate.smartMatch, // Mos dizayn — mavjud dizaynlardan muqovaga mosini tanlaydi
    BookStoryTemplate.spring,
    BookStoryTemplate.summer,
    BookStoryTemplate.autumn,
    BookStoryTemplate.winter,
    BookStoryTemplate.noir,       // Zamonaviy
    BookStoryTemplate.terracotta,
    BookStoryTemplate.botanical,
    BookStoryTemplate.cleanStudio,
    BookStoryTemplate.goldArch,
    BookStoryTemplate.arch,
    BookStoryTemplate.split,
    BookStoryTemplate.polaroid,
  ];

  Future<Uint8List> _renderStoryWithRecovery(BookStoryTemplate template, {int page = 0}) async {
    try {
      return await renderBookStory(widget.book, template: template,
          descriptionPage: page, adminCode: AdminSession.code);
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      try {
        return await renderBookStory(
          widget.book,
          template: template,
          descriptionPage: page,
          renderScale: 2 / 3,
          adminCode: AdminSession.code,
        );
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        try {
          return await renderBookStory(
            widget.book,
            template: template,
            descriptionPage: page,
            renderScale: 0.5,
            adminCode: AdminSession.code,
          );
        } catch (_) {
          // CanvasKit/GPU uchala urinishda ham yiqilsa, Safari'ga bog‘liq
          // bo‘lmagan sof CPU raster yo‘li. Endi sahifa xato bilan tugamaydi.
          if (page > 0) rethrow; // Never substitute a blank copy slide.
          return renderBookStoryCpuFallback(
            widget.book,
            template: template,
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Keep the catalogue intact while this Story route or an external
    // Instagram share sheet is open, including long background sessions.
    CatalogResume.instance.beginStoryFlow();
    _descriptionPages = bookStoryDescriptionPages(widget.book);
    _previewCover = loadBookStoryCover(widget.book);
    _image = _renderStoryWithRecovery(_template);
    _restoreTemplate();
  }

  @override
  void dispose() {
    CatalogResume.instance.endStoryFlow();
    super.dispose();
  }

  Future<void> _restoreTemplate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_templatePreferenceKey);
      if (saved == null) return;
      BookStoryTemplate? restored;
      for (final value in BookStoryTemplate.values) {
        if (value.name == saved) {
          restored = value;
          break;
        }
      }
      if (restored == null ||
          !_templateOrder.contains(restored) ||
          !mounted ||
          restored == _template) {
        return;
      }
      final restoredTemplate = restored;
      setState(() {
        _template = restoredTemplate;
        _descriptionPage = 0;
        _image = _renderStoryWithRecovery(restoredTemplate);
      });
    } catch (_) {
      // Saqlangan tanlov o‘qilmasa hozirgi dizayn bilan davom etamiz.
    }
  }

  String get _filename => _filenameForPage(_descriptionPage);

  void _selectDescriptionPage(int page) {
    if (page < 0 || page >= _pageCount || page == _descriptionPage) return;
    setState(() {
      _descriptionPage = page;
      _image = _renderStoryWithRecovery(_template, page: page);
    });
  }

  Future<void> _selectTemplate(BookStoryTemplate template) async {
    if (_template == template) return;
    setState(() {
      _template = template;
      _descriptionPage = 0;
      _image = _renderStoryWithRecovery(template);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_templatePreferenceKey, template.name);
    } catch (_) {
      // Story ishlashiga xalaqit bermaydi.
    }
  }

  bool get _mayCreateStory =>
      OwnerStoryAccess.instance.allowedFor(context.read<AppState>());

  Future<void> _copyLink() async {
    if (!_mayCreateStory) return;
    final link = bookShareLink(widget.book.id).toString();
    try {
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) setState(() => _copied = true);
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => AlertDialog(
        title: const Text('Kitob havolasi'), content: SelectableText(link),
      ));
    }
  }

  Future<void> _share(Uint8List bytes, BuildContext buttonContext,
      {bool allPages = false}) async {
    if (_sharing || !_mayCreateStory) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    setState(() => _sharing = true);
    try {
      // Only the PNG: Instagram may discard image + URL payloads. The exact
      // book URL is copied separately for its tappable Link sticker.
      final pageNumbers = allPages
          ? List<int>.generate(_pageCount, (i) => i)
          : <int>[_descriptionPage];
      final files = <XFile>[];
      final names = <String>[];
      for (final page in pageNumbers) {
        final png = page == _descriptionPage
            ? bytes : await _renderStoryWithRecovery(_template, page: page);
        files.add(XFile.fromData(png, mimeType: 'image/png'));
        names.add(_filenameForPage(page));
      }
      await SharePlus.instance.share(ShareParams(
        files: files,
        fileNameOverrides: names,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(kIsWeb
            ? 'Ulashish ochilmadi. “Rasmni yuklab olish” tugmasidan foydalaning.'
            : 'Ulashish ochilmadi. Qayta urinib ko‘ring.'),
      ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _saveInstagramPost(BuildContext buttonContext) async {
    if (_sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    setState(() => _sharing = true);
    try {
      // Dedicated edge-to-edge 4:5 composition; never shrink a full Story.
      final postPng = await renderBookInstagramPost(
        widget.book,
        template: _template,
        description: _descriptionPages[_descriptionPage],
      );
      final postFilename = _filename.replaceFirst(
        '-story.png',
        '-post-1080x1350.png',
      );
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(postPng, mimeType: 'image/png')],
        fileNameOverrides: [postFilename],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Instagram posti 1080×1350 tayyor. Telefoningizga saqlash uchun “Save Image / Rasmni saqlash”ni tanlang.',
          ),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Post rasmini saqlab bo‘lmadi. Qayta urinib ko‘ring.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!OwnerStoryAccess.instance.allowedFor(state)) {
      return const Scaffold(
        body: Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Instagram story dizaynlari faqat do‘kon egasi uchun. Profil ma’lumotlarini tekshirib, admin sifatida kiring.'),
        )),
      );
    }
    return Scaffold(
    appBar: AppBar(title: const Text('Instagram story')),
    body: SafeArea(child: FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Story rasmini tayyorlashda xatolik bo‘ldi. Qayta urinib ko‘ring.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => setState(() {
              _image = _renderStoryWithRecovery(_template);
            }), child: const Text('Qayta urinish')),
          ]),
        ));
        final bytes = snapshot.data;
        if (bytes == null) return const Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Story rasmi tayyorlanmoqda…')],
        ));
        return ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [
            const Expanded(child: Text('Dizaynni tanlang',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            Text('${_templateOrder.length} ta uslub',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              // The frame keeps the 9:16 story *uncropped* even in tiny
              // thumbnails; more options fit without endless scrolling.
              const gap = 3.0;
              final columns = constraints.maxWidth >= 840 ? 12
                  : constraints.maxWidth >= 520 ? 10
                  : constraints.maxWidth >= 350 ? 8 : 7;
              final itemWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              final itemHeight = itemWidth * 16 / 9 + 17;
              return Wrap(
                spacing: gap,
                runSpacing: 4,
                children: _templateOrder.map((item) {
                  final selected = item == _template;
                  return Semantics(
                    button: true,
                    label: '${bookStoryTemplateName(item)} dizaynini tanlash',
                    selected: selected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(5),
                      onTap: () => _selectTemplate(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 170),
                        width: itemWidth,
                        height: itemHeight,
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF08786E)
                                : const Color(0x33000000),
                            width: selected ? 2 : .6,
                          ),
                        ),
                        child: Column(children: [
                          Expanded(child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Stack(fit: StackFit.expand, children: [
                              ColoredBox(color: bookStoryTemplateColor(item)),
                              if (selected)
                                Image.memory(bytes,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.low,
                                  semanticLabel:
                                      '${bookStoryTemplateName(item)} tanlangan Story rasmi')
                              else FutureBuilder<Uint8List>(
                                future: _previewImageFor(item),
                                builder: (context, preview) {
                                  final previewBytes = preview.data;
                                  if (previewBytes != null &&
                                      previewBytes.isNotEmpty) {
                                    return Image.memory(previewBytes,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.low,
                                      semanticLabel:
                                          '${bookStoryTemplateName(item)} to‘liq Story ko‘rinishi');
                                  }
                                  if (preview.hasError) {
                                    return const Icon(Icons.image_not_supported_outlined,
                                        size: 12);
                                  }
                                  return const Center(child: SizedBox(
                                    width: 9, height: 9,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.1),
                                  ));
                                },
                              ),
                              if (selected)
                                const Positioned(top: 0, right: 0,
                                  child: Icon(Icons.check_circle,
                                    size: 12, color: Color(0xFF08786E))),
                            ]),
                          )),
                          SizedBox(height: 15, child: Center(child: Text(
                            bookStoryTemplateName(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ))),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ClipRRect(borderRadius: BorderRadius.circular(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOut,
                child: AspectRatio(
                  key: ValueKey('${_template.name}-$_descriptionPage'),
                  aspectRatio: 9 / 16,
                  child: Image.memory(bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    semanticLabel: '${widget.book.title}, ${storyPrice(widget.book)} — story rasmi'),
                ),
              )),
          )),
          if (_pageCount > 1) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                tooltip: 'Oldingi story sahifasi',
                onPressed: _descriptionPage > 0
                    ? () => _selectDescriptionPage(_descriptionPage - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('Tavsif: ${_descriptionPage + 1}/$_pageCount',
                style: const TextStyle(fontWeight: FontWeight.w900)),
              IconButton(
                tooltip: 'Keyingi story sahifasi',
                onPressed: _descriptionPage + 1 < _pageCount
                    ? () => _selectDescriptionPage(_descriptionPage + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ]),
            const Text('Tavsif to‘liq chiqishi uchun barcha sahifalarni ketma-ket storyga joylang.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 20),
          const Text('Story ustiga bosilganda kitob ochilishi uchun:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Havolani nusxalang, rasmni Instagram storyga qo‘ying. Keyin Stikerlar → Link orqali havolani joylang. Stiker matni: “Buyurtma berish uchun bosing”. Uni rasmdagi o‘q ostiga qo‘ying.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _copyLink,
            icon: Icon(_copied ? Icons.check : Icons.link),
            label: Text(_copied ? 'Havola nusxalandi' : '1. Kitob havolasini nusxalash')),
          const SizedBox(height: 10),
          Builder(builder: (buttonContext) => FilledButton.icon(
            onPressed: _sharing ? null : () => _share(bytes, buttonContext),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('2. Storyga ulashish'),
          )),
          if (_pageCount > 1) ...[
            const SizedBox(height: 8),
            Builder(builder: (buttonContext) => OutlinedButton.icon(
              onPressed: _sharing ? null : () => _share(bytes, buttonContext, allPages: true),
              icon: const Icon(Icons.collections_rounded),
              label: Text('Barcha $_pageCount ta storyni ulashish'),
            )),
          ],
          const SizedBox(height: 8),
          Builder(builder: (buttonContext) => OutlinedButton.icon(
            onPressed: _sharing ? null : () async {
              if (kIsWeb) {
                try {
                  await XFile.fromData(bytes, mimeType: 'image/png', name: _filename).saveTo(_filename);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Story rasmi saqlandi ✅')));
                } catch (_) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saqlash ochilmadi. “Storyga ulashish”dan foydalaning.')));
                }
              } else {
                await _share(bytes, buttonContext);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rasmni saqlash uchun ulashish oynasidan “Save Image / Rasmni saqlash”ni tanlang.')));
              }
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Rasmni saqlash'),
          )),
          // For now, feed-post export is deliberately an iOS-only feature.
          // The shared Flutter code must not change Android or web UI.
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
            const SizedBox(height: 8),
            Builder(builder: (buttonContext) => OutlinedButton.icon(
              onPressed: _sharing
                  ? null
                  : () => _saveInstagramPost(buttonContext),
              icon: const Icon(Icons.crop_portrait_rounded),
              label: const Text('Post uchun saqlash'),
            )),
          ],
          const SizedBox(height: 8),
          const Text('Instagram ulashish ro‘yxatida chiqmasa, rasmni saqlab, Instagram’da story sifatida tanlang. Rasmdagi yozuvning o‘zi bosiladigan havola emas — Link stikeri kerak.',
              style: TextStyle(fontSize: 12)),
        ]);
      },
    )),
  );
  }
}
