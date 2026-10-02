import 'dart:typed_data';

import 'package:croheal/src/inference/preprocess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('center-crops a landscape image and resizes to size x size x 3', () {
    // 300x100: red | green | blue thirds. Center crop keeps only green.
    final image = img.Image(width: 300, height: 100);
    for (final p in image) {
      if (p.x < 100) {
        p.setRgb(255, 0, 0);
      } else if (p.x < 200) {
        p.setRgb(0, 255, 0);
      } else {
        p.setRgb(0, 0, 255);
      }
    }
    final out = preprocessImage(image, 32);
    expect(out.length, 32 * 32 * 3);
    // centre pixel is pure green, values are raw 0..255 (no normalisation)
    final c = (16 * 32 + 16) * 3;
    expect(out.sublist(c, c + 3), [0, 255, 0]);
    expect(out.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(255));
    expect(out.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(0));
  });

  test('decodes encoded JPEG bytes', () {
    final image = img.Image(width: 64, height: 48);
    img.fill(image, color: img.ColorRgb8(10, 120, 30));
    final out = preprocessBytes(Uint8List.fromList(img.encodeJpg(image)), 16);
    expect(out.length, 16 * 16 * 3);
    expect(out[1], closeTo(120, 6)); // JPEG is lossy
  });

  test('rejects garbage bytes', () {
    expect(() => preprocessBytes(Uint8List.fromList([1, 2, 3, 4]), 16),
        throwsFormatException);
  });

  test('thumbnail is a square JPEG', () {
    final image = img.Image(width: 400, height: 200);
    final thumb = img.decodeJpg(
        thumbnailJpeg(Uint8List.fromList(img.encodePng(image)), size: 64))!;
    expect((thumb.width, thumb.height), (64, 64));
  });
}
