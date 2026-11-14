import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore(ref.watch(sharedPreferencesProvider)));

/// Thin JSON wrapper over SharedPreferences. Acts as the offline cache; the
/// Firestore-backed repositories will replace it as the source of truth.
class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  static const keys = ['consent', 'vehicles', 'activeVehicleId', 'reports', 'consentSyncedFor', _ownerKey];

  /// User-data caches cleared on sign-out (consent stays: it belongs to the device owner).
  static const userDataKeys = ['vehicles', 'activeVehicleId', 'reports', 'consentSyncedFor', _ownerKey];

  static const _ownerKey = 'cacheOwner';

  Map<String, dynamic>? readMap(String key) {
    final raw = _prefs.getString(key);
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  String? readString(String key) => _prefs.getString(key);

  Future<void> write(String key, Object? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else {
      await _prefs.setString(key, jsonEncode(value));
    }
  }

  /// KVKK Art. 11 — full export of everything stored on this device.
  Map<String, dynamic> exportAll() => {
    for (final k in keys)
      if (_prefs.getString(k) != null) k: _tryDecode(_prefs.getString(k)!),
  };

  /// Cached data may be uploaded to [uid]'s account only if it was created
  /// offline before any sign-in, or by that same user.
  bool cacheBelongsTo(String uid) {
    final owner = _prefs.getString(_ownerKey);
    return owner == null || owner == uid;
  }

  Future<void> claimCache(String uid) => _prefs.setString(_ownerKey, uid);

  Future<void> clearUserData() async {
    for (final k in userDataKeys) {
      await _prefs.remove(k);
    }
  }

  Future<void> clearAll() async {
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  static Object? _tryDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return s;
    }
  }
}
