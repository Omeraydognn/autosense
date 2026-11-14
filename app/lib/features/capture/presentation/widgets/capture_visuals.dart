import 'dart:math' as math;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Scrolling bar waveform of normalised amplitudes (0..1).
class LiveWaveform extends StatelessWidget {
  const LiveWaveform({super.key, required this.samples, required this.color, this.height = 96});

  final List<double> samples;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _WaveformPainter(samples, color, Theme.of(context).colorScheme.outline)),
  );
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.samples, this.color, this.idleColor);
  final List<double> samples;
  final Color color;
  final Color idleColor;

  static const barWidth = 3.0;
  static const gap = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / (barWidth + gap)).floor();
    final mid = size.height / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final start = math.max(0, samples.length - count);
    final visible = samples.sublist(start);

    for (var i = 0; i < count; i++) {
      final x = i * (barWidth + gap) + barWidth / 2;
      final idx = i - (count - visible.length);
      final hasSample = idx >= 0;
      final amp = hasSample ? visible[idx] : 0.04;
      final h = math.max(3.0, amp * size.height * 0.95);
      paint.color = hasSample ? color.withValues(alpha: 0.35 + 0.65 * amp.clamp(0, 1)) : idleColor;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => true;
}

enum LevelStatus {
  tooQuiet('Çok sessiz — telefonu motora yaklaştırın', AppColors.u2),
  good('Seviye iyi', AppColors.u1),
  tooLoud('Çok yüksek — biraz uzaklaşın', AppColors.u3),
  idle('Kayıt bekleniyor', AppColors.u0);

  const LevelStatus(this.label, this.color);
  final String label;
  final Color color;

  static LevelStatus of(double level, {required bool active}) {
    if (!active) return idle;
    if (level < 0.18) return tooQuiet;
    if (level > 0.92) return tooLoud;
    return good;
  }
}

/// 20-segment input level meter.
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.level, required this.active});
  final double level;
  final bool active;

  static const segments = 20;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = LevelStatus.of(level, active: active);
    final lit = active ? (level * segments).round() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < segments; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i < lit
                        ? (i >= 18
                              ? AppColors.u3
                              : i >= 14
                              ? AppColors.u2
                              : AppColors.u1)
                        : scheme.surfaceContainerHigh,
                  ),
                ),
              ),
          ],
        ),
        const Gap(Space.sm),
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: status.color),
            const Gap(6),
            Text(status.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: status.color)),
          ],
        ),
      ],
    );
  }
}

/// Big round record button with a progress ring for the 10-second clip.
class RecordButton extends StatelessWidget {
  const RecordButton({super.key, required this.recording, required this.progress, required this.onTap});

  final bool recording;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: recording ? progress : 0,
              strokeWidth: 4,
              color: AppColors.u3,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
          Material(
            color: onTap == null ? scheme.surfaceContainerHigh : AppColors.u3,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 76,
                height: 76,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: recording
                      ? const Icon(Icons.stop_rounded, key: ValueKey('stop'), color: Colors.white, size: 36)
                      : const Icon(Icons.mic_rounded, key: ValueKey('mic'), color: Colors.white, size: 34),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Viewfinder with corner brackets to align the instrument cluster.
class ClusterFrame extends StatelessWidget {
  const ClusterFrame({super.key, required this.captured, required this.glare, this.preview, this.busy = false});
  final bool captured;
  final bool glare;

  /// Anonymised JPEG to show once processed.
  final Uint8List? preview;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(colors: [Color(0xFF1E2A44), Color(0xFF070A12)], radius: 1.0),
          ),
          child: Stack(
            children: [
              if (preview != null)
                Positioned.fill(child: Image.memory(preview!, fit: BoxFit.cover, gaplessPlayback: true)),
              Positioned.fill(child: CustomPaint(painter: _BracketPainter(captured ? AppColors.u1 : Colors.white))),
              if (busy)
                const Center(child: CircularProgressIndicator(color: Colors.white))
              else if (preview == null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        captured ? Icons.check_circle_rounded : Icons.speed_rounded,
                        color: captured ? AppColors.u1 : Colors.white.withValues(alpha: 0.5),
                        size: 52,
                      ),
                      const Gap(Space.sm),
                      Text(
                        captured ? 'Fotoğraf hazır · anonimleştirildi' : 'Gösterge panelini çerçeveye hizalayın',
                        style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              if (glare)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.u2.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wb_sunny_rounded, size: 14, color: Colors.black),
                        const Gap(4),
                        Text(
                          'Parlama algılandı — açıyı değiştirin',
                          style: t.labelSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 28.0;
    const len = 34.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final r = Rect.fromLTRB(inset, inset * 1.4, size.width - inset, size.height - inset * 1.4);
    for (final (corner, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner.translate(len * dx, 0), p);
      canvas.drawLine(corner, corner.translate(0, len * dy), p);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}
