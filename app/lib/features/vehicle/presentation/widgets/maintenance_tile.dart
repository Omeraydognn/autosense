import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/maintenance.dart';

extension DueStateStyle on DueState {
  Color color(ColorScheme scheme) => switch (this) {
    DueState.ok => AppColors.u1,
    DueState.dueSoon => AppColors.u2,
    DueState.overdue => AppColors.u3,
    DueState.noRecord => scheme.onSurfaceVariant,
  };
}

class MaintenanceTile extends StatelessWidget {
  const MaintenanceTile({super.key, required this.status, this.onTap});

  final MaintenanceStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = status.state.color(scheme);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        child: Row(
          children: [
            IconTile(icon: status.spec.icon, color: color, size: 40),
            const Gap(Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(status.spec.title, style: t.titleSmall)),
                      Pill(status.state.label, color: color),
                    ],
                  ),
                  const Gap(4),
                  Text(
                    status.describe((km) => Fmt.km(km)),
                    style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (status.state != DueState.noRecord) ...[
                    const Gap(Space.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: status.progress,
                        minHeight: 4,
                        color: color,
                        backgroundColor: scheme.surfaceContainerHigh,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
