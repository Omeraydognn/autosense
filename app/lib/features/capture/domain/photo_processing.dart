import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A rectangle in the upright (orientation-applied) image, in pixels.
class Region {
  const Region(this.left, this.top, this.width, this.height, {this.kind = RegionKind.face});
  final int left;
  final int top;
  final int width;
  final int height;
  final RegionKind kind;

  /// Grows the box by [fraction] on every side (detectors are tight).
  Region inflate(double fraction) {
    final dx = (width * fraction).round();
    final dy = (height * fraction).round();
    return Region(left - dx, top - dy, width + 2 * dx, height + 2 * dy, kind: kind);
  }
}

enum RegionKind { face, plate }

class PhotoJob {
  const PhotoJob(this.bytes, {this.regions = const [], this.maxSide = 1600});
  final Uint8List bytes;
  final List<Region> regions;
  final int maxSide;
}

class ProcessedPhoto {
  const ProcessedPhoto({
    required this.jpeg,
    required this.width,
    required this.height,
    required this.hadExif,
    required this.hadGps,
    required this.glareRatio,
    required this.facesBlurred,
    required this.platesBlurred,
  });

  final Uint8List jpeg;
  final int width;
  final int height;
  final bool hadExif;
  final bool hadGps;

  /// Share of near-white, low-saturation pixels (reflections on the cluster glass).
  final double glareRatio;
  final int facesBlurred;
  final int platesBlurred;

  static const glareThreshold = 0.03;
  bool get hasGlare => glareRatio >= glareThreshold;
}

class PhotoDecodeException implements Exception {
  const PhotoDecodeException();
  @override
  String toString() => 'Fotoğraf okunamadı';
}

/// Pure, isolate-safe photo anonymisation (P0 §5).
///
/// Order matters: orientation is baked first so detector boxes (which are in
/// upright coordinates) line up, regions are destroyed *before* resizing, and
/// all metadata is dropped on encode.
ProcessedPhoto processPhoto(PhotoJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) throw const PhotoDecodeException();

  final hadExif = !decoded.exif.isEmpty;
  final hadGps = !decoded.exif.gpsIfd.isEmpty;

  var image = img.bakeOrientation(decoded);

  var faces = 0;
  var plates = 0;
  final masked = <Region>[];
  for (final raw in job.regions) {
    final r = _clip(raw.inflate(0.15), image.width, image.height);
    if (r == null) continue;
    final crop = img.copyCrop(image, x: r.left, y: r.top, width: r.width, height: r.height);
    // Coarse averaged blocks (≈2 per short side) then a blur: glyphs and
    // facial features are destroyed, not merely softened.
    final block = math.max(8, math.min(r.width, r.height) ~/ 2);
    final redacted = img.gaussianBlur(
      img.pixelate(crop, size: block, mode: img.PixelateMode.average),
      radius: math.max(4, block ~/ 2),
    );
    img.compositeImage(image, redacted, dstX: r.left, dstY: r.top);
    masked.add(r);
    raw.kind == RegionKind.face ? faces++ : plates++;
  }

  // Measured before resizing so region coordinates still line up.
  final glare = measureGlare(image, exclude: masked);

  final longest = math.max(image.width, image.height);
  if (longest > job.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: job.maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: job.maxSide, interpolation: img.Interpolation.average);
  }

  // Drop EXIF entirely: GPS, device model, timestamps, thumbnails.
  image.exif.clear();
  final jpeg = img.encodeJpg(image, quality: 85);

  return ProcessedPhoto(
    jpeg: jpeg,
    width: image.width,
    height: image.height,
    hadExif: hadExif,
    hadGps: hadGps,
    glareRatio: glare,
    facesBlurred: faces,
    platesBlurred: plates,
  );
}

/// Fraction of bright, desaturated pixels on a ~160 px thumbnail, ignoring
/// [exclude] (redacted areas such as a white plate are content, not glare).
double measureGlare(img.Image image, {List<Region> exclude = const []}) {
  final small = image.width > 160 ? img.copyResize(image, width: 160) : image;
  final sx = image.width / small.width;
  final sy = image.height / small.height;
  bool excluded(int x, int y) {
    final ox = x * sx;
    final oy = y * sy;
    return exclude.any((r) => ox >= r.left && ox < r.left + r.width && oy >= r.top && oy < r.top + r.height);
  }

  var bright = 0;
  var total = 0;
  for (final p in small) {
    if (excluded(p.x, p.y)) continue;
    final r = p.rNormalized.toDouble();
    final g = p.gNormalized.toDouble();
    final b = p.bNormalized.toDouble();
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final saturation = maxC == 0 ? 0 : (maxC - minC) / maxC;
    if (maxC > 0.94 && saturation < 0.15) bright++;
    total++;
  }
  return total == 0 ? 0 : bright / total;
}

Region? _clip(Region r, int w, int h) {
  final left = r.left.clamp(0, w);
  final top = r.top.clamp(0, h);
  final right = (r.left + r.width).clamp(0, w);
  final bottom = (r.top + r.height).clamp(0, h);
  if (right - left < 2 || bottom - top < 2) return null;
  return Region(left, top, right - left, bottom - top, kind: r.kind);
}

/// Turkish plate format, e.g. "34 ABC 123", "06 A 1234", "35 AB 12".
final turkishPlate = RegExp(r'^(0[1-9]|[1-7]\d|8[01])\s?[A-Z]{1,3}\s?\d{2,4}$');

/// True when recognised text looks like a licence plate (TR or generic EU).
bool looksLikePlate(String text) {
  final t = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 ]'), '').trim();
  if (turkishPlate.hasMatch(t)) return true;
  final compact = t.replaceAll(' ', '');
  final hasLetters = RegExp(r'[A-Z]').hasMatch(compact);
  final hasDigits = RegExp(r'\d').hasMatch(compact);
  // Generic: 5–8 alphanumerics mixing letters and digits, not a unit like "142300KM".
  return compact.length >= 5 &&
      compact.length <= 8 &&
      hasLetters &&
      hasDigits &&
      !RegExp(r'^\d+(KM|KMH|RPM|L|C)$').hasMatch(compact);
}
