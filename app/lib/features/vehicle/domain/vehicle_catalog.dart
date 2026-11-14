/// Models covered by the MVP RAG corpus (P0 §5). Other vehicles can still be
/// added, but reports will not contain owner's-manual citations.
class CatalogModel {
  const CatalogModel(this.make, this.model, this.engines);
  final String make;
  final String model;
  final List<String> engines;

  String get key => '$make $model';
}

abstract final class VehicleCatalog {
  static const models = <CatalogModel>[
    CatalogModel('Fiat', 'Egea', ['1.3 Multijet', '1.4 Fire', '1.6 Multijet', '1.5 Hybrid']),
    CatalogModel('Renault', 'Clio', ['1.0 TCe', '1.5 dCi', '1.2 16V', '1.6 E-Tech Hybrid']),
    CatalogModel('Toyota', 'Corolla', ['1.33 VVT-i', '1.6 Valvematic', '1.8 Hybrid', '1.5 Dynamic Force']),
    CatalogModel('Hyundai', 'i20', ['1.0 T-GDi', '1.2 MPI', '1.4 CRDi', '1.4 MPI']),
    CatalogModel('Volkswagen', 'Golf', ['1.0 TSI', '1.4 TSI', '1.5 eTSI', '1.6 TDI', '2.0 TDI']),
    CatalogModel('Dacia', 'Duster', ['1.0 TCe', '1.3 TCe', '1.5 dCi', '1.6 SCe']),
  ];

  static List<String> get makes => models.map((m) => m.make).toSet().toList();

  static CatalogModel? find(String make, String model) {
    for (final m in models) {
      if (m.make == make && m.model == model) return m;
    }
    return null;
  }

  static bool hasManual(String make, String model) => find(make, model) != null;
}
