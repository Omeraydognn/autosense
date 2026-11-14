import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/photo_processing.dart';

/// Finds faces and licence plates on-device. Nothing leaves the phone.
abstract interface class SensitiveRegionDetector {
  /// False when the platform has no on-device detector (web).
  bool get available;

  /// Regions in upright image coordinates of the file at [path].
  Future<List<Region>> detect(String path);

  Future<void> close();
}

final sensitiveRegionDetectorProvider = Provider.autoDispose<SensitiveRegionDetector>((ref) {
  final isMobile =
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  final detector = isMobile ? MlKitRegionDetector() : const UnavailableRegionDetector();
  ref.onDispose(detector.close);
  return detector;
});

class MlKitRegionDetector implements SensitiveRegionDetector {
  MlKitRegionDetector()
    : _faces = FaceDetector(
        options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate, minFaceSize: 0.05),
      ),
      _text = TextRecognizer();

  final FaceDetector _faces;
  final TextRecognizer _text;

  @override
  bool get available => true;

  @override
  Future<List<Region>> detect(String path) async {
    final input = InputImage.fromFilePath(path);
    final faces = await _faces.processImage(input);
    final text = await _text.processImage(input);

    return [
      for (final f in faces)
        Region(
          f.boundingBox.left.round(),
          f.boundingBox.top.round(),
          f.boundingBox.width.round(),
          f.boundingBox.height.round(),
        ),
      for (final block in text.blocks)
        for (final line in block.lines)
          if (looksLikePlate(line.text))
            Region(
              line.boundingBox.left.round(),
              line.boundingBox.top.round(),
              line.boundingBox.width.round(),
              line.boundingBox.height.round(),
              kind: RegionKind.plate,
            ),
    ];
  }

  @override
  Future<void> close() async {
    await _faces.close();
    await _text.close();
  }
}

class UnavailableRegionDetector implements SensitiveRegionDetector {
  const UnavailableRegionDetector();
  @override
  bool get available => false;
  @override
  Future<List<Region>> detect(String path) async => const [];
  @override
  Future<void> close() async {}
}
