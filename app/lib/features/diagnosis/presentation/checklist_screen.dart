import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/urgency_badge.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

/// S5 — Mechanic checklist.
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key, required this.reportId});
  final String reportId;

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  final _checked = <int>{};

  String _asText(DiagnosticReport r) {
    final b = StringBuffer()
      ..writeln('AutoSense ön-teşhis raporu — ${r.vehicleName}')
      ..writeln(Fmt.dateTime(r.createdAt))
      ..writeln('Aciliyet: ${r.urgency.code} · ${r.urgency.title}')
      ..writeln()
      ..writeln('Tespit: ${r.headline}')
      ..writeln()
      ..writeln('Olası nedenler:');
    for (final (i, c) in r.causes.indexed) {
      b.writeln('${i + 1}. ${c.title} (%${(c.likelihood * 100).round()})');
    }
    b
      ..writeln()
      ..writeln('Ustaya sorulacaklar:');
    for (final q in r.checklist) {
      b.writeln('• $q');
    }
    b
      ..writeln()
      ..writeln('Not: Bu rapor bilgilendirme amaçlıdır; kesin teşhis yerine geçmez.');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reportByIdProvider(widget.reportId));
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (report == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kontrol listesi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.headline, style: t.titleMedium),
                      Text(
                        '${report.vehicleName} · ${Fmt.date(report.createdAt)}',
                        style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                UrgencyBadge(report.urgency, compact: true),
              ],
            ),
          ),
          const SectionHeader('Ustaya sorulacaklar', subtitle: 'Görüşme sırasında işaretleyin'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              children: [
                for (final (i, q) in report.checklist.indexed)
                  CheckboxListTile(
                    value: _checked.contains(i),
                    onChanged: (v) => setState(() => v == true ? _checked.add(i) : _checked.remove(i)),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      q,
                      style: t.bodyMedium?.copyWith(
                        decoration: _checked.contains(i) ? TextDecoration.lineThrough : null,
                        color: _checked.contains(i) ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Gap(Space.lg),
          const InfoBanner(
            icon: Icons.lightbulb_outline_rounded,
            title: 'İpucu',
            message: 'Kaydettiğiniz sesi ustaya dinletin. Aralıklı sesler serviste tekrar etmeyebilir.',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _asText(report)));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Rapor metni kopyalandı')));
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Kopyala'),
                ),
              ),
              const Gap(Space.md),
              Expanded(
                child: FilledButton.icon(
                  // TODO(frontend): PDF export via `pdf` + `share_plus` (later step).
                  onPressed: () =>
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('PDF dışa aktarma bir sonraki adımda eklenecek'))),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF paylaş'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
