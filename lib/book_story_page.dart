import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_session.dart';
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
    BookStoryTemplate.obsidianEdition, // Grafit va oltin
    BookStoryTemplate.pearlEdition,    // Marvarid, ipak va nozik chiziqlar
    BookStoryTemplate.sapphireEdition, // Ko‘k kristall
    BookStoryTemplate.velvetEdition,   // Bordo velvet
    BookStoryTemplate.atlasLuxeEdition,// Atlas naqshi
    BookStoryTemplate.quickPrice,       // Faqat muqova, narx, yetkazish va mavjudlik
    BookStoryTemplate.cleanEdition,    // Oq va toza
    BookStoryTemplate.premiumEdition,  // To‘q yashil va oltin
    BookStoryTemplate.nightEdition,    // Tun ranglari
    BookStoryTemplate.warmEdition,     // Iliq va yumshoq
    BookStoryTemplate.saleEdition,     // Sotuv uchun yorqin
    BookStoryTemplate.editorialEdition,// Jurnal uslubida
    // Muqova ranglarini o‘zi tahlil qilib, fon/yozuv/aksentlarni moslaydi.
    BookStoryTemplate.current,    // Avto dizayn — yangi kompozitsiyani o‘zi yaratadi
    BookStoryTemplate.oldCurrent, // Hozir — eski tanish dizayn
    BookStoryTemplate.smartMatch, // Mos dizayn — mavjud dizaynlardan muqovaga mosini tanlaydi
    BookStoryTemplate.decorative, // Klassik
    BookStoryTemplate.spring,
    BookStoryTemplate.summer,
    BookStoryTemplate.autumn,
    BookStoryTemplate.winter,
    BookStoryTemplate.adras,      // Naqqosh
    BookStoryTemplate.cinema,     // Tun va shahar
    BookStoryTemplate.ornament,   // Sado
    BookStoryTemplate.noir,       // Zamonaviy
    BookStoryTemplate.marble,
    BookStoryTemplate.terracotta,
    BookStoryTemplate.royal,
    BookStoryTemplate.botanical,
    BookStoryTemplate.lifestyle,
    BookStoryTemplate.cleanStudio,
    BookStoryTemplate.goldArch,
    BookStoryTemplate.scrapbook,
    BookStoryTemplate.arch,
    BookStoryTemplate.split,
    BookStoryTemplate.polaroid,
    BookStoryTemplate.coverFocus,
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

  Future<void> _copyLink() async {
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
    if (_sharing) return;
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

  Future<void> _saveInstagramPost(
    Uint8List storyBytes,
    BuildContext buttonContext,
  ) async {
    if (_sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    setState(() => _sharing = true);
    try {
      // Reuse the selected Story design; only adapt the canvas to feed 4:5.
      final postPng = await renderBookInstagramPost(storyBytes);
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
  Widget build(BuildContext context) => Scaffold(
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
          const Text('Dizaynni tanlang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final columns = constraints.maxWidth >= 520 ? 5 : 4;
              final itemWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: _templateOrder.map((item) {
                  final selected = item == _template;
                  final darkItem =
                      item == BookStoryTemplate.obsidianEdition ||
                      item == BookStoryTemplate.sapphireEdition ||
                      item == BookStoryTemplate.velvetEdition ||
                      item == BookStoryTemplate.premiumEdition ||
                      item == BookStoryTemplate.nightEdition ||
                      item == BookStoryTemplate.library ||
                      item == BookStoryTemplate.emerald ||
                      item == BookStoryTemplate.geometric ||
                      item == BookStoryTemplate.coverFocus ||
                      item == BookStoryTemplate.lifestyle ||
                      item == BookStoryTemplate.goldArch ||
                      item == BookStoryTemplate.midnight ||
                      item == BookStoryTemplate.cinema ||
                      item == BookStoryTemplate.royal ||
                      item == BookStoryTemplate.adras ||
                      item == BookStoryTemplate.khiva ||
                      item == BookStoryTemplate.turon;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _selectTemplate(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: itemWidth,
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                      decoration: BoxDecoration(
                        color: bookStoryTemplateColor(item),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF08786E)
                              : const Color(0x22000000),
                          width: selected ? 3 : 1,
                        ),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                  color: Color(0x2208786E),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.auto_awesome_rounded,
                            size: 20,
                            color: darkItem
                                ? Colors.white
                                : const Color(0xFF174652),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bookStoryTemplateName(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: darkItem
                                  ? Colors.white
                                  : const Color(0xFF174652),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ClipRRect(borderRadius: BorderRadius.circular(18),
              child: Image.memory(bytes, gaplessPlayback: true,
                semanticLabel: '${widget.book.title}, ${storyPrice(widget.book)} — story rasmi')),
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
                  : () => _saveInstagramPost(bytes, buttonContext),
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
