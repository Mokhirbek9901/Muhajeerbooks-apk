import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';
import 'book_links.dart';
import 'bundle_story_image.dart';

class BundleStoryPage extends StatefulWidget {
  const BundleStoryPage({
    super.key,
    required this.bundle,
    required this.books,
  });

  final Map<String, dynamic> bundle;
  final List<Book> books;

  @override
  State<BundleStoryPage> createState() => _BundleStoryPageState();
}

class _BundleStoryPageState extends State<BundleStoryPage> {
  late Future<Uint8List> _image;
  bool _sharing = false;
  bool _copied = false;

  String get _id => (widget.bundle['id'] ?? '').toString();
  String get _title => (widget.bundle['title'] ?? 'Kitoblar seti').toString();

  @override
  void initState() {
    super.initState();
    _image = renderBundleStory(widget.bundle, widget.books);
  }

  Future<void> _copyLink() async {
    final link = bundleShareLink(_id).toString();
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _share(Uint8List bytes, BuildContext buttonContext) async {
    if (_sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: ['muhajeer-set-$_id-story.png'],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Set uchun Instagram story')),
        body: SafeArea(
          child: FutureBuilder<Uint8List>(
            future: _image,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: FilledButton(
                    onPressed: () => setState(
                      () => _image =
                          renderBundleStory(widget.bundle, widget.books),
                    ),
                    child: const Text('Qayta tayyorlash'),
                  ),
                );
              }
              final bytes = snapshot.data;
              if (bytes == null) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Set storysi tayyorlanmoqda…'),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 270),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(bytes, gaplessPlayback: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: Icon(_copied ? Icons.check_rounded : Icons.link_rounded),
                    label: Text(
                      _copied
                          ? 'Set havolasi nusxalandi'
                          : '1. Set havolasini nusxalash',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      onPressed:
                          _sharing ? null : () => _share(bytes, buttonContext),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('2. Story rasmini ulashish'),
                    ),
                  ),
                  if (kIsWeb)
                    TextButton.icon(
                      onPressed: () async => XFile.fromData(
                        bytes,
                        mimeType: 'image/png',
                        name: 'muhajeer-set-$_id-story.png',
                      ).saveTo('muhajeer-set-$_id-story.png'),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Rasmni yuklab olish'),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Storyda setdagi kitoblar kichik rasmlarda, asl narxlari bilan ko‘rinadi. Instagram’da Link stikeriga nusxalangan set havolasini qo‘ying.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
      );
}
