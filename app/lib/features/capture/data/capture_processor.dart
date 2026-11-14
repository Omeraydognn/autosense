import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../diagnosis/domain/audio_classes.dart';
import '../domain/captured_media.dart';
import '../domain/pcm.dart';
import '../domain/photo_processing.dart';
import '../domain/speech_suppressor.dart';
import 'sensitive_region_detector.dart';

final captureProcessorProvider = Provider.autoDispose<CaptureProcessor>(
  (ref) => CaptureProcessor(ref.watch(sensitiveRegionDetectorProvider)),
);

/// Turns raw captures into privacy-safe media. Heavy work runs off the UI
/// isolate via [compute].
class CaptureProcessor {
  CaptureProcessor(this._detector);
  final SensitiveRegionDetector _detector;

  Future<CapturedAudio> finishAudio(Float32List raw, RecordingState state) async {
    final result = await compute(_processAudio, raw);
    return CapturedAudio(
      state: state,
      wav: result.wav,
      samples: result.samples,
      seconds: result.samples.length / AudioSpec.sampleRate,
      speechRatio: result.speechRatio,
    );
  }

  Future<CapturedPhoto> finishPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    var regions = const <Region>[];
    var detectorRan = false;
    if (_detector.available) {
      try {
        regions = await _detector.detect(file.path);
        detectorRan = true;
      } catch (e) {
        debugPrint('[capture] region detection failed: $e');
      }
    }
    final p = await compute(processPhoto, PhotoJob(bytes, regions: regions));
    return CapturedPhoto(
      jpeg: p.jpeg,
      width: p.width,
      height: p.height,
      facesBlurred: p.facesBlurred,
      platesBlurred: p.platesBlurred,
      metadataRemoved: p.hadExif,
      gpsRemoved: p.hadGps,
      glare: p.hasGlare,
      detectorRan: detectorRan,
    );
  }
}

class _AudioResult {
  const _AudioResult(this.wav, this.samples, this.speechRatio);
  final Uint8List wav;
  final Float32List samples;
  final double speechRatio;
}

_AudioResult _processAudio(Float32List raw) {
  final maxLen = (AudioSpec.maxSeconds * AudioSpec.sampleRate).round();
  final clip = raw.length > maxLen ? Float32List.sublistView(raw, 0, maxLen) : raw;
  final suppressed = const SpeechSuppressor().process(clip);
  return _AudioResult(WavEncoder.encode(suppressed.samples), suppressed.samples, suppressed.speechRatio);
}
