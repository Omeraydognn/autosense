import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import 'firebase_bootstrap.dart';

class RemoteSnapshot {
  const RemoteSnapshot(this.docs, {required this.fromCache});
  final List<Map<String, dynamic>> docs;

  /// True while Firestore has not yet heard from the server.
  final bool fromCache;
}

/// Per-user cloud storage. All paths live under `users/{uid}/`, matching
/// `firestore.rules`. Null when Firebase is unavailable or nobody is signed in.
abstract interface class RemoteStore {
  String get uid;
  Stream<RemoteSnapshot> watch(String collection);
  Future<void> put(String collection, String id, Map<String, dynamic> data);
  Future<void> remove(String collection, String id);
  Future<void> mergeProfile(Map<String, dynamic> data);
  Future<void> appendConsentLog(Map<String, dynamic> consent);

  /// KVKK Art. 11 — erase every document this user owns.
  Future<void> deleteAll();
}

final remoteStoreProvider = Provider<RemoteStore?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return null;
  final user = ref.watch(authStateProvider);
  if (user == null || user.isLocal) return null;
  return FirestoreRemoteStore(FirebaseFirestore.instance, user.uid);
});

class FirestoreRemoteStore implements RemoteStore {
  FirestoreRemoteStore(this._db, this.uid);

  final FirebaseFirestore _db;
  @override
  final String uid;

  static const userCollections = ['vehicles', 'reports', 'consentLog', 'devices'];

  DocumentReference<Map<String, dynamic>> get _user => _db.collection('users').doc(uid);

  @override
  Stream<RemoteSnapshot> watch(String collection) => _user
      .collection(collection)
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) => RemoteSnapshot(
          s.docs.map((d) => Map<String, dynamic>.from(d.data())..remove('updatedAt')).toList(),
          fromCache: s.metadata.isFromCache,
        ),
      );

  @override
  Future<void> put(String collection, String id, Map<String, dynamic> data) =>
      _user.collection(collection).doc(id).set({...data, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> remove(String collection, String id) => _user.collection(collection).doc(id).delete();

  @override
  Future<void> mergeProfile(Map<String, dynamic> data) =>
      _user.set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  @override
  Future<void> appendConsentLog(Map<String, dynamic> consent) => _user.collection('consentLog').add(consent);

  @override
  Future<void> deleteAll() async {
    for (final c in userCollections) {
      final docs = await _user.collection(c).get();
      // Batches are limited to 500 writes.
      for (var i = 0; i < docs.docs.length; i += 450) {
        final batch = _db.batch();
        for (final d in docs.docs.skip(i).take(450)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await _user.delete();
  }
}
