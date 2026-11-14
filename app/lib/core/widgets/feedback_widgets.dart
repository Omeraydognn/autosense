import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_card.dart';

/// Horizontal confidence/likelihood bar with label and percentage.
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({super.key, required this.value, required this.color, this.label, this.dense = false});

  final double value;
  final Color color;
  final String? label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text(label!, style: dense ? t.bodySmall : t.bodyMedium)),
                Text(
                  '%${(value * 100).round()}',
                  style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: v,
              minHeight: dense ? 5 : 7,
              color: color,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
        ),
      ],
    );
  }
}

enum BannerTone { info, warning, danger, success }

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.title, this.message, this.icon, this.tone = BannerTone.info});

  final String title;
  final String? message;
  final IconData? icon;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final color = switch (tone) {
      BannerTone.info => scheme.primary,
      BannerTone.warning => const Color(0xFFF59E0B),
      BannerTone.danger => scheme.error,
      BannerTone.success => const Color(0xFF16A34A),
    };
    final defaultIcon = switch (tone) {
      BannerTone.info => Icons.info_outline_rounded,
      BannerTone.warning => Icons.warning_amber_rounded,
      BannerTone.danger => Icons.report_gmailerrorred_rounded,
      BannerTone.success => Icons.check_circle_outline_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(Space.md + 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: color, size: 22),
          const Gap(Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                if (message != null) ...[
                  const Gap(2),
                  Text(message!, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon: icon, color: scheme.primary, size: 72),
            const Gap(Space.xl),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            const Gap(Space.sm),
            Text(
              message,
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const Gap(Space.xl), action!],
          ],
        ),
      ),
    );
  }
}
