enum FuelType {
  gasoline('Benzin'),
  diesel('Dizel'),
  lpg('LPG'),
  hybrid('Hibrit');

  const FuelType(this.label);
  final String label;
}

enum Transmission {
  manual('Manuel'),
  automatic('Otomatik');

  const Transmission(this.label);
  final String label;
}

/// A completed maintenance item entered by the user.
class ServiceEntry {
  const ServiceEntry({required this.itemId, required this.date, required this.mileageKm});

  final String itemId;
  final DateTime date;
  final int mileageKm;

  Map<String, dynamic> toJson() => {'itemId': itemId, 'date': date.toIso8601String(), 'mileageKm': mileageKm};
  factory ServiceEntry.fromJson(Map<String, dynamic> j) => ServiceEntry(
    itemId: j['itemId'] as String,
    date: DateTime.parse(j['date'] as String),
    mileageKm: (j['mileageKm'] as num).toInt(),
  );
}

/// Vehicle profile (S2). VIN, plate and location are never collected (KVKK).
class Vehicle {
  const Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.engine,
    required this.fuel,
    required this.transmission,
    required this.mileageKm,
    this.services = const [],
  });

  final String id;
  final String make;
  final String model;
  final int year;
  final String engine;
  final FuelType fuel;
  final Transmission transmission;
  final int mileageKm;
  final List<ServiceEntry> services;

  String get displayName => '$make $model';
  String get subtitle => '$year · $engine · ${transmission.label}';

  /// Most recent service entry for [itemId], by mileage.
  ServiceEntry? lastServiceFor(String itemId) {
    ServiceEntry? best;
    for (final s in services.where((s) => s.itemId == itemId)) {
      if (best == null || s.mileageKm > best.mileageKm) best = s;
    }
    return best;
  }

  Vehicle copyWith({
    String? make,
    String? model,
    int? year,
    String? engine,
    FuelType? fuel,
    Transmission? transmission,
    int? mileageKm,
    List<ServiceEntry>? services,
  }) => Vehicle(
    id: id,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year ?? this.year,
    engine: engine ?? this.engine,
    fuel: fuel ?? this.fuel,
    transmission: transmission ?? this.transmission,
    mileageKm: mileageKm ?? this.mileageKm,
    services: services ?? this.services,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'make': make,
    'model': model,
    'year': year,
    'engine': engine,
    'fuel': fuel.name,
    'transmission': transmission.name,
    'mileageKm': mileageKm,
    'services': services.map((s) => s.toJson()).toList(),
  };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    id: j['id'] as String,
    make: j['make'] as String,
    model: j['model'] as String,
    year: (j['year'] as num).toInt(),
    engine: j['engine'] as String,
    fuel: FuelType.values.byName(j['fuel'] as String),
    transmission: Transmission.values.byName(j['transmission'] as String),
    mileageKm: (j['mileageKm'] as num).toInt(),
    services: (j['services'] as List? ?? [])
        .map((e) => ServiceEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
