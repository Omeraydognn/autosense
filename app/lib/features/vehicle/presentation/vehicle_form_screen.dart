import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/navigation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle.dart';
import '../domain/vehicle_catalog.dart';

/// Create / edit a vehicle profile (S2).
class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicleId});
  final String? vehicleId;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  static const _other = 'Diğer';

  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _engineCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _oilKmCtrl = TextEditingController();

  String? _make;
  String? _model;
  String? _engine;
  int _year = DateTime.now().year - 5;
  FuelType _fuel = FuelType.gasoline;
  Transmission _transmission = Transmission.manual;
  Vehicle? _existing;

  bool get _isEdit => _existing != null;
  bool get _isOtherMake => _make == _other;
  CatalogModel? get _catalog =>
      _isOtherMake || _make == null || _model == null ? null : VehicleCatalog.find(_make!, _model!);

  @override
  void initState() {
    super.initState();
    final id = widget.vehicleId;
    if (id == null) return;
    final v = ref.read(vehiclesProvider).where((v) => v.id == id).firstOrNull;
    if (v == null) return;
    _existing = v;
    final inCatalog = VehicleCatalog.find(v.make, v.model);
    if (inCatalog != null) {
      _make = v.make;
      _model = v.model;
      if (inCatalog.engines.contains(v.engine)) {
        _engine = v.engine;
      } else {
        _engine = _other;
        _engineCtrl.text = v.engine;
      }
    } else {
      _make = _other;
      _makeCtrl.text = v.make;
      _modelCtrl.text = v.model;
      _engineCtrl.text = v.engine;
    }
    _year = v.year;
    _fuel = v.fuel;
    _transmission = v.transmission;
    _kmCtrl.text = v.mileageKm.toString();
  }

  @override
  void dispose() {
    for (final c in [_makeCtrl, _modelCtrl, _engineCtrl, _kmCtrl, _oilKmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final make = _isOtherMake ? _makeCtrl.text.trim() : _make!;
    final model = _isOtherMake ? _modelCtrl.text.trim() : _model!;
    final engine = (_isOtherMake || _engine == _other) ? _engineCtrl.text.trim() : _engine!;
    final km = int.parse(_kmCtrl.text);
    final notifier = ref.read(vehiclesProvider.notifier);

    if (_isEdit) {
      await notifier.replace(
        _existing!.copyWith(
          make: make,
          model: model,
          year: _year,
          engine: engine,
          fuel: _fuel,
          transmission: _transmission,
          mileageKm: km,
        ),
      );
    } else {
      final oilKm = int.tryParse(_oilKmCtrl.text);
      await notifier.add(
        Vehicle(
          id: '',
          make: make,
          model: model,
          year: _year,
          engine: engine,
          fuel: _fuel,
          transmission: _transmission,
          mileageKm: km,
          services: [if (oilKm != null) ServiceEntry(itemId: 'engine_oil', date: DateTime.now(), mileageKm: oilKm)],
        ),
      );
    }
    if (mounted) context.popOrGo();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aracı sil?'),
        content: const Text('Araç profili ve bakım kayıtları bu cihazdan silinir. Raporlar geçmişte kalır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(vehiclesProvider.notifier).remove(_existing!.id);
    if (mounted) context.popOrGo();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final models = _make == null || _isOtherMake
        ? <CatalogModel>[]
        : VehicleCatalog.models.where((m) => m.make == _make).toList();
    final engines = _catalog?.engines ?? const <String>[];
    final currentYear = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Aracı düzenle' : 'Araç ekle'),
        actions: [
          if (_isEdit) IconButton(tooltip: 'Sil', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            const InfoBanner(
              icon: Icons.lock_outline_rounded,
              title: 'Plaka, şasi no veya konum istemiyoruz',
              message: 'Teşhis için yalnızca model ve kilometre bilgisi yeterlidir.',
            ),
            const Gap(Space.xl),
            Text('Araç', style: t.titleMedium),
            const Gap(Space.md),
            DropdownButtonFormField<String>(
              borderRadius: BorderRadius.circular(Radii.md),
              initialValue: _make,
              decoration: const InputDecoration(labelText: 'Marka'),
              items: [
                for (final m in VehicleCatalog.makes) DropdownMenuItem(value: m, child: Text(m)),
                const DropdownMenuItem(value: _other, child: Text(_other)),
              ],
              validator: _required,
              onChanged: (v) => setState(() {
                _make = v;
                _model = null;
                _engine = null;
              }),
            ),
            const Gap(Space.md),
            if (_isOtherMake) ...[
              TextFormField(
                controller: _makeCtrl,
                decoration: const InputDecoration(labelText: 'Marka adı'),
                validator: _required,
              ),
              const Gap(Space.md),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(labelText: 'Model'),
                validator: _required,
              ),
              const Gap(Space.md),
              TextFormField(
                controller: _engineCtrl,
                decoration: const InputDecoration(labelText: 'Motor', hintText: 'örn. 1.6 benzinli'),
                validator: _required,
              ),
              const Gap(Space.sm),
              Text(
                'Bu model için kullanım kılavuzu henüz indekslenmedi; raporlarda kılavuz alıntısı olmaz.',
                style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                borderRadius: BorderRadius.circular(Radii.md),
                key: ValueKey('model-$_make'),
                initialValue: _model,
                decoration: const InputDecoration(labelText: 'Model'),
                items: [for (final m in models) DropdownMenuItem(value: m.model, child: Text(m.model))],
                validator: _required,
                onChanged: _make == null
                    ? null
                    : (v) => setState(() {
                        _model = v;
                        _engine = null;
                      }),
              ),
              const Gap(Space.md),
              DropdownButtonFormField<String>(
                borderRadius: BorderRadius.circular(Radii.md),
                key: ValueKey('engine-$_make-$_model'),
                initialValue: _engine,
                decoration: const InputDecoration(labelText: 'Motor'),
                items: [
                  for (final e in engines) DropdownMenuItem(value: e, child: Text(e)),
                  if (_model != null) const DropdownMenuItem(value: _other, child: Text(_other)),
                ],
                validator: _required,
                onChanged: _model == null ? null : (v) => setState(() => _engine = v),
              ),
              if (_engine == _other) ...[
                const Gap(Space.md),
                TextFormField(
                  controller: _engineCtrl,
                  decoration: const InputDecoration(labelText: 'Motor'),
                  validator: _required,
                ),
              ],
            ],
            const Gap(Space.md),
            DropdownButtonFormField<int>(
              borderRadius: BorderRadius.circular(Radii.md),
              initialValue: _year,
              decoration: const InputDecoration(labelText: 'Model yılı'),
              items: [for (var y = currentYear + 1; y >= 1995; y--) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
            const Gap(Space.xl),
            Text('Yakıt', style: t.titleMedium),
            const Gap(Space.md),
            SegmentedButton<FuelType>(
              showSelectedIcon: false,
              segments: [for (final f in FuelType.values) ButtonSegment(value: f, label: Text(f.label))],
              selected: {_fuel},
              onSelectionChanged: (s) => setState(() => _fuel = s.first),
            ),
            const Gap(Space.xl),
            Text('Şanzıman', style: t.titleMedium),
            const Gap(Space.md),
            SegmentedButton<Transmission>(
              showSelectedIcon: false,
              segments: [for (final tr in Transmission.values) ButtonSegment(value: tr, label: Text(tr.label))],
              selected: {_transmission},
              onSelectionChanged: (s) => setState(() => _transmission = s.first),
            ),
            const Gap(Space.xl),
            Text('Kilometre', style: t.titleMedium),
            const Gap(Space.md),
            TextFormField(
              controller: _kmCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Güncel kilometre', suffixText: 'km'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return 'Geçerli bir kilometre girin';
                if (n > 2000000) return 'Değer çok yüksek';
                return null;
              },
            ),
            if (!_isEdit) ...[
              const Gap(Space.md),
              TextFormField(
                controller: _oilKmCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Son yağ değişimi (isteğe bağlı)',
                  suffixText: 'km',
                  helperText: 'Bakım takvimini hemen başlatmak için',
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(onPressed: _save, child: Text(_isEdit ? 'Değişiklikleri kaydet' : 'Aracı kaydet')),
        ),
      ),
    );
  }
}
