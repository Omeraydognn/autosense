import 'package:flutter/material.dart';

/// Engine state the user selects before recording (P0 §3, S3).
enum RecordingState {
  startup('Marş', 'Motoru çalıştırırken kaydedin', Icons.power_settings_new_rounded),
  idle('Rölanti', 'Motor çalışırken, araç dururken', Icons.speed_rounded),
  braking('Frenleme', 'Yavaşça fren yaparken kaydedin', Icons.do_not_step_rounded);

  const RecordingState(this.label, this.hint, this.icon);
  final String label;
  final String hint;
  final IconData icon;
}

/// The nine labelled classes of the Kaggle Car Diagnostics Dataset plus an
/// explicit `unknown` class (Track A).
enum EngineSoundClass {
  normalIdle('normal_idle', 'Normal rölanti', RecordingState.idle, isNormal: true),
  lowOil('low_oil', 'Düşük yağ seviyesi', RecordingState.idle),
  powerSteering('power_steering', 'Hidrolik direksiyon', RecordingState.idle),
  serpentineBelt('serpentine_belt', 'V kayışı (serpantin)', RecordingState.idle),
  normalStartup('normal_startup', 'Normal marş', RecordingState.startup, isNormal: true),
  badIgnition('bad_ignition', 'Ateşleme arızası', RecordingState.startup),
  deadBattery('dead_battery', 'Zayıf / bitik akü', RecordingState.startup),
  normalBrakes('normal_brakes', 'Normal fren', RecordingState.braking, isNormal: true),
  wornBrakes('worn_brakes', 'Aşınmış fren balatası', RecordingState.braking),
  unknown('unknown', 'Belirlenemedi', null);

  const EngineSoundClass(this.id, this.label, this.state, {this.isNormal = false});

  final String id;
  final String label;
  final RecordingState? state;
  final bool isNormal;

  static EngineSoundClass fromId(String id) =>
      values.firstWhere((c) => c.id == id, orElse: () => EngineSoundClass.unknown);

  static List<EngineSoundClass> forState(RecordingState s) => values.where((c) => c.state == s).toList();
}
