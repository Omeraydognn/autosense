import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/remote_store.dart';
import 'local_store.dart';

/// A list kept in sync between the on-device cache and the user's Firestore
/// collection.
///
/// * The cache is returned immediately, so the UI never waits for the network.
/// * Firestore snapshots then become the source of truth.
/// * Writes are optimistic: state + cache first, cloud second.
/// * Data created before the first sign-in (on this device, by nobody else)
///   is uploaded once the server confirms the cloud collection is empty.
abstract class SyncedListNotifier<T> extends Notifier<List<T>> {
  String get collection;
  String get cacheKey => collection;

  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(T item);
  String idOf(T item);

  /// Optional ordering applied to every state update.
  List<T> sort(List<T> items) => items;

  RemoteStore? _remote;

  @protected
  RemoteStore? get remote => _remote;

  @override
  List<T> build() {
    final cache = ref.watch(localStoreProvider);
    final remote = _remote = ref.watch(remoteStoreProvider);

    // Decide ownership *before* anything claims the cache for this user.
    final ownCache = remote == null || cache.cacheBelongsTo(remote.uid);
    final local = ownCache ? sort(cache.readList(cacheKey).map(fromJson).toList()) : <T>[];

    if (remote != null) {
      var migrated = false;
      final sub = remote.watch(collection).listen((snap) async {
        if (snap.fromCache && snap.docs.isEmpty) return; // keep cache until the server answers
        if (!snap.fromCache) await cache.claimCache(remote.uid);
        if (ownCache && !migrated && !snap.fromCache && snap.docs.isEmpty && state.isNotEmpty) {
          migrated = true;
          for (final item in state) {
            _send(remote.put(collection, idOf(item), toJson(item)));
          }
          return;
        }
        state = sort(snap.docs.map(fromJson).toList());
        await _persistCache();
      }, onError: (Object e) => debugPrint('[sync:$collection] $e'));
      ref.onDispose(sub.cancel);
    }
    return local;
  }

  @protected
  Future<void> upsert(T item) async {
    final id = idOf(item);
    final exists = state.any((e) => idOf(e) == id);
    state = sort(exists ? [for (final e in state) idOf(e) == id ? item : e] : [...state, item]);
    await _persistCache();
    final remote = _remote;
    if (remote != null) _send(remote.put(collection, id, toJson(item)));
  }

  @protected
  Future<void> removeById(String id) async {
    state = state.where((e) => idOf(e) != id).toList();
    await _persistCache();
    final remote = _remote;
    if (remote != null) _send(remote.remove(collection, id));
  }

  /// Cloud writes are fire-and-forget: offline, Firestore queues them and the
  /// returned future only completes once the server acknowledges.
  void _send(Future<void> write) =>
      unawaited(write.catchError((Object e) => debugPrint('[sync:$collection] write failed: $e')));

  Future<void> _persistCache() => ref.read(localStoreProvider).write(cacheKey, state.map(toJson).toList());
}
