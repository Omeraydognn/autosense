import 'package:autosense/features/vehicle/domain/maintenance.dart';
import 'package:autosense/features/vehicle/domain/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oil = MaintenanceSpec(
    id: 'engine_oil',
    title: 'Motor yağı',
    icon: Icons.oil_barrel,
    intervalKm: 15000,
    intervalMonths: 12,
  );
  final now = DateTime(2026, 11, 12);

  Vehicle vehicle({required int km, List<ServiceEntry> services = const []}) => Vehicle(
    id: 'v1',
    make: 'Fiat',
    model: 'Egea',
    year: 2018,
    engine: '1.3 Multijet',
    fuel: FuelType.diesel,
    transmission: Transmission.manual,
    mileageKm: km,
    services: services,
  );

  MaintenanceStatus statusFor(Vehicle v) => MaintenanceCalculator.compute(v, specs: const [oil], now: now).single;

  test('no service entry → noRecord', () {
    expect(statusFor(vehicle(km: 100000)).state, DueState.noRecord);
  });

  test('well within interval → ok with remaining km and days', () {
    final s = statusFor(
      vehicle(
        km: 105000,
        services: [ServiceEntry(itemId: 'engine_oil', date: DateTime(2026, 6, 1), mileageKm: 100000)],
      ),
    );
    expect(s.state, DueState.ok);
    expect(s.remainingKm, 10000);
    expect(s.remainingDays, DateTime(2027, 6, 1).difference(now).inDays);
    // Progress is the larger of distance used (5k/15k) and time used (164/365 days).
    expect(s.progress, closeTo(164 / 365, 0.01));
  });

  test('within 1,500 km window → dueSoon and reminder mentions km', () {
    final s = statusFor(
      vehicle(
        km: 113800,
        services: [ServiceEntry(itemId: 'engine_oil', date: DateTime(2026, 9, 1), mileageKm: 100000)],
      ),
    );
    expect(s.state, DueState.dueSoon);
    expect(s.remainingKm, 1200);
    expect(MaintenanceCalculator.reminderText(s), contains('1200 km'));
  });

  test('time interval alone can make an item due', () {
    final s = statusFor(
      vehicle(
        km: 101000,
        services: [ServiceEntry(itemId: 'engine_oil', date: DateTime(2025, 11, 30), mileageKm: 100000)],
      ),
    );
    expect(s.state, DueState.dueSoon);
    expect(s.remainingDays, 18);
  });

  test('past interval → overdue, sorted first', () {
    const filter = MaintenanceSpec(id: 'air_filter', title: 'Hava filtresi', icon: Icons.air, intervalKm: 30000);
    final v = vehicle(
      km: 120000,
      services: [
        ServiceEntry(itemId: 'engine_oil', date: DateTime(2026, 1, 1), mileageKm: 100000),
        ServiceEntry(itemId: 'air_filter', date: DateTime(2026, 1, 1), mileageKm: 110000),
      ],
    );
    final list = MaintenanceCalculator.compute(v, specs: const [filter, oil], now: now);
    expect(list.first.spec.id, 'engine_oil');
    expect(list.first.state, DueState.overdue);
    expect(list.first.progress, 1.0);
  });

  test('uses the most recent entry per item', () {
    final s = statusFor(
      vehicle(
        km: 131000,
        services: [
          ServiceEntry(itemId: 'engine_oil', date: DateTime(2025, 1, 1), mileageKm: 100000),
          ServiceEntry(itemId: 'engine_oil', date: DateTime(2026, 10, 1), mileageKm: 130000),
        ],
      ),
    );
    expect(s.remainingKm, 14000);
    expect(s.state, DueState.ok);
  });
}
