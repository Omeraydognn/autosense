import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/remote_store.dart';
import '../../capture/domain/captured_media.dart';
import '../../onboarding/domain/consent.dart';

/// Decides *what* may leave the device. Pure, so it is unit-tested.
abstract final class UploadPolicy {
  /// The anonymised photo is needed for cloud vision (Track B) — only if
  /// faces/plates were actually scanned, and only with diagnosis consent.
  static bool photo(CapturedPhoto? p, Consent? c) => p != null && p.safeToUpload && (c?.diagnosis ?? false);

  /// Audio is classified on-device; the clip is uploaded only to improve
  /// the model, which needs its own separate consent.
  static bool audio(CapturedAudio? a, Consent? c) => a != null && (c?.modelImprovement ?? false);
}

abstract interface class MediaUploader {
  /// Uploads [bytes] to `users/{uid}/media/{name}` and returns the path.
  Future<String> put(String name, Uint8List bytes, {required String contentType, Map<String, String> meta});
}

final mediaUploaderProvider = Provider<MediaUploader?>((ref) {
  final remote = ref.watch(remoteStoreProvider);
  return remote == null ? null : FirebaseMediaUploader(FirebaseStorage.instance, remote.uid);
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) => MediaRepository(ref.watch(mediaUploaderProvider)));

class FirebaseMediaUploader implements MediaUploader {
  FirebaseMediaUploader(this._storage, this.uid);
  final FirebaseStorage _storage;
  final String uid;

  @override
  Future<String> put(
    String name,
    Uint8List bytes, {
    required String contentType,
    Map<String, String> meta = const {},
  }) async {
    final ref = _storage.ref('users/$uid/media/$name');
    await ref.putData(bytes, SettableMetadata(contentType: contentType, customMetadata: meta));
    return ref.fullPath;
  }
}

/// Uploads anonymised media for a report. Never blocks the report: any
/// failure (offline, Storage not enabled, quota) just means no media path.
class MediaRepository {
  MediaRepository(this._uploader, {this.timeout = const Duration(seconds: 20)});
  final MediaUploader? _uploader;
  final Duration timeout;

  Future<List<String>> uploadFor({
    required String reportId,
    required Consent? consent,
    CapturedAudio? audio,
    CapturedPhoto? photo,
  }) async {
    final uploader = _uploader;
    if (uploader == null) return const [];
    final meta = {'reportId': reportId, 'anonymised': 'true'};

    final jobs = <Future<String?>>[
      if (UploadPolicy.photo(photo, consent))
        _try(() => uploader.put('$reportId-photo.jpg', photo!.jpeg, contentType: 'image/jpeg', meta: meta)),
      if (UploadPolicy.audio(audio, consent))
        _try(() => uploader.put('$reportId-audio.wav', audio!.wav, contentType: 'audio/wav', meta: meta)),
    ];
    final results = await Future.wait(jobs);
    return results.whereType<String>().toList();
  }

  Future<String?> _try(Future<String> Function() job) async {
    try {
      return await job().timeout(timeout);
    } catch (e) {
      debugPrint('[media] upload skipped: $e');
      return null;
    }
  }
}
