import 'package:flutter/material.dart';

import '../../features/diagnosis/domain/urgency.dart';
import '../theme/app_colors.dart';

extension UrgencyStyle on Urgency {
  Color get color => switch (this) {
    Urgency.u0 => AppColors.u0,
    Urgency.u1 => AppColors.u1,
    Urgency.u2 => AppColors.u2,
    Urgency.u3 => AppColors.u3,
  };

  IconData get icon => switch (this) {
    Urgency.u0 => Icons.info_rounded,
    Urgency.u1 => Icons.event_available_rounded,
    Urgency.u2 => Icons.schedule_rounded,
    Urgency.u3 => Icons.dangerous_rounded,
  };
}

/// Compact colour-coded urgency chip: [U2 · Birkaç gün içinde].
class UrgencyBadge extends StatelessWidget {
  const UrgencyBadge(this.urgency, {super.key, this.compact = false});

  final Urgency urgency;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = urgency.color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(urgency.icon, size: compact ? 13 : 15, color: c),
          const SizedBox(width: 5),
          Text(
            compact ? urgency.code : '${urgency.code} · ${urgency.title}',
            style: t.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
