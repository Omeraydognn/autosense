import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/maintenance.dart';
import '../../domain/vehicle.dart';

Future<void> showMileageSheet(BuildContext context, Vehicle vehicle) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _MileageSheet(vehicle: vehicle),
);

Future<void> showAddServiceSheet(BuildContext context, Vehicle vehicle, {String? itemId}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _AddServiceSheet(vehicle: vehicle, initialItemId: itemId),
);

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: t.titleLarge),
          const Gap(4),
          Text(subtitle, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Gap(Space.xl),
          ...children,
        ],
      ),
    );
  }
}

class _MileageSheet extends ConsumerStatefulWidget {
  const _MileageSheet({required this.vehicle});
  final Vehicle vehicle;

  @override
  ConsumerState<_MileageSheet> createState() => _MileageSheetState();
}

class _MileageSheetState extends ConsumerState<_MileageSheet> {
  late final _ctrl = TextEditingController(text: widget.vehicle.mileageKm.toString());
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final km = int.tryParse(_ctrl.text);
    if (km == null || km < widget.vehicle.mileageKm) {
      setState(() => _error = 'Kilometre ${Fmt.km(widget.vehicle.mileageKm)} değerinden küçük olamaz');
      return;
    }
    await ref.read(vehiclesProvider.notifier).updateMileage(widget.vehicle.id, km);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _SheetScaffold(
    title: 'Kilometreyi güncelle',
    subtitle: 'Bakım hatırlatmaları güncel kilometreye göre hesaplanır.',
    children: [
      TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: 'Güncel kilometre', suffixText: 'km', errorText: _error),
        onSubmitted: (_) => _save(),
      ),
      const Gap(Space.lg),
      FilledButton(onPressed: _save, child: const Text('Kaydet')),
    ],
  );
}

class _AddServiceSheet extends ConsumerStatefulWidget {
  const _AddServiceSheet({required this.vehicle, this.initialItemId});
  final Vehicle vehicle;
  final String? initialItemId;

  @override
  ConsumerState<_AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends ConsumerState<_AddServiceSheet> {
  late String _itemId = widget.initialItemId ?? MaintenanceSpecs.defaults.first.id;
  late final _kmCtrl = TextEditingController(text: widget.vehicle.mileageKm.toString());
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _kmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final km = int.tryParse(_kmCtrl.text);
    if (km == null) return;
    await ref
        .read(vehiclesProvider.notifier)
        .addService(widget.vehicle.id, ServiceEntry(itemId: _itemId, date: _date, mileageKm: km));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _SheetScaffold(
    title: 'Bakım kaydı ekle',
    subtitle: 'Yapılan son bakımı girin; bir sonraki tarih otomatik hesaplanır.',
    children: [
      DropdownButtonFormField<String>(
        borderRadius: BorderRadius.circular(Radii.md),
        initialValue: _itemId,
        decoration: const InputDecoration(labelText: 'Bakım kalemi'),
        items: [
          for (final s in MaintenanceSpecs.defaults)
            DropdownMenuItem(
              value: s.id,
              child: Row(children: [Icon(s.icon, size: 18), const Gap(10), Text(s.title)]),
            ),
        ],
        onChanged: (v) => setState(() => _itemId = v ?? _itemId),
      ),
      const Gap(Space.md),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _kmCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Bakım kilometresi', suffixText: 'km'),
            ),
          ),
          const Gap(Space.md),
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(Radii.md),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tarih',
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(Fmt.date(_date)),
              ),
            ),
          ),
        ],
      ),
      const Gap(Space.xl),
      FilledButton(onPressed: _save, child: const Text('Kaydı ekle')),
    ],
  );
}
