import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/urgency_badge.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';
import '../domain/urgency.dart';
import 'widgets/report_tile.dart';

/// S5 — History timeline of past reports.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  Urgency? _filter;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(reportsProvider);
    final reports = _filter == null ? all : all.where((r) => r.urgency == _filter).toList();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Group by month for a timeline feel.
    final groups = <String, List<DiagnosticReport>>{};
    for (final r in reports) {
      final key = Fmt.date(r.createdAt).split(' ').skip(1).join(' ');
      groups.putIfAbsent(key, () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş')),
      body: all.isEmpty
          ? EmptyState(
              icon: Icons.history_rounded,
              title: 'Henüz rapor yok',
              message: 'İlk teşhisinizi yaptığınızda raporlarınız burada zaman çizelgesi olarak görünür.',
              action: FilledButton(onPressed: () => context.go('/diagnose'), child: const Text('Teşhis başlat')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: Space.sm),
                        child: ChoiceChip(
                          label: Text('Tümü (${all.length})'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                      ),
                      for (final u in Urgency.values.reversed)
                        Padding(
                          padding: const EdgeInsets.only(right: Space.sm),
                          child: ChoiceChip(
                            avatar: Icon(u.icon, size: 16, color: u.color),
                            label: Text(u.code),
                            selected: _filter == u,
                            onSelected: (_) => setState(() => _filter = _filter == u ? null : u),
                          ),
                        ),
                    ],
                  ),
                ),
                if (reports.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xxl),
                    child: Text('Bu filtrede rapor yok.', textAlign: TextAlign.center, style: t.bodyMedium),
                  ),
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: t.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final r in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: ReportTile(report: r),
                    ),
                ],
              ],
            ),
    );
  }
}
