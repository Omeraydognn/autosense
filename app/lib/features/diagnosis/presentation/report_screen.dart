import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/navigation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/urgency_badge.dart';
import '../data/report_repository.dart';
import '../domain/guardrails.dart';
import '../domain/report.dart';
import '../domain/telltales.dart';
import '../domain/urgency.dart';

/// S4 — Diagnostic Report.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportByIdProvider(reportId));
    if (report == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Rapor bulunamadı',
          message: 'Bu rapor silinmiş olabilir.',
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Teşhis raporu'),
            actions: [
              IconButton(
                tooltip: 'Raporu sil',
                onPressed: () async {
                  await ref.read(reportsProvider.notifier).remove(report.id);
                  if (context.mounted) context.popOrGo();
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            sliver: SliverList.list(
              children: [
                _UrgencyHero(report: report),
                if (report.guardrailApplied) ...[
                  const Gap(Space.md),
                  const InfoBanner(
                    tone: BannerTone.danger,
                    icon: Icons.shield_rounded,
                    title: 'Güvenlik kuralı uygulandı',
                    message: 'Kırmızı bir uyarı lambası yüksek güvenle algılandığı için aciliyet U3\'e yükseltildi.',
                  ),
                ],
                if (report.lowConfidence) ...[
                  const Gap(Space.md),
                  InfoBanner(
                    tone: BannerTone.warning,
                    title: report.insufficientInfo ? 'Yetersiz bilgi' : 'Düşük güven',
                    message: report.insufficientInfo
                        ? 'Kılavuzda yeterince ilgili bilgi bulunamadı. Sonuçlar yalnızca algılama çıktısına dayanır.'
                        : 'Model bu sonuçtan emin değil. Daha sessiz bir ortamda yeniden kayıt almayı deneyin.',
                  ),
                ],
                _Findings(report: report),
                _Causes(report: report),
                if (report.citations.isNotEmpty) _ManualCard(report: report),
                const Gap(Space.xl),
                FilledButton.icon(
                  onPressed: () => context.push('/report/${report.id}/checklist'),
                  icon: const Icon(Icons.checklist_rounded),
                  label: const Text('Usta için kontrol listesi'),
                ),
                const Gap(Space.lg),
                Text(
                  'AutoSense bir ön-teşhis asistanıdır ve ustanın yerini almaz. Sonuçlar bilgilendirme amaçlıdır.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgencyHero extends StatelessWidget {
  const _UrgencyHero({required this.report});
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final u = report.urgency;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        color: u.color.withValues(alpha: 0.1),
        border: Border.all(color: u.color.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(Space.lg + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UrgencyBadge(u),
              const Spacer(),
              Text(Fmt.dateTime(report.createdAt), style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const Gap(Space.lg),
          Text(report.headline, style: t.headlineSmall),
          const Gap(4),
          Text(report.vehicleName, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const Gap(Space.lg),
          _UrgencyScale(current: u),
          const Gap(Space.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(u.icon, size: 20, color: u.color),
              const Gap(Space.sm),
              Expanded(
                child: Text(u.advice, style: t.titleSmall?.copyWith(color: u.color)),
              ),
            ],
          ),
          const Gap(Space.sm),
          Text(report.summary, style: t.bodyMedium),
        ],
      ),
    );
  }
}

class _UrgencyScale extends StatelessWidget {
  const _UrgencyScale({required this.current});
  final Urgency current;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final u in Urgency.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: u == Urgency.u3 ? 0 : 4),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: u == current ? 10 : 6,
                    decoration: BoxDecoration(
                      color: u.index <= current.index ? u.color : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const Gap(6),
                  Text(
                    u.code,
                    style: t.labelSmall?.copyWith(
                      fontWeight: u == current ? FontWeight.w800 : FontWeight.w500,
                      color: u == current ? u.color : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Findings extends StatelessWidget {
  const _Findings({required this.report});
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final audio = report.audio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Tespit edilenler', subtitle: 'Algılama katmanının çıktısı'),
        if (audio != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconTile(icon: Icons.graphic_eq_rounded, color: scheme.primary, size: 40),
                    const Gap(Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motor sesi · ${audio.state.label}',
                            style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          Text(audio.label.label, style: t.titleMedium),
                        ],
                      ),
                    ),
                    Text(Fmt.percent(audio.confidence), style: t.titleLarge?.copyWith(color: scheme.primary)),
                  ],
                ),
                const Gap(Space.lg),
                for (final s in audio.topK) ...[
                  ConfidenceBar(
                    value: s.score,
                    label: s.label.label,
                    dense: true,
                    color: s.label == audio.label ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const Gap(Space.sm + 2),
                ],
                Text('YAMNet · cihaz üzerinde', style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        if (audio != null && report.telltales.isNotEmpty) const Gap(Space.md),
        for (final l in report.telltales)
          AppCard(
            child: Row(
              children: [
                IconTile(icon: l.spec?.icon ?? Icons.warning_rounded, color: l.color.color, size: 40),
                const Gap(Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uyarı lambası · ${l.color.label}',
                        style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(l.name, style: t.titleMedium),
                      if (l.color == TelltaleColor.red && l.confidence >= Guardrails.redTelltaleConfidence)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Pill('Kırmızı lamba → U3', color: l.color.color, icon: Icons.shield_rounded),
                        ),
                    ],
                  ),
                ),
                Text(Fmt.percent(l.confidence), style: t.titleLarge?.copyWith(color: l.color.color)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Causes extends StatelessWidget {
  const _Causes({required this.report});
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final causes = report.causes.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Olası nedenler', subtitle: 'Olasılığa göre sıralı'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            children: [
              for (var i = 0; i < causes.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 0 ? scheme.primary : scheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: t.labelMedium?.copyWith(
                            color: i == 0 ? scheme.onPrimary : scheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Gap(Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConfidenceBar(
                              value: causes[i].likelihood,
                              label: causes[i].title,
                              color: i == 0 ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                            ),
                            const Gap(Space.sm),
                            Text(causes[i].explanation, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                            if (causes[i].citationIds.isNotEmpty) ...[
                              const Gap(Space.sm),
                              Wrap(
                                spacing: 6,
                                children: [
                                  for (final id in causes[i].citationIds)
                                    Pill(
                                      'Kılavuz s. ${report.citationById(id)?.page ?? '?'}',
                                      color: scheme.primary,
                                      icon: Icons.menu_book_rounded,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != causes.length - 1) const Divider(indent: 54),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ManualCard extends StatelessWidget {
  const _ManualCard({required this.report});
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Kullanım kılavuzunuzdan', subtitle: 'Kısa alıntılar · FSEK md. 35'),
        for (final c in report.citations) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(left: Space.md),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: scheme.primary, width: 3)),
                  ),
                  child: Text('“${c.excerpt}”', style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                ),
                const Gap(Space.md),
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 15, color: scheme.onSurfaceVariant),
                    const Gap(6),
                    Expanded(
                      child: Text(
                        '${c.source} · sayfa ${c.page}',
                        style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(Space.sm),
        ],
      ],
    );
  }
}
