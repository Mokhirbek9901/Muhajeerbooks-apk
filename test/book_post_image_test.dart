import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/book_post_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Instagram post is 1080x1350 and keeps both Story ends', () async {
    // A synthetic Story makes accidental center-cropping easy to detect:
    // the full-width red header and blue footer must both remain visible.
    const storyWidth = 1080;
    const storyHeight = 1920;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1080, 1920),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1080, 120),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 1800, 1080, 120),
      ui.Paint()..color = const ui.Color(0xFF0000FF),
    );
    final picture = recorder.endRecording();
    final story = await picture.toImage(storyWidth, storyHeight);
    final storyPng = await story.toByteData(format: ui.ImageByteFormat.png);
    expect(storyPng, isNotNull);
    final pngBytes = Uint8List.fromList(storyPng!.buffer.asUint8List());
    story.dispose();
    picture.dispose();

    final png = await renderBookInstagramPost(pngBytes);
    final codec = await ui.instantiateImageCodec(png);
    final output = (await codec.getNextFrame()).image;
    expect(output.width, 1080);
    expect(output.height, 1350);

    final rgba = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(rgba, isNotNull);
    final data = rgba!.buffer.asUint8List();
    int channel(int x, int y, int index) =>
        data[(y * output.width + x) * 4 + index];

    // The head and tail are preserved by containment, not centre-cropping.
    expect(channel(540, 40, 0), greaterThan(200)); // red header
    expect(channel(540, 40, 2), lessThan(50));
    expect(channel(540, 1310, 2), greaterThan(200)); // blue footer
    expect(channel(540, 1310, 0), lessThan(50));

    output.dispose();
    codec.dispose();
  });
}
