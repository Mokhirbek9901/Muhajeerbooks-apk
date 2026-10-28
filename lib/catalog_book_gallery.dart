import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';

/// Lazy thumbnails keep the catalog compact even for very large galleries.
class CatalogBookGallery extends StatefulWidget {
  const CatalogBookGallery({super.key, required this.book, required this.fallback});
  final Book book;
  final Widget fallback;
  @override
  State<CatalogBookGallery> createState() => _CatalogBookGalleryState();
}

class _CatalogBookGalleryState extends State<CatalogBookGallery> {
  final controller = PageController();
  int index = 0;

  @override
  void didUpdateWidget(covariant CatalogBookGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.book.galleryImages, widget.book.galleryImages)) {
      index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) controller.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.book.galleryImages;
    if (images.length < 2) return widget.fallback;
    void move(int delta) => controller.animateToPage(
      (index + delta).clamp(0, images.length - 1),
      duration: const Duration(milliseconds: 180), curve: Curves.easeOut,
    );
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        key: const ValueKey('catalog-book-photos'),
        controller: controller,
        itemCount: images.length,
        onPageChanged: (value) => setState(() => index = value),
        itemBuilder: (_, i) => Image.network(
          widget.book.galleryThumbnailUrlAt(i), fit: BoxFit.cover,
          cacheWidth: 480, gaplessPlayback: true,
          errorBuilder: (_, __, ___) => widget.fallback,
        ),
      ),
      Positioned(right: 6, bottom: 8, child: Material(
        color: Colors.black.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Oldingi rasm', visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            iconSize: 18, color: Colors.white,
            onPressed: index > 0 ? () => move(-1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${index + 1}/${images.length}',
            style: const TextStyle(color: Colors.white, fontSize: 11)),
          IconButton(
            tooltip: 'Keyingi rasm', visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            iconSize: 18, color: Colors.white,
            onPressed: index < images.length - 1 ? () => move(1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
      )),
    ]);
  }
}
