import 'dart:typed_data';

import '../../diagnosis/domain/audio_classes.dart';

/// An engine clip after on-device processing: 16 kHz mono, speech attenuated.
class CapturedAudio {
  const CapturedAudio({
    required this.state,
    required this.wav,
    required this.samples,
    required this.seconds,
    required this.speechRatio,
  });

  final RecordingState state;

  /// 16-bit PCM WAV, ready for upload (model-improvement consent only).
  final Uint8List wav;

  /// Float samples for the on-device classifier (Track A / YAMNet).
  final Float32List samples;
  final double seconds;

  /// Share of frames where speech was detected and attenuated.
  final double speechRatio;
  bool get speechSuppressed => speechRatio > 0;
}

/// A dashboard photo after on-device anonymisation.
class CapturedPhoto {
  const CapturedPhoto({
    required this.jpeg,
    required this.width,
    required this.height,
    required this.facesBlurred,
    required this.platesBlurred,
    required this.metadataRemoved,
    required this.gpsRemoved,
    required this.glare,
    required this.detectorRan,
  });

  final Uint8List jpeg;
  final int width;
  final int height;
  final int facesBlurred;
  final int platesBlurred;

  /// EXIF existed and was stripped.
  final bool metadataRemoved;
  final bool gpsRemoved;
  final bool glare;

  /// False where face/plate detection is unavailable (web). Such photos are
  /// never uploaded, because anonymisation cannot be guaranteed.
  final bool detectorRan;
  bool get safeToUpload => detectorRan;
}
