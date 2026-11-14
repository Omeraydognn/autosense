import 'package:flutter/material.dart';

import 'vehicle.dart';

/// A maintenance item with a manufacturer interval (Light Track, P0 §4).
class MaintenanceSpec {
  const MaintenanceSpec({
    required this.id,
    required this.title,
    required this.icon,
    this.intervalKm,
    this.intervalMonths,
  }) : assert(intervalKm != null || intervalMonths != null);

  final String id;
  final String title;
  final IconData icon;
  final int? intervalKm;
  final int? intervalMonths;
}

/// Generic intervals. TODO(backend): replace per make/model with values
/// extracted from the owner's manuals in the RAG corpus.
abstract final class MaintenanceSpecs {
  static const defaults = <MaintenanceSpec>[
    MaintenanceSpec(
      id: 'engine_oil',
      title: 'Motor yağı ve filtre',
      icon: Icons.oil_barrel_rounded,
      intervalKm: 15000,
      intervalMonths: 12,
    ),
    MaintenanceSpec(
      id: 'air_filter',
      title: 'Hava filtresi',
      icon: Icons.air_rounded,
      intervalKm: 30000,
      intervalMonths: 24,
    ),
    MaintenanceSpec(
      id: 'cabin_filter',
      title: 'Polen filtresi',
      icon: Icons.filter_vintage_rounded,
      intervalKm: 15000,
      intervalMonths: 12,
    ),
    MaintenanceSpec(id: 'brake_fluid', title: 'Fren hidroliği', icon: Icons.water_drop_rounded, intervalMonths: 24),
    MaintenanceSpec(
      id: 'spark_plugs',
      title: 'Bujiler',
      icon: Icons.bolt_rounded,
      intervalKm: 60000,
      intervalMonths: 48,
    ),
    MaintenanceSpec(
      id: 'coolant',
      title: 'Antifriz',
      icon: Icons.ac_unit_rounded,
      intervalKm: 60000,
      intervalMonths: 48,
    ),
    MaintenanceSpec(
      id: 'timing_belt',
      title: 'Triger kayışı seti',
      icon: Icons.settings_input_component_rounded,
      intervalKm: 120000,
      intervalMonths: 72,
    ),
  ];

  static MaintenanceSpec? byId(String id) {
    for (final s in defaults) {
      if (s.id == id) return s;
    }
    return null;
  }
}

enum DueState {
  ok('Zamanı var'),
  dueSoon('Yaklaşıyor'),
  overdue('Gecikti'),
  noRecord('Kayıt yok');

  const DueState(this.label);
  final String label;
}

class MaintenanceStatus {
  const MaintenanceStatus({
    required this.spec,
    required this.state,
    this.remainingKm,
    this.remainingDays,
    this.progress = 0,
  });

  final MaintenanceSpec spec;
  final DueState state;
  final int? remainingKm;
  final int? remainingDays;

  /// 0 = just serviced, 1 = due now (clamped).
  final double progress;

  /// Human-readable remaining text, e.g. "≈1.200 km" or "45 gün".
  String describe(String Function(int) formatKm) {
    if (state == DueState.noRecord) return 'Son bakım kaydını ekleyin';
    final parts = <String>[];
    if (remainingKm != null) {
      parts.add(remainingKm! >= 0 ? '≈${formatKm(remainingKm!)} kaldı' : '${formatKm(-remainingKm!)} geçti');
    }
    if (remainingDays != null) {
      parts.add(remainingDays! >= 0 ? '${remainingDays!} gün' : '${-remainingDays!} gün gecikme');
    }
    return parts.join(' · ');
  }
}

/// Pure, deterministic calculation — no model involved.
abstract final class MaintenanceCalculator {
  /// Item enters its due window within this distance or time.
  static const dueWindowKm = 1500;
  static const dueWindowDays = 30;

  static List<MaintenanceStatus> compute(
    Vehicle vehicle, {
    List<MaintenanceSpec> specs = MaintenanceSpecs.defaults,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final list = specs.map((s) => _status(vehicle, s, today)).toList();
    list.sort((a, b) => _rank(a).compareTo(_rank(b)));
    return list;
  }

  static MaintenanceStatus _status(Vehicle v, MaintenanceSpec spec, DateTime now) {
    final last = v.lastServiceFor(spec.id);
    if (last == null) {
      return MaintenanceStatus(spec: spec, state: DueState.noRecord);
    }

    int? remainingKm;
    double kmProgress = 0;
    if (spec.intervalKm != null) {
      final used = v.mileageKm - last.mileageKm;
      remainingKm = spec.intervalKm! - used;
      kmProgress = used / spec.intervalKm!;
    }

    int? remainingDays;
    double timeProgress = 0;
    if (spec.intervalMonths != null) {
      final due = _addMonths(last.date, spec.intervalMonths!);
      remainingDays = due.difference(_dateOnly(now)).inDays;
      final total = due.difference(last.date).inDays;
      timeProgress = total == 0 ? 1 : (total - remainingDays) / total;
    }

    final overdue = (remainingKm != null && remainingKm < 0) || (remainingDays != null && remainingDays < 0);
    final soon =
        (remainingKm != null && remainingKm <= dueWindowKm) ||
        (remainingDays != null && remainingDays <= dueWindowDays);

    return MaintenanceStatus(
      spec: spec,
      state: overdue
          ? DueState.overdue
          : soon
          ? DueState.dueSoon
          : DueState.ok,
      remainingKm: remainingKm,
      remainingDays: remainingDays,
      progress: (kmProgress > timeProgress ? kmProgress : timeProgress).clamp(0.0, 1.0),
    );
  }

  /// Push text used by the scheduled `maintenanceCheck()` function.
  static String? reminderText(MaintenanceStatus s) => switch (s.state) {
    DueState.overdue => '${s.spec.title} bakımı gecikti.',
    DueState.dueSoon when s.remainingKm != null && s.remainingKm! <= dueWindowKm =>
      '${s.spec.title} bakımı ${s.remainingKm} km içinde.',
    DueState.dueSoon => '${s.spec.title} bakımı ${s.remainingDays} gün içinde.',
    _ => null,
  };

  static int _rank(MaintenanceStatus s) => switch (s.state) {
    DueState.overdue => 0,
    DueState.dueSoon => 1,
    DueState.ok => 2,
    DueState.noRecord => 3,
  };

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _addMonths(DateTime d, int months) {
    final m = d.month - 1 + months;
    final year = d.year + m ~/ 12;
    final month = m % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
  }
}
