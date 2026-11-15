import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_store.dart';
import '../../../core/storage/synced_list_notifier.dart';
import '../domain/maintenance.dart';
import '../domain/vehicle.dart';

final vehiclesProvider = NotifierProvider<VehiclesNotifier, List<Vehicle>>(VehiclesNotifier.new);

final activeVehicleIdProvider = NotifierProvider<ActiveVehicleIdNotifier, String?>(ActiveVehicleIdNotifier.new);

/// The vehicle currently selected in the garage (falls back to the first).
final activeVehicleProvider = Provider<Vehicle?>((ref) {
  final vehicles = ref.watch(vehiclesProvider);
  if (vehicles.isEmpty) return null;
  final id = ref.watch(activeVehicleIdProvider);
  return vehicles.firstWhere((v) => v.id == id, orElse: () => vehicles.first);
});

final maintenanceProvider = Provider.family<List<MaintenanceStatus>, String>((ref, vehicleId) {
  final vehicle = ref.watch(vehiclesProvider).where((v) => v.id == vehicleId).firstOrNull;
  if (vehicle == null) return const [];
  return MaintenanceCalculator.compute(vehicle);
});

class VehiclesNotifier extends SyncedListNotifier<Vehicle> {
  @override
  String get collection => 'vehicles';
  @override
  Vehicle fromJson(Map<String, dynamic> json) => Vehicle.fromJson(json);
  @override
  Map<String, dynamic> toJson(Vehicle item) => item.toJson();
  @override
  String idOf(Vehicle item) => item.id;

  Future<Vehicle> add(Vehicle draft) async {
    final vehicle = Vehicle(
      id: const Uuid().v4(),
      make: draft.make,
      model: draft.model,
      year: draft.year,
      engine: draft.engine,
      fuel: draft.fuel,
      transmission: draft.transmission,
      mileageKm: draft.mileageKm,
      services: draft.services,
    );
    await upsert(vehicle);
    await ref.read(activeVehicleIdProvider.notifier).select(vehicle.id);
    return vehicle;
  }

  Future<void> replace(Vehicle vehicle) => upsert(vehicle);

  Future<void> remove(String id) => removeById(id);

  Future<void> updateMileage(String id, int km) async {
    final v = state.firstWhere((v) => v.id == id);
    await replace(v.copyWith(mileageKm: km));
  }

  Future<void> addService(String id, ServiceEntry entry) async {
    final v = state.firstWhere((v) => v.id == id);
    final mileage = entry.mileageKm > v.mileageKm ? entry.mileageKm : v.mileageKm;
    await replace(v.copyWith(services: [...v.services, entry], mileageKm: mileage));
  }
}

class ActiveVehicleIdNotifier extends Notifier<String?> {
  static const _key = 'activeVehicleId';

  @override
  String? build() => ref.watch(localStoreProvider).readString(_key);

  Future<void> select(String id) async {
    state = id;
    await ref.read(localStoreProvider).write(_key, id);
  }
}
