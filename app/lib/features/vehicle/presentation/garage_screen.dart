import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../diagnosis/data/report_repository.dart';
import '../../diagnosis/presentation/widgets/report_tile.dart';
import '../data/vehicle_repository.dart';
import '../domain/maintenance.dart';
import '../domain/vehicle.dart';
import '../domain/vehicle_catalog.dart';
import 'widgets/maintenance_tile.dart';
import 'widgets/vehicle_sheets.dart';

/// S2 — Vehicle Profile & maintenance card.
class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    final active = ref.watch(activeVehicleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garajım'),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const Gap(Space.sm),
        ],
      ),
      body: active == null
          ? EmptyState(
              icon: Icons.directions_car_filled_rounded,
              title: 'Aracınızı ekleyin',
              message:
                  'Marka, model, motor ve kilometre bilgisiyle bakım takvimini ve kılavuz destekli raporları açın.',
              action: FilledButton.icon(
                onPressed: () => context.push('/vehicle/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Araç ekle'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                _VehicleSwitcher(vehicles: vehicles, activeId: active.id),
                const Gap(Space.md),
                _VehicleHero(vehicle: active),
                const Gap(Space.md),
                _DiagnoseCta(onTap: () => context.go('/diagnose')),
                _MaintenanceSection(vehicle: active),
                _RecentReports(vehicleId: active.id),
              ],
            ),
    );
  }
}

class _VehicleSwitcher extends ConsumerWidget {
  const _VehicleSwitcher({required this.vehicles, required this.activeId});
  final List<Vehicle> vehicles;
  final String activeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final v in vehicles)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: ChoiceChip(
                label: Text(v.displayName),
                selected: v.id == activeId,
                onSelected: (_) => ref.read(activeVehicleIdProvider.notifier).select(v.id),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Araç ekle'),
            onPressed: () => context.push('/vehicle/new'),
          ),
        ],
      ),
    );
  }
}

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasManual = VehicleCatalog.hasManual(vehicle.make, vehicle.model);
    const onDark = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111A33), Color(0xFF1E3192), AppColors.brand],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -30,
            child: Icon(Icons.directions_car_filled_rounded, size: 170, color: Colors.white.withValues(alpha: 0.07)),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.lg + 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vehicle.displayName, style: t.headlineSmall?.copyWith(color: onDark)),
                          const Gap(2),
                          Text(vehicle.subtitle, style: t.bodyMedium?.copyWith(color: muted)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Düzenle',
                      style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.14)),
                      onPressed: () => context.push('/vehicle/${vehicle.id}/edit'),
                      icon: const Icon(Icons.edit_outlined, color: onDark, size: 20),
                    ),
                  ],
                ),
                const Gap(Space.xl),
                Text('KİLOMETRE', style: t.labelSmall?.copyWith(color: muted, letterSpacing: 1.2)),
                const Gap(2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.number(vehicle.mileageKm),
                      style: t.displaySmall?.copyWith(
                        color: onDark,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Gap(6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('km', style: t.titleMedium?.copyWith(color: muted)),
                    ),
                  ],
                ),
                const Gap(Space.lg),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    _HeroChip(
                      icon: Icons.speed_rounded,
                      label: 'Km güncelle',
                      onTap: () => showMileageSheet(context, vehicle),
                    ),
                    _HeroChip(
                      icon: hasManual ? Icons.menu_book_rounded : Icons.menu_book_outlined,
                      label: hasManual ? 'Kılavuz destekli' : 'Kılavuz yok',
                    ),
                    _HeroChip(icon: Icons.local_gas_station_outlined, label: vehicle.fuel.label),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: onTap != null ? 0.18 : 0.1),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const Gap(6),
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnoseCta extends StatelessWidget {
  const _DiagnoseCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          const IconTile(icon: Icons.graphic_eq_rounded, color: AppColors.accent, size: 48),
          const Gap(Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yeni teşhis başlat', style: t.titleMedium),
                Text(
                  'Motor sesi kaydedin veya uyarı lambasını çekin',
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _MaintenanceSection extends ConsumerWidget {
  const _MaintenanceSection({required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(maintenanceProvider(vehicle.id));
    final overdue = items.where((i) => i.state == DueState.overdue).length;
    final soon = items.where((i) => i.state == DueState.dueSoon).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Bakım takvimi',
          subtitle: overdue + soon == 0
              ? 'Üretici aralıklarına göre hesaplanır'
              : '${overdue > 0 ? '$overdue gecikmiş · ' : ''}$soon yaklaşan bakım',
          trailing: TextButton.icon(
            onPressed: () => showAddServiceSheet(context, vehicle),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Kayıt ekle'),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                MaintenanceTile(
                  status: items[i],
                  onTap: () => showAddServiceSheet(context, vehicle, itemId: items[i].spec.id),
                ),
                if (i != items.length - 1) const Divider(indent: 72),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentReports extends ConsumerWidget {
  const _RecentReports({required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider).where((r) => r.vehicleId == vehicleId).take(2).toList();
    if (reports.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Son raporlar',
          trailing: TextButton(onPressed: () => context.go('/history'), child: const Text('Tümü')),
        ),
        for (final r in reports)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: ReportTile(report: r),
          ),
      ],
    );
  }
}
