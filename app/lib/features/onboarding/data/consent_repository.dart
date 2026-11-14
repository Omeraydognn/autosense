import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/remote_store.dart';
import '../../../core/storage/local_store.dart';
import '../domain/consent.dart';

final consentProvider = NotifierProvider<ConsentNotifier, Consent?>(ConsentNotifier.new);

/// Consent is given on the device (S1, before any account exists) and then
/// recorded in the cloud as:
///   * `users/{uid}.consent` — the current snapshot, read by Cloud Functions
///     (e.g. no push unless `notifications == true`);
///   * `users/{uid}/consentLog/*` — an append-only, versioned history.
class ConsentNotifier extends Notifier<Consent?> {
  static const _key = 'consent';
  static const _syncedKey = 'consentSyncedFor';

  @override
  Consent? build() {
    final store = ref.watch(localStoreProvider);
    final json = store.readMap(_key);
    final consent = json == null ? null : Consent.fromJson(json);

    // First time this consent meets a signed-in account → record it.
    final remote = ref.watch(remoteStoreProvider);
    if (remote != null && consent != null && store.readString(_syncedKey) != _marker(remote.uid, consent)) {
      _record(remote, consent);
    }
    return consent;
  }

  Future<void> save(Consent consent) async {
    state = consent;
    await ref.read(localStoreProvider).write(_key, consent.toJson());
    final remote = ref.read(remoteStoreProvider);
    if (remote != null) _record(remote, consent);
  }

  Future<void> update({bool? diagnosis, bool? modelImprovement, bool? notifications}) async {
    final current = state;
    if (current == null) return;
    await save(
      current.copyWith(diagnosis: diagnosis, modelImprovement: modelImprovement, notifications: notifications),
    );
  }

  void reset() => state = null;

  void _record(RemoteStore remote, Consent consent) {
    final store = ref.read(localStoreProvider);
    unawaited(() async {
      try {
        // Not awaited on the server ack (offline-safe); Firestore queues the writes.
        unawaited(remote.mergeProfile({'consent': consent.toJson()}));
        unawaited(remote.appendConsentLog(consent.toJson()));
        await store.write(_syncedKey, _marker(remote.uid, consent));
      } catch (e) {
        debugPrint('[consent] sync failed: $e');
      }
    }());
  }

  static String _marker(String uid, Consent c) => '$uid|${c.version}|${c.acceptedAt.toIso8601String()}';
}
