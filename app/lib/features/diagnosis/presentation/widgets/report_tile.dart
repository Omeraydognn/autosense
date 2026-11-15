import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/urgency_badge.dart';
import '../../domain/report.dart';

class ReportTile extends StatelessWidget {
  const ReportTile({super.key, required this.report});
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sources = [
      if (report.audio != null) Icons.mic_rounded,
      if (report.telltales.isNotEmpty) Icons.photo_camera_rounded,
    ];
    return AppCard(
      onTap: () => context.push('/report/${report.id}'),
      padding: const EdgeInsets.all(Space.md + 2),
      child: Row(
        children: [
          IconTile(icon: report.urgency.icon, color: report.urgency.color, size: 44),
          const Gap(Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.headline, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const Gap(2),
                Row(
                  children: [
                    for (final i in sources) ...[Icon(i, size: 13, color: scheme.onSurfaceVariant), const Gap(4)],
                    Flexible(
                      child: Text(
                        '${report.vehicleName} · ${Fmt.relative(report.createdAt)}',
                        style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(Space.sm),
          UrgencyBadge(report.urgency, compact: true),
        ],
      ),
    );
  }
}
