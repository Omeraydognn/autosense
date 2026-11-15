import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_bootstrap.dart';

/// Minimal user model the rest of the app depends on (never the SDK type).
class AppUser {
  const AppUser({required this.uid, this.email, required this.isAnonymous, this.isLocal = false});

  final String uid;
  final String? email;
  final bool isAnonymous;

  /// Local-only mode (Firebase not configured): no cloud sync.
  final bool isLocal;

  String get label => isLocal ? 'Yerel mod' : (email ?? 'Misafir');
}

/// User-facing auth failure with a Turkish message.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> authStateChanges();
  Future<void> signInAnonymously();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password);
  Future<void> sendPasswordReset(String email);

  /// Upgrades a guest account to email/password, keeping the same UID and data.
  Future<void> linkWithEmail(String email, String password);
  Future<void> signOut();
  Future<void> deleteAccount();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(firebaseReadyProvider) ? FirebaseAuthRepository(FirebaseAuth.instance) : LocalAuthRepository();
});

/// Synchronous view of the signed-in user, kept up to date from the stream.
final authStateProvider = NotifierProvider<AuthStateNotifier, AppUser?>(AuthStateNotifier.new);

class AuthStateNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.authStateChanges().listen((u) => state = u);
    ref.onDispose(sub.cancel);
    return repo.currentUser;
  }
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);
  final FirebaseAuth _auth;

  static AppUser? _map(User? u) => u == null ? null : AppUser(uid: u.uid, email: u.email, isAnonymous: u.isAnonymous);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_map);

  @override
  Future<void> signInAnonymously() => _guard(() => _auth.signInAnonymously());

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> signUpWithEmail(String email, String password) =>
      _guard(() => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> sendPasswordReset(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> linkWithEmail(String email, String password) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Oturum bulunamadı.');
    return user.linkWithCredential(EmailAuthProvider.credential(email: email.trim(), password: password));
  });

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() => _guard(() async => _auth.currentUser?.delete());

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(messageFor(e.code));
    }
  }

  static String messageFor(String code) => switch (code) {
    'invalid-email' => 'E-posta adresi geçersiz.',
    'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' => 'E-posta veya şifre hatalı.',
    'email-already-in-use' || 'credential-already-in-use' => 'Bu e-posta ile zaten bir hesap var.',
    'weak-password' => 'Şifre en az 6 karakter olmalı.',
    'too-many-requests' => 'Çok fazla deneme yapıldı. Biraz sonra tekrar deneyin.',
    'network-request-failed' => 'İnternet bağlantısı yok.',
    'requires-recent-login' => 'Bu işlem için yeniden giriş yapmanız gerekiyor.',
    'operation-not-allowed' => 'Bu giriş yöntemi Firebase konsolunda etkin değil.',
    _ => 'Bir hata oluştu ($code).',
  };
}

/// Used when Firebase is not configured: a permanent on-device user.
class LocalAuthRepository implements AuthRepository {
  static const _user = AppUser(uid: 'local', isAnonymous: true, isLocal: true);

  @override
  AppUser? get currentUser => _user;
  @override
  Stream<AppUser?> authStateChanges() => const Stream.empty();
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<void> signInWithEmail(String email, String password) => _unsupported();
  @override
  Future<void> signUpWithEmail(String email, String password) => _unsupported();
  @override
  Future<void> sendPasswordReset(String email) => _unsupported();
  @override
  Future<void> linkWithEmail(String email, String password) => _unsupported();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() async {}

  Future<void> _unsupported() async => throw const AuthFailure('Bulut hesabı bu sürümde etkin değil (yerel mod).');
}
