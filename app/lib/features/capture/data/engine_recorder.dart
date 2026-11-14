import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../domain/pcm.dart';

final engineRecorderProvider = Provider.autoDispose<EngineRecorder>((ref) {
  final recorder = EngineRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// Records raw 16 kHz mono PCM for engine diagnosis.
///
/// Voice-oriented processing (AGC, noise suppression, echo cancellation) is
/// switched off on purpose: it would erase exactly the mechanical sounds the
/// classifier needs.
class EngineRecorder {
  EngineRecorder({AudioRecorder? recorder}) : _rec = recorder ?? AudioRecorder();

  final AudioRecorder _rec;
  final _buffer = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _sub;
  StreamController<Float32List>? _chunks;

  static const config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: AudioSpec.sampleRate,
    numChannels: AudioSpec.channels,
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
    androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.mic),
  );

  Future<bool> hasPermission() => _rec.hasPermission();

  /// Starts recording and returns live float chunks for the meter/waveform.
  Future<Stream<Float32List>> start() async {
    await _sub?.cancel();
    _buffer.clear();
    final chunks = _chunks = StreamController<Float32List>.broadcast();
    final bytes = await _rec.startStream(config);
    _sub = bytes.listen((b) {
      _buffer.add(b);
      if (!chunks.isClosed) chunks.add(Pcm.int16ToFloat(b));
    }, onError: (Object e) => debugPrint('[recorder] $e'));
    return chunks.stream;
  }

  /// Stops and returns everything recorded since [start].
  Future<Float32List> stop() async {
    await _rec.stop();
    await _sub?.cancel();
    _sub = null;
    await _chunks?.close();
    return Pcm.int16ToFloat(_buffer.takeBytes());
  }

  Future<void> cancel() async {
    await _rec.cancel();
    await _sub?.cancel();
    _sub = null;
    await _chunks?.close();
    _buffer.clear();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _chunks?.close();
    await _rec.dispose();
  }
}
