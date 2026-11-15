import 'dart:math' as math;
import 'dart:typed_data';

import 'pcm.dart';

class SuppressionResult {
  const SuppressionResult({required this.samples, required this.speechFrames, required this.totalFrames});

  final Float32List samples;
  final int speechFrames;
  final int totalFrames;

  double get speechRatio => totalFrames == 0 ? 0 : speechFrames / totalFrames;
  bool get speechDetected => speechFrames > 0;
}

/// On-device speech attenuation (P0 §5, KVKK): human voices in an engine
/// clip are detected and turned down by [attenuationDb] before the clip is
/// stored or uploaded.
///
/// Heuristic voice-activity detection — no model, runs in a few ms:
///  * **Voicing**: normalised autocorrelation peak in the human pitch range
///    (80–400 Hz). Engine idle firing is ~20–60 Hz, outside this range.
///  * **Prominence**: frame energy above the clip's noise floor (20th
///    percentile), because speech rides on top of the engine.
///  * **Smoothing**: a short hangover so syllables are not chopped.
///
/// Known limitation (MODEL_CARD): high-revving engines and belt squeal can
/// look voiced; a learned VAD (e.g. Silero) is the planned upgrade.
class SpeechSuppressor {
  const SpeechSuppressor({
    this.sampleRate = AudioSpec.sampleRate,
    this.frameMs = 30,
    this.hopMs = 15,
    this.voicingThreshold = 0.55,
    this.prominenceDb = 6,
    this.attenuationDb = 20,
    this.hangoverFrames = 6,
  });

  final int sampleRate;
  final int frameMs;
  final int hopMs;
  final double voicingThreshold;
  final double prominenceDb;
  final double attenuationDb;
  final int hangoverFrames;

  static const _minPitchHz = 80;
  static const _maxPitchHz = 400;

  SuppressionResult process(Float32List input) {
    final frame = sampleRate * frameMs ~/ 1000;
    final hop = sampleRate * hopMs ~/ 1000;
    if (input.length < frame) {
      return SuppressionResult(samples: Float32List.fromList(input), speechFrames: 0, totalFrames: 0);
    }

    final count = 1 + (input.length - frame) ~/ hop;
    final energy = List<double>.generate(count, (i) => Pcm.dbfs(input, i * hop, i * hop + frame));
    final floor = _percentile(energy, 0.2);

    final raw = List<bool>.generate(count, (i) {
      if (energy[i] < floor + prominenceDb) return false;
      return _voicing(input, i * hop, frame) >= voicingThreshold;
    });

    // Hangover: keep a few frames after (and one before) each detection.
    final speech = List<bool>.filled(count, false);
    for (var i = 0; i < count; i++) {
      if (!raw[i]) continue;
      for (var k = math.max(0, i - 1); k <= math.min(count - 1, i + hangoverFrames); k++) {
        speech[k] = true;
      }
    }

    // Per-sample gain with short linear ramps to avoid clicks.
    final low = math.pow(10, -attenuationDb / 20).toDouble();
    final gain = Float32List(input.length)..fillRange(0, input.length, 1);
    for (var i = 0; i < count; i++) {
      if (!speech[i]) continue;
      final end = math.min(input.length, i * hop + frame);
      for (var s = i * hop; s < end; s++) {
        gain[s] = low;
      }
    }
    final ramp = sampleRate ~/ 200; // 5 ms
    final smoothed = Float32List(input.length);
    var g = 1.0;
    final step = (1 - low) / ramp;
    for (var s = 0; s < input.length; s++) {
      final target = gain[s];
      if (g > target) {
        g = math.max(target, g - step);
      } else if (g < target) {
        g = math.min(target, g + step);
      }
      smoothed[s] = input[s] * g;
    }

    return SuppressionResult(samples: smoothed, speechFrames: speech.where((x) => x).length, totalFrames: count);
  }

  /// Max normalised autocorrelation over the pitch-lag range.
  double _voicing(Float32List x, int start, int len) {
    final minLag = sampleRate ~/ _maxPitchHz;
    final maxLag = math.min(len - 1, sampleRate ~/ _minPitchHz);

    // Remove DC within the frame.
    var mean = 0.0;
    for (var i = 0; i < len; i++) {
      mean += x[start + i];
    }
    mean /= len;

    var e0 = 0.0;
    for (var i = 0; i < len; i++) {
      final v = x[start + i] - mean;
      e0 += v * v;
    }
    if (e0 <= 1e-9) return 0;

    var best = 0.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var num = 0.0;
      var e1 = 0.0;
      var e2 = 0.0;
      for (var i = 0; i + lag < len; i++) {
        final a = x[start + i] - mean;
        final b = x[start + i + lag] - mean;
        num += a * b;
        e1 += a * a;
        e2 += b * b;
      }
      final denom = math.sqrt(e1 * e2);
      if (denom > 0) {
        final r = num / denom;
        if (r > best) best = r;
      }
    }
    return best;
  }

  static double _percentile(List<double> values, double p) {
    final sorted = [...values]..sort();
    return sorted[(p * (sorted.length - 1)).round()];
  }
}
