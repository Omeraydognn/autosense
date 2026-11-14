import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase client options for project `autosense-team44`.
///
/// The API keys are **not** in the repository. They are passed at build time:
///
///     flutter run --dart-define-from-file=firebase.env.json
///
/// `firebase.env.json` is git-ignored; copy `firebase.env.example.json` and
/// fill in the keys from the Firebase console (Project settings → Your apps).
/// Without a key the app runs in local-only mode.
abstract final class FirebaseConfig {
  static const _project = 'autosense-team44';
  static const _sender = '415608366788';
  static const _bucket = 'autosense-team44.firebasestorage.app';

  static const _webKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _androidKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _iosKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');

  /// Options for the current platform, or null when no key was provided
  /// (or the platform is not configured).
  static FirebaseOptions? forCurrentPlatform({bool emulators = false}) {
    String key(String value) => value.isEmpty && emulators ? 'emulator-api-key' : value;

    final FirebaseOptions options;
    if (kIsWeb) {
      options = FirebaseOptions(
        apiKey: key(_webKey),
        appId: '1:$_sender:web:579bc38991ab175b380b91',
        messagingSenderId: _sender,
        projectId: _project,
        authDomain: '$_project.firebaseapp.com',
        storageBucket: _bucket,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      options = FirebaseOptions(
        apiKey: key(_androidKey),
        appId: '1:$_sender:android:58c8c21b5d8e331a380b91',
        messagingSenderId: _sender,
        projectId: _project,
        storageBucket: _bucket,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      options = FirebaseOptions(
        apiKey: key(_iosKey),
        appId: '1:$_sender:ios:52e27d023ec4bc65380b91',
        messagingSenderId: _sender,
        projectId: _project,
        storageBucket: _bucket,
        iosBundleId: 'com.team44.autosense',
      );
    } else {
      return null;
    }
    return options.apiKey.isEmpty ? null : options;
  }
}
