import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum TelltaleColor {
  red('Kırmızı', AppColors.telltaleRed),
  amber('Sarı / Turuncu', AppColors.telltaleAmber),
  green('Yeşil', AppColors.telltaleGreen),
  blue('Mavi', AppColors.telltaleBlue);

  const TelltaleColor(this.label, this.color);
  final String label;
  final Color color;
}

/// One of the ~20 common ISO 2575 telltales the vision prompt is restricted to.
class TelltaleSpec {
  const TelltaleSpec(this.id, this.name, this.color, this.icon);
  final String id;
  final String name;
  final TelltaleColor color;
  final IconData icon;
}

abstract final class Telltales {
  static const all = <TelltaleSpec>[
    TelltaleSpec('check_engine', 'Motor arıza lambası', TelltaleColor.amber, Icons.engineering_rounded),
    TelltaleSpec('oil_pressure', 'Yağ basıncı', TelltaleColor.red, Icons.oil_barrel_rounded),
    TelltaleSpec('battery', 'Şarj / akü', TelltaleColor.red, Icons.battery_alert_rounded),
    TelltaleSpec('coolant_temp', 'Motor hararet', TelltaleColor.red, Icons.thermostat_rounded),
    TelltaleSpec('brake_system', 'Fren sistemi', TelltaleColor.red, Icons.error_outline_rounded),
    TelltaleSpec('abs', 'ABS', TelltaleColor.amber, Icons.album_outlined),
    TelltaleSpec('airbag', 'Hava yastığı', TelltaleColor.red, Icons.airline_seat_recline_extra_rounded),
    TelltaleSpec('tpms', 'Lastik basıncı', TelltaleColor.amber, Icons.tire_repair_rounded),
    TelltaleSpec('esp', 'ESP / denge kontrol', TelltaleColor.amber, Icons.swap_calls_rounded),
    TelltaleSpec('glow_plug', 'Kızdırma bujisi', TelltaleColor.amber, Icons.whatshot_rounded),
    TelltaleSpec('eps', 'Elektrikli direksiyon', TelltaleColor.red, Icons.trip_origin_rounded),
    TelltaleSpec('seatbelt', 'Emniyet kemeri', TelltaleColor.red, Icons.event_seat_rounded),
    TelltaleSpec('door_open', 'Kapı açık', TelltaleColor.red, Icons.sensor_door_outlined),
    TelltaleSpec('low_fuel', 'Düşük yakıt', TelltaleColor.amber, Icons.local_gas_station_rounded),
    TelltaleSpec('dpf', 'Partikül filtresi (DPF)', TelltaleColor.amber, Icons.filter_alt_rounded),
    TelltaleSpec('service_due', 'Servis zamanı', TelltaleColor.amber, Icons.build_circle_outlined),
    TelltaleSpec('transmission', 'Şanzıman', TelltaleColor.amber, Icons.settings_rounded),
    TelltaleSpec('parking_brake', 'El freni', TelltaleColor.red, Icons.local_parking_rounded),
    TelltaleSpec('washer_fluid', 'Cam suyu', TelltaleColor.amber, Icons.water_drop_outlined),
    TelltaleSpec('high_beam', 'Uzun far', TelltaleColor.blue, Icons.highlight_rounded),
  ];

  static TelltaleSpec? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}
