import 'dart:async';
import 'dart:convert';

import 'package:autosense/core/firebase/remote_store.dart';
import 'package:autosense/core/storage/local_store.dart';
import 'package:autosense/features/auth/data/auth_repository.dart';
import 'package:autosense/features/onboarding/data/consent_repository.dart';
import 'package:autosense/features/onboarding/domain/consent.dart';
import 'package:autosense/features/vehicle/data/vehicle_repository.dart';
import 'package:autosense/features/vehicle/domain/vehicle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRemoteStore implements RemoteStore {
  FakeRemoteStore(this.uid);

  @override
  final String uid;
  final controllers = <String, StreamController<RemoteSnapshot>>{};
  final puts = <String, Map<String, dynamic>>{};
  final removed = <String>[];
  final profile = <String, dynamic>{};
  final consentLog = <Map<String, dynamic>>[];

  StreamController<RemoteSnapshot> _c(String collection) =>
      controllers.putIfAbsent(collection, StreamController<RemoteSnapshot>.broadcast);

  void emit(String collection, List<Map<String, dynamic>> docs, {bool fromCache = false}) =>
      _c(collection).add(RemoteSnapshot(docs, fromCache: fromCache));

  @override
  Stream<RemoteSnapshot> watch(String collection) => _c(collection).stream;
  @override
  Future<void> put(String collection, String id, Map<String, dynamic> data) async => puts['$collection/$id'] = data;
  @override
  Future<void> remove(String collection, String id) async => removed.add('$collection/$id');
  @override
  Future<void> mergeProfile(Map<String, dynamic> data) async => profile.addAll(data);
  @override
  Future<void> appendConsentLog(Map<String, dynamic> consent) async => consentLog.add(consent);
  @override
  Future<void> deleteAll() async {}
}

Vehicle _vehicle(String id, {int km = 100000}) => Vehicle(
  id: id,
  make: 'Dacia',
  model: 'Duster',
  year: 2019,
  engine: '1.5 dCi',
  fuel: FuelType.diesel,
  transmission: Transmission.manual,
  mileageKm: km,
);

Future<ProviderContainer> _container({Map<String, Object> prefs = const {}, RemoteStore? remote}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp), remoteStoreProvider.overrideWithValue(remote)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('local-only mode: writes go to the cache only', () async {
    final c = await _container();
    await c.read(vehiclesProvider.notifier).add(_vehicle('x'));
    expect(c.read(vehiclesProvider), hasLength(1));
    expect(c.read(localStoreProvider).readList('vehicles'), hasLength(1));
  });

  test('remote snapshot becomes the source of truth and refreshes the cache', () async {
    final remote = FakeRemoteStore('u1');
    final c = await _container(remote: remote);
    c.listen(vehiclesProvider, (_, _) {});

    remote.emit('vehicles', [_vehicle('a').toJson(), _vehicle('b').toJson()]);
    await _flush();

    expect(c.read(vehiclesProvider).map((v) => v.id), ['a', 'b']);
    expect(c.read(localStoreProvider).readList('vehicles'), hasLength(2));
  });

  test('an empty cached snapshot (offline) does not wipe local data', () async {
    final remote = FakeRemoteStore('u1');
    final c = await _container(prefs: {'vehicles': '[${_jsonOf(_vehicle('a'))}]', 'cacheOwner': 'u1'}, remote: remote);
    c.listen(vehiclesProvider, (_, _) {});

    remote.emit('vehicles', [], fromCache: true);
    await _flush();

    expect(c.read(vehiclesProvider), hasLength(1));
  });

  test('data created before first sign-in is uploaded once the server is empty', () async {
    final remote = FakeRemoteStore('u1');
    final c = await _container(prefs: {'vehicles': '[${_jsonOf(_vehicle('a'))}]'}, remote: remote);
    c.listen(vehiclesProvider, (_, _) {});

    remote.emit('vehicles', []);
    await _flush();

    expect(remote.puts.keys, ['vehicles/a']);
  });

  test('another user\'s cache is never uploaded into this account', () async {
    final remote = FakeRemoteStore('u2');
    final c = await _container(prefs: {'vehicles': '[${_jsonOf(_vehicle('a'))}]', 'cacheOwner': 'u1'}, remote: remote);
    c.listen(vehiclesProvider, (_, _) {});

    remote.emit('vehicles', []);
    await _flush();

    expect(remote.puts, isEmpty);
    expect(c.read(vehiclesProvider), isEmpty);
  });

  test('writes are optimistic and also sent to the cloud', () async {
    final remote = FakeRemoteStore('u1');
    final c = await _container(remote: remote);
    final v = await c.read(vehiclesProvider.notifier).add(_vehicle('ignored'));
    await c.read(vehiclesProvider.notifier).updateMileage(v.id, 120000);
    await _flush();

    expect(c.read(vehiclesProvider).single.mileageKm, 120000);
    expect(remote.puts['vehicles/${v.id}']?['mileageKm'], 120000);

    await c.read(vehiclesProvider.notifier).remove(v.id);
    await _flush();
    expect(remote.removed, ['vehicles/${v.id}']);
  });

  test('consent is snapshotted on the profile and appended to the log', () async {
    final remote = FakeRemoteStore('u1');
    final c = await _container(remote: remote);
    await c
        .read(consentProvider.notifier)
        .save(
          Consent(
            version: Consent.currentVersion,
            acceptedAt: DateTime(2026, 11, 12),
            diagnosis: true,
            modelImprovement: false,
            notifications: true,
          ),
        );
    await c.read(consentProvider.notifier).update(notifications: false);
    await _flush();

    expect((remote.profile['consent'] as Map)['notifications'], isFalse);
    expect(remote.consentLog, hasLength(2));
  });

  test('auth error codes map to Turkish messages', () {
    expect(FirebaseAuthRepository.messageFor('wrong-password'), 'E-posta veya şifre hatalı.');
    expect(FirebaseAuthRepository.messageFor('weak-password'), contains('6 karakter'));
    expect(FirebaseAuthRepository.messageFor('xyz'), contains('xyz'));
  });
}

String _jsonOf(Vehicle v) => jsonEncode(v.toJson());
