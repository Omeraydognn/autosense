import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../data/diagnosis_service.dart';
import '../../onboarding/data/consent_repository.dart';
import '../data/media_repository.dart';
import '../data/report_repository.dart';

/// Shows the four pipeline stages live while `diagnose()` runs.
class DiagnosingScreen extends ConsumerStatefulWidget {
  const DiagnosingScreen({super.key, required this.request});
  final CaptureRequest request;

  @override
  ConsumerState<DiagnosingScreen> createState() => _DiagnosingScreenState();
}

class _DiagnosingScreenState extends ConsumerState<DiagnosingScreen> {
  DiagnosisStage? _stage;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _error = null);
    try {
      final report = await ref
          .read(diagnosisServiceProvider)
          .diagnose(
            widget.request,
            onStage: (s) {
              if (mounted) setState(() => _stage = s);
            },
          );
      // Reports are immutable once stored, so media goes up first.
      final paths = await ref
          .read(mediaRepositoryProvider)
          .uploadFor(
            reportId: report.id,
            consent: ref.read(consentProvider),
            audio: widget.request.audio,
            photo: widget.request.photo,
          );
      await ref.read(reportsProvider.notifier).add(report.copyWith(mediaPaths: paths));
      if (mounted) context.pushReplacement('/report/${report.id}');
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final current = _stage?.index ?? -1;

    return Scaffold(
      appBar: AppBar(leading: const CloseButton()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      value: _error != null ? 0 : null,
                      color: AppColors.accent,
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                  ),
                  Icon(
                    _error != null ? Icons.cloud_off_rounded : Icons.auto_awesome_rounded,
                    size: 44,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ),
          const Gap(Space.xl),
          Text(
            _error != null ? 'Rapor oluşturulamadı' : 'Raporunuz hazırlanıyor',
            style: t.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const Gap(Space.sm),
          Text(
            _error != null
                ? 'Bağlantınızı kontrol edip tekrar deneyin.'
                : 'Uygulamadan çıkarsanız rapor hazır olduğunda bildirim gönderilir.',
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const Gap(Space.xxl),
          AppCard(
            child: Column(
              children: [
                for (final s in DiagnosisStage.values)
                  _StageRow(
                    stage: s,
                    state: s.index < current
                        ? _RowState.done
                        : s.index == current
                        ? _RowState.active
                        : _RowState.pending,
                    isLast: s == DiagnosisStage.values.last,
                  ),
              ],
            ),
          ),
          if (_error != null) ...[const Gap(Space.xl), FilledButton(onPressed: _run, child: const Text('Tekrar dene'))],
        ],
      ),
    );
  }
}

enum _RowState { pending, active, done }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.state, required this.isLast});
  final DiagnosisStage stage;
  final _RowState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (state) {
      _RowState.done => AppColors.u1,
      _RowState.active => scheme.primary,
      _RowState.pending => scheme.outline,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == _RowState.pending ? Colors.transparent : color.withValues(alpha: 0.15),
                  border: Border.all(color: color, width: 2),
                ),
                child: switch (state) {
                  _RowState.done => Icon(Icons.check_rounded, size: 16, color: color),
                  _RowState.active => Padding(
                    padding: const EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  ),
                  _RowState.pending => const SizedBox.shrink(),
                },
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: scheme.outline, margin: const EdgeInsets.symmetric(vertical: 4)),
                ),
            ],
          ),
          const Gap(Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Space.lg, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: t.titleSmall?.copyWith(color: state == _RowState.pending ? scheme.onSurfaceVariant : null),
                  ),
                  Text(stage.detail, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
