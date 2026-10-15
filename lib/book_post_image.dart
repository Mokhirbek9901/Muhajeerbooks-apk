import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Converts any existing 9:16 Story design into an Instagram feed portrait.
///
/// The original artwork is *contained*, never cropped or stretched: the
/// unobstructed Story remains visible, including multi-page descriptions.
/// Its blurred colours fill the extra space at the sides of the 4:5 canvas.
Future<Uint8List> renderBookInstagramPost(Uint8List storyPng) async {
  const postWidth = 1080;
  const postHeight = 1350;

  final codec = await ui.instantiateImageCodec(storyPng);
  ui.Image? source;
  try {
    final frame = await codec.getNextFrame();
    source = frame.image;

    final sourceWidth = source.width.toDouble();
    final sourceHeight = source.height.toDouble();
    final bounds = const ui.Rect.fromLTWH(0, 0, 1080, 1350);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final fillScale = math.max(
      postWidth / sourceWidth,
      postHeight / sourceHeight,
    );
    final cropWidth = postWidth / fillScale;
    final cropHeight = postHeight / fillScale;
    final backgroundCrop = ui.Rect.fromLTWH(
      (sourceWidth - cropWidth) / 2,
      (sourceHeight - cropHeight) / 2,
      cropWidth,
      cropHeight,
    );

    // A soft extension of the chosen Story design fills the post sides.
    canvas.drawImageRect(
      source,
      backgroundCrop,
      bounds,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.medium
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
    );
    canvas.drawRect(
      bounds,
      ui.Paint()..color = const ui.Color(0x550B131A),
    );

    // Contain the *entire* Story — no book-cover, title, price or text loss.
    final containScale = math.min(
      postWidth / sourceWidth,
      postHeight / sourceHeight,
    );
    final width = sourceWidth * containScale;
    final height = sourceHeight * containScale;
    final foreground = ui.Rect.fromLTWH(
      (postWidth - width) / 2,
      (postHeight - height) / 2,
      width,
      height,
    );
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(0, 0, sourceWidth, sourceHeight),
      foreground,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );

    final picture = recorder.endRecording();
    try {
      final rendered = await picture.toImage(postWidth, postHeight);
      try {
        final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('Instagram post PNG eksporti amalga oshmadi');
        }
        return data.buffer.asUint8List();
      } finally {
        rendered.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    source?.dispose();
    codec.dispose();
  }
}
