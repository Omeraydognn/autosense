import 'dart:typed_data';

import 'package:autosense/features/capture/domain/captured_media.dart';
import 'package:autosense/features/diagnosis/data/media_repository.dart';
import 'package:autosense/features/diagnosis/domain/audio_classes.dart';
import 'package:autosense/features/onboarding/domain/consent.dart';
import 'package:flutter_test/flutter_test.dart';

Consent consent({bool diagnosis = true, bool improvement = false}) => Consent(
  version: '1.0',
  acceptedAt: DateTime(2026, 11, 13),
  diagnosis: diagnosis,
  modelImprovement: improvement,
  notifications: false,
);

CapturedPhoto photo({bool detectorRan = true}) => CapturedPhoto(
  jpeg: Uint8List(10),
  width: 10,
  height: 10,
  facesBlurred: 0,
  platesBlurred: 0,
  metadataRemoved: true,
  gpsRemoved: true,
  glare: false,
  detectorRan: detectorRan,
);

final audio = CapturedAudio(
  state: RecordingState.idle,
  wav: Uint8List(44),
  samples: Float32List(0),
  seconds: 10,
  speechRatio: 0,
);

class FakeUploader implements MediaUploader {
  final names = <String>[];
  bool fail = false;
  @override
  Future<String> put(
    String name,
    Uint8List bytes, {
    required String contentType,
    Map<String, String> meta = const {},
  }) async {
    if (fail) throw Exception('storage disabled');
    names.add(name);
    return 'users/u/media/$name';
  }
}

void main() {
  group('UploadPolicy', () {
    test('photo needs diagnosis consent and a completed face/plate scan', () {
      expect(UploadPolicy.photo(photo(), consent()), isTrue);
      expect(UploadPolicy.photo(photo(detectorRan: false), consent()), isFalse);
      expect(UploadPolicy.photo(photo(), consent(diagnosis: false)), isFalse);
      expect(UploadPolicy.photo(null, consent()), isFalse);
    });

    test('audio needs the separate model-improvement consent', () {
      expect(UploadPolicy.audio(audio, consent()), isFalse);
      expect(UploadPolicy.audio(audio, consent(improvement: true)), isTrue);
      expect(UploadPolicy.audio(audio, null), isFalse);
    });
  });

  group('MediaRepository', () {
    test('uploads only what the policy allows', () async {
      final up = FakeUploader();
      final paths = await MediaRepository(up)
          .uploadFor(reportId: 'r1', consent: consent(), audio: audio, photo: photo());
      expect(up.names, ['r1-photo.jpg']);
      expect(paths, ['users/u/media/r1-photo.jpg']);
    });

    test('failures never block the report', () async {
      final up = FakeUploader()..fail = true;
      final paths = await MediaRepository(up)
          .uploadFor(reportId: 'r1', consent: consent(improvement: true), audio: audio, photo: photo());
      expect(paths, isEmpty);
    });

    test('signed out / local mode uploads nothing', () async {
      expect(await MediaRepository(null).uploadFor(reportId: 'r1', consent: consent(), photo: photo()), isEmpty);
    });
  });
}
