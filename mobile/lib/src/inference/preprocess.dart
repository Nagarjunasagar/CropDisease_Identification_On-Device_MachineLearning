import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Preprocessing contract shared with training (ml/cropdx/data.py) and the
/// Qt edge app (edge/core/src/preprocess.cpp):
///
///   1. decode, honour EXIF orientation, RGB
///   2. center-crop to a square
///   3. anti-aliased resize to [size] x [size]
///   4. float32 values in [0, 255], NHWC (normalisation is inside the model)
///
/// Pure Dart and synchronous so it can run in a background isolate and be
/// unit-tested without a device.
Float32List preprocessBytes(Uint8List encoded, int size) {
  return preprocessImage(_decode(encoded), size);
}

/// Decodes any supported format. Corrupt input surfaces as a FormatException
/// (package:image can throw RangeError while probing truncated headers).
img.Image _decode(Uint8List encoded) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(encoded);
  } on Object {
    decoded = null;
  }
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image');
  }
  return decoded;
}

Float32List preprocessImage(img.Image source, int size) {
  var image = img.bakeOrientation(source);
  if (image.format != img.Format.uint8 || image.numChannels != 3) {
    image = image.convert(format: img.Format.uint8, numChannels: 3);
  }

  final side = image.width < image.height ? image.width : image.height;
  image = img.copyCrop(
    image,
    x: (image.width - side) ~/ 2,
    y: (image.height - side) ~/ 2,
    width: side,
    height: side,
  );
  // `average` box-filters when shrinking (anti-aliased), like tf.image.resize
  // with antialias=True; plain bilinear on a 12 MP photo would alias badly.
  image = img.copyResize(
    image,
    width: size,
    height: size,
    interpolation:
        side > size ? img.Interpolation.average : img.Interpolation.linear,
  );

  final out = Float32List(size * size * 3);
  var i = 0;
  for (final p in image) {
    out[i++] = p.r.toDouble();
    out[i++] = p.g.toDouble();
    out[i++] = p.b.toDouble();
  }
  return out;
}

/// Small square JPEG thumbnail for the history list.
Uint8List thumbnailJpeg(Uint8List encoded, {int size = 256}) {
  final img.Image decoded;
  try {
    decoded = _decode(encoded);
  } on FormatException {
    return Uint8List(0);
  }
  final oriented = img.bakeOrientation(decoded);
  final side =
      oriented.width < oriented.height ? oriented.width : oriented.height;
  final square = img.copyCrop(
    oriented,
    x: (oriented.width - side) ~/ 2,
    y: (oriented.height - side) ~/ 2,
    width: side,
    height: side,
  );
  return img.encodeJpg(
    img.copyResize(
      square,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    ),
    quality: 85,
  );
}
