import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

/// `flutter run --dart-define=USE_EMULATORS=true` → local Firebase Emulator Suite.
const useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// reCAPTCHA Enterprise site key for App Check on web (optional).
const appCheckWebKey = String.fromEnvironment('APP_CHECK_WEB_KEY');

/// True when Firebase initialised successfully. Overridden in `main()`;
/// false in tests and before `flutterfire configure` has been run.
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// Initialises Firebase, App Check and (optionally) the emulators.
/// Never throws: on failure the app continues in local-only mode.
Future<bool> initFirebase() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('[firebase] not configured, running local-only: $e');
    return false;
  }

  try {
    if (!kIsWeb || appCheckWebKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: appCheckWebKey.isEmpty ? null : ReCaptchaEnterpriseProvider(appCheckWebKey),
        providerAndroid: kReleaseMode ? const AndroidPlayIntegrityProvider() : const AndroidDebugProvider(),
        providerApple: kReleaseMode
            ? const AppleAppAttestWithDeviceCheckFallbackProvider()
            : const AppleDebugProvider(),
      );
    }
  } catch (e) {
    debugPrint('[firebase] App Check activation failed: $e');
  }

  // Offline cache: Firestore keeps a local copy so the app works without signal.
  // Settings must be applied before the first Firestore call.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  if (useEmulators) {
    final host = defaultTargetPlatform == TargetPlatform.android && !kIsWeb ? '10.0.2.2' : 'localhost';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }
  return true;
}
