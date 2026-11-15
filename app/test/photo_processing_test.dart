import 'dart:typed_data';

import 'package:autosense/features/capture/domain/photo_processing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A 400×300 "dashboard" with a detailed checkerboard where a face would be,
/// EXIF orientation + GPS set, and an optional bright glare patch.
Uint8List samplePhoto({bool glare = false, int orientation = 1}) {
  final image = img.Image(width: 400, height: 300);
  img.fill(image, color: img.ColorRgb8(20, 25, 40));
  for (var y = 100; y < 200; y++) {
    for (var x = 150; x < 250; x++) {
      final on = ((x ~/ 4) + (y ~/ 4)).isEven;
      image.setPixelRgb(x, y, on ? 230 : 10, on ? 200 : 10, on ? 180 : 10);
    }
  }
  if (glare) img.fillRect(image, x1: 0, y1: 0, x2: 120, y2: 60, color: img.ColorRgb8(255, 255, 255));
  image.exif.imageIfd.orientation = orientation;
  image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(41, 1);
  image.exif.imageIfd['Model'] = img.IfdValueAscii('TestPhone');
  return img.encodeJpg(image);
}

double variance(img.Image image, int x0, int y0, int w, int h) {
  final values = <double>[];
  for (var y = y0; y < y0 + h; y++) {
    for (var x = x0; x < x0 + w; x++) {
      values.add(image.getPixel(x, y).luminanceNormalized.toDouble());
    }
  }
  final mean = values.reduce((a, b) => a + b) / values.length;
  return values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
}

void main() {
  test('strips all EXIF including GPS', () {
    final out = processPhoto(PhotoJob(samplePhoto()));
    expect(out.hadExif, isTrue);
    expect(out.hadGps, isTrue);

    final reread = img.decodeJpg(out.jpeg)!;
    expect(reread.exif.isEmpty, isTrue);
    expect(reread.exif.gpsIfd.isEmpty, isTrue);
  });

  test('region is destroyed (detail variance collapses), rest untouched', () {
    final before = img.decodeJpg(samplePhoto())!;
    final out = processPhoto(PhotoJob(samplePhoto(), regions: const [Region(150, 100, 100, 100)]));
    final after = img.decodeJpg(out.jpeg)!;

    expect(out.facesBlurred, 1);
    expect(variance(before, 160, 110, 80, 80), greaterThan(0.1));
    expect(variance(after, 160, 110, 80, 80), lessThan(0.02));
    expect(variance(after, 10, 250, 50, 40), closeTo(variance(before, 10, 250, 50, 40), 0.01));
  });

  test('orientation is baked in before boxes are applied', () {
    // Orientation 6 = rotate 90° CW → upright image is 300×400.
    final out = processPhoto(PhotoJob(samplePhoto(orientation: 6)));
    expect(out.width, 300);
    expect(out.height, 400);
  });

  test('large photos are downscaled', () {
    final big = img.Image(width: 4000, height: 3000);
    final out = processPhoto(PhotoJob(img.encodeJpg(big)));
    expect(out.width, 1600);
    expect(out.height, 1200);
  });

  test('large text-sized detail (a plate line) becomes unreadable', () {
    // 440×100 white plate with 40 px tall black "glyph" bars, like a 48 pt line.
    final image = img.Image(width: 1200, height: 900);
    img.fill(image, color: img.ColorRgb8(18, 22, 34));
    img.fillRect(image, x1: 380, y1: 720, x2: 820, y2: 820, color: img.ColorRgb8(250, 250, 250));
    for (var x = 470; x < 730; x += 26) {
      img.fillRect(image, x1: x, y1: 750, x2: x + 12, y2: 790, color: img.ColorRgb8(0, 0, 0));
    }
    final bytes = img.encodeJpg(image);
    final before = img.decodeJpg(bytes)!;
    // OCR line boxes are tight around the glyphs.
    final out = processPhoto(PhotoJob(bytes, regions: const [Region(465, 748, 270, 44, kind: RegionKind.plate)]));
    final after = img.decodeJpg(out.jpeg)!;

    expect(out.platesBlurred, 1);
    final v0 = variance(before, 470, 752, 250, 36);
    final v1 = variance(after, 470, 752, 250, 36);
    expect(v1, lessThan(v0 * 0.05), reason: 'glyph contrast must be destroyed, not just softened');
  });

  test('masked regions do not count as glare', () {
    final image = img.Image(width: 1200, height: 900);
    img.fill(image, color: img.ColorRgb8(18, 22, 34));
    img.fillRect(image, x1: 380, y1: 720, x2: 820, y2: 820, color: img.ColorRgb8(250, 250, 250));
    final out = processPhoto(
      PhotoJob(img.encodeJpg(image), regions: const [Region(380, 720, 440, 100, kind: RegionKind.plate)]),
    );
    expect(out.hasGlare, isFalse);
  });

  test('glare detection', () {
    expect(processPhoto(PhotoJob(samplePhoto())).hasGlare, isFalse);
    expect(processPhoto(PhotoJob(samplePhoto(glare: true))).hasGlare, isTrue);
  });

  test('regions outside the image are ignored safely', () {
    final out = processPhoto(PhotoJob(samplePhoto(), regions: const [Region(-500, -500, 10, 10)]));
    expect(out.facesBlurred, 0);
  });

  test('invalid bytes throw a typed error', () {
    expect(() => processPhoto(PhotoJob(Uint8List.fromList([1, 2, 3]))), throwsA(isA<PhotoDecodeException>()));
  });

  group('plate text', () {
    test('Turkish plates', () {
      for (final p in ['34 ABC 123', '06 A 1234', '35AB12', '81 ZZ 999']) {
        expect(looksLikePlate(p), isTrue, reason: p);
      }
    });
    test('dashboard text is not a plate', () {
      for (final t in ['142300 km', '142300', 'ECO', 'P R N D', '22:45', '90 km/h', '3000 RPM', 'ABS']) {
        expect(looksLikePlate(t), isFalse, reason: t);
      }
    });
  });
}
