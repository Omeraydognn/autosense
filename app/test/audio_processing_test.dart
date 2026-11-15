import 'dart:math' as math;
import 'dart:typed_data';

import 'package:autosense/features/capture/domain/pcm.dart';
import 'package:autosense/features/capture/domain/speech_suppressor.dart';
import 'package:flutter_test/flutter_test.dart';

const sr = AudioSpec.sampleRate;

/// Idle engine: 27 Hz firing pulses that ring at 160 Hz, plus broadband noise.
Float32List engine(double seconds, {int seed = 1}) {
  final rnd = math.Random(seed);
  final n = (seconds * sr).round();
  final out = Float32List(n);
  const period = sr ~/ 27;
  for (var i = 0; i < n; i++) {
    final t = (i % period) / sr;
    final ring = math.exp(-t * 60) * math.sin(2 * math.pi * 160 * t);
    out[i] = 0.12 * ring + 0.05 * (rnd.nextDouble() * 2 - 1);
  }
  return out;
}

/// Voiced "syllables": 140 Hz glottal-like harmonics, 250 ms on / 250 ms off.
Float32List withSpeech(Float32List base, {required double from, required double to}) {
  final out = Float32List.fromList(base);
  for (var i = (from * sr).round(); i < (to * sr).round() && i < out.length; i++) {
    final t = i / sr;
    final syllableOn = ((t - from) % 0.5) < 0.25;
    if (!syllableOn) continue;
    var v = 0.0;
    for (var h = 1; h <= 6; h++) {
      v += math.sin(2 * math.pi * 140 * h * t) / h;
    }
    out[i] += 0.35 * v;
  }
  return out;
}

double segmentDb(Float32List x, double from, double to) => Pcm.dbfs(x, (from * sr).round(), (to * sr).round());

void main() {
  group('PCM / WAV', () {
    test('int16 bytes → floats', () {
      final b = ByteData(6)
        ..setInt16(0, 32767, Endian.little)
        ..setInt16(2, -32768, Endian.little)
        ..setInt16(4, 0, Endian.little);
      final f = Pcm.int16ToFloat(b.buffer.asUint8List());
      expect(f[0], closeTo(1, 1e-4));
      expect(f[1], -1);
      expect(f[2], 0);
    });

    test('WAV header is valid 16 kHz mono 16-bit and samples round-trip', () {
      final samples = Float32List.fromList(List.generate(1600, (i) => math.sin(i / 10) * 0.5));
      final wav = WavEncoder.encode(samples);
      final h = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(h.getUint16(22, Endian.little), 1);
      expect(h.getUint32(24, Endian.little), 16000);
      expect(h.getUint16(34, Endian.little), 16);
      expect(wav.length, 44 + 1600 * 2);
      final back = WavEncoder.decode(wav);
      for (var i = 0; i < samples.length; i += 97) {
        expect(back[i], closeTo(samples[i], 1e-3));
      }
    });

    test('dBFS and meter level', () {
      final sine = Float32List.fromList(List.generate(sr, (i) => math.sin(2 * math.pi * 440 * i / sr)));
      expect(Pcm.dbfs(sine), closeTo(-3.01, 0.05));
      expect(Pcm.dbfs(Float32List(100)), -120);
      expect(Pcm.meterLevel(-60), 0);
      expect(Pcm.meterLevel(-30), 0.5);
      expect(Pcm.meterLevel(3), 1);
    });
  });

  group('SpeechSuppressor', () {
    const vad = SpeechSuppressor();

    test('engine-only clip is left (almost) untouched', () {
      final clip = engine(10);
      final r = vad.process(clip);
      expect(r.speechRatio, lessThan(0.05), reason: 'false-positive rate on pure engine noise');
      expect(segmentDb(r.samples, 0, 10), closeTo(segmentDb(clip, 0, 10), 0.5));
    });

    test('speech over engine is detected and attenuated', () {
      final clip = withSpeech(engine(10, seed: 7), from: 3, to: 6);
      final r = vad.process(clip);

      expect(r.speechDetected, isTrue);
      expect(r.speechRatio, inInclusiveRange(0.15, 0.5));

      // Inside the speech region the level drops by well over 10 dB…
      final before = segmentDb(clip, 3, 6);
      final after = segmentDb(r.samples, 3, 6);
      expect(before - after, greaterThan(10));

      // …while engine-only regions keep their level.
      expect(segmentDb(r.samples, 0.5, 2.5), closeTo(segmentDb(clip, 0.5, 2.5), 1.0));
      expect(segmentDb(r.samples, 7, 9.5), closeTo(segmentDb(clip, 7, 9.5), 1.0));
    });

    test('very short input is returned unchanged', () {
      final r = vad.process(Float32List(100));
      expect(r.totalFrames, 0);
      expect(r.samples.length, 100);
    });
  });
}
