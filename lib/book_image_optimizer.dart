import 'dart:typed_data';
import 'package:image/image.dart' as img;

const bookPhotoMaxBytes = 240 * 1024;
const bookThumbnailMaxBytes = 40 * 1024;

img.Image _fit(img.Image source, int width, int height) {
  final scale = (width / source.width) < (height / source.height)
      ? width / source.width : height / source.height;
  if (scale >= 1) return source;
  return img.copyResize(source,
    width: (source.width * scale).round().clamp(1, width),
    height: (source.height * scale).round().clamp(1, height),
    interpolation: img.Interpolation.average,
  );
}

Uint8List _boundedJpeg(img.Image source, int limit, int quality) {
  var image = source;
  while (true) {
    for (var q = quality; q >= 60; q -= 4) {
      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: q));
      if (bytes.length <= limit) return bytes;
    }
    if (image.width <= 1 && image.height <= 1) {
      throw StateError('Rasmni kichraytirib bo‘lmadi.');
    }
    image = img.copyResize(image,
      width: (image.width * .82).floor().clamp(1, image.width),
      height: (image.height * .82).floor().clamp(1, image.height),
      interpolation: img.Interpolation.average,
    );
  }
}

/// Only compressed display/thumbnail variants are sent; originals stay local.
Map<String, Uint8List>? prepareBookImageVariants(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  return {
    'full': _boundedJpeg(_fit(oriented, 1200, 1800), bookPhotoMaxBytes, 76),
    'thumb': _boundedJpeg(_fit(oriented, 480, 720), bookThumbnailMaxBytes, 76),
  };
}
