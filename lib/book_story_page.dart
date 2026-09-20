import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'book_links.dart';
import 'book_story_image.dart';

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

  static const _templatePreferenceKey = 'book_story_template_v1';

  // Eng yangi dizaynlar tepada ko‘rinsin — foydalanuvchi ularni qidirib
  // pastga tushmasin. Qolganlari avvalgi tartibda saqlanadi.
  static const List<BookStoryTemplate> _templateOrder = [
    BookStoryTemplate.atlas,
    BookStoryTemplate.marble,
    BookStoryTemplate.cinema,
    BookStoryTemplate.terracotta,
    BookStoryTemplate.royal,
    BookStoryTemplate.silk,
    BookStoryTemplate.botanical,
    BookStoryTemplate.mosaic,
    BookStoryTemplate.midnight,
    BookStoryTemplate.gallery,
    BookStoryTemplate.lifestyle,
    BookStoryTemplate.cleanStudio,
    BookStoryTemplate.goldArch,
    BookStoryTemplate.scrapbook,
    BookStoryTemplate.current,
    BookStoryTemplate.arch,
    BookStoryTemplate.magazine,
    BookStoryTemplate.classic,
    BookStoryTemplate.poster,
    BookStoryTemplate.noir,
    BookStoryTemplate.split,
    BookStoryTemplate.polaroid,
    BookStoryTemplate.collage,
    BookStoryTemplate.coverFocus,
  ];

  @override
  void initState() {
    super.initState();
    _image = renderBookStory(widget.book, template: _template);
    _restoreTemplate();
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
      final restoredTemplate = restored!;
      setState(() {
        _template = restoredTemplate;
        _image = renderBookStory(widget.book, template: restoredTemplate);
      });
    } catch (_) {
      // Saqlangan tanlov o‘qilmasa hozirgi dizayn bilan davom etamiz.
    }
  }

  String get _filename =>
      'muhajeer-${widget.book.id}-${bookStoryTemplateName(_template).toLowerCase()}-story.png';

  Future<void> _selectTemplate(BookStoryTemplate template) async {
    if (_template == template) return;
    setState(() {
      _template = template;
      _image = renderBookStory(widget.book, template: template);
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

  Future<void> _share(Uint8List bytes, BuildContext buttonContext) async {
    if (_sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    setState(() => _sharing = true);
    try {
      // Only the PNG: Instagram may discard image + URL payloads. The exact
      // book URL is copied separately for its tappable Link sticker.
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: [_filename],
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Instagram story')),
    body: SafeArea(child: FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Kitob rasmini yuklab bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => setState(() {
              _image = renderBookStory(widget.book, template: _template);
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
                  final darkItem = item == BookStoryTemplate.library ||
                      item == BookStoryTemplate.emerald ||
                      item == BookStoryTemplate.noir ||
                      item == BookStoryTemplate.geometric ||
                      item == BookStoryTemplate.coverFocus ||
                      item == BookStoryTemplate.lifestyle ||
                      item == BookStoryTemplate.goldArch ||
                      item == BookStoryTemplate.mosaic ||
                      item == BookStoryTemplate.midnight ||
                      item == BookStoryTemplate.atlas ||
                      item == BookStoryTemplate.cinema ||
                      item == BookStoryTemplate.royal;
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
            constraints: const BoxConstraints(maxWidth: 270),
            child: ClipRRect(borderRadius: BorderRadius.circular(18),
              child: Image.memory(bytes, gaplessPlayback: true,
                semanticLabel: '${widget.book.title}, ${storyPrice(widget.book)} — story rasmi')),
          )),
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
          const SizedBox(height: 8),
          const Text('Instagram ulashish ro‘yxatida chiqmasa, rasmni saqlab, Instagram’da story sifatida tanlang. Rasmdagi yozuvning o‘zi bosiladigan havola emas — Link stikeri kerak.',
              style: TextStyle(fontSize: 12)),
        ]);
      },
    )),
  );
}
