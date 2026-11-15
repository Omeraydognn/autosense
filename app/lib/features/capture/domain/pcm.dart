import 'dart:math' as math;
import 'dart:typed_data';

/// Audio format used end to end: matches the YAMNet input (Track A).
abstract final class AudioSpec {
  static const sampleRate = 16000;
  static const channels = 1;
  static const maxSeconds = 10.0;
  static const minSeconds = 2.0;
}

abstract final class Pcm {
  /// Little-endian signed 16-bit PCM bytes → floats in [-1, 1].
  static Float32List int16ToFloat(Uint8List bytes) {
    final n = bytes.lengthInBytes ~/ 2;
    final data = ByteData.sublistView(bytes, 0, n * 2);
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  /// Root-mean-square of [samples] in dBFS (−∞ … 0). Silence → −120.
  static double dbfs(Float32List samples, [int start = 0, int? end]) {
    final e = end ?? samples.length;
    if (e <= start) return -120;
    var sum = 0.0;
    for (var i = start; i < e; i++) {
      sum += samples[i] * samples[i];
    }
    final rms = math.sqrt(sum / (e - start));
    return rms <= 1e-6 ? -120 : 20 * math.log(rms) / math.ln10;
  }

  /// Maps dBFS to a 0..1 meter value (−60 dBFS → 0, 0 dBFS → 1).
  static double meterLevel(double dbfs) => ((dbfs + 60) / 60).clamp(0.0, 1.0);

  /// Peak absolute amplitude.
  static double peak(Float32List samples) {
    var p = 0.0;
    for (final s in samples) {
      final a = s.abs();
      if (a > p) p = a;
    }
    return p;
  }
}

/// Minimal RIFF/WAVE writer: 16-bit PCM, mono.
abstract final class WavEncoder {
  static Uint8List encode(Float32List samples, {int sampleRate = AudioSpec.sampleRate}) {
    const bytesPerSample = 2;
    final dataLen = samples.length * bytesPerSample;
    final b = ByteData(44 + dataLen);
    void ascii(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    b.setUint32(16, 16, Endian.little); // PCM chunk size
    b.setUint16(20, 1, Endian.little); // PCM format
    b.setUint16(22, AudioSpec.channels, Endian.little);
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * bytesPerSample * AudioSpec.channels, Endian.little);
    b.setUint16(32, bytesPerSample * AudioSpec.channels, Endian.little);
    b.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      b.setInt16(44 + i * 2, v, Endian.little);
    }
    return b.buffer.asUint8List();
  }

  /// Reads back samples written by [encode] (used in tests and for replay).
  static Float32List decode(Uint8List wav) => Pcm.int16ToFloat(Uint8List.sublistView(wav, 44));
}
