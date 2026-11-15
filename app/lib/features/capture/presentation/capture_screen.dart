import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../diagnosis/data/diagnosis_service.dart';
import '../../diagnosis/domain/audio_classes.dart';
import '../../onboarding/data/consent_repository.dart';
import '../../vehicle/data/vehicle_repository.dart';
import '../data/capture_processor.dart';
import '../data/engine_recorder.dart';
import '../domain/captured_media.dart';
import '../domain/pcm.dart';
import 'widgets/capture_visuals.dart';

enum CaptureMode { audio, photo }

/// S3 — Capture. Real 16 kHz microphone recording and camera/gallery photos,
/// both anonymised on the device before anything else sees them.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  static const clipSeconds = AudioSpec.maxSeconds;
  static const _uiTick = Duration(milliseconds: 100);

  /// One waveform bar per 50 ms of audio.
  static const _barSamples = AudioSpec.sampleRate ~/ 20;

  CaptureMode _mode = CaptureMode.audio;
  RecordingState _state = RecordingState.idle;

  // Audio
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  StreamSubscription<Float32List>? _levelSub;
  bool _recording = false;
  bool _processingAudio = false;
  bool _micDenied = false;
  double _elapsed = 0;
  final List<double> _bars = [];
  final List<double> _pendingBar = [];
  double _level = 0;
  CapturedAudio? _audio;

  // Photo
  bool _processingPhoto = false;
  CapturedPhoto? _photo;

  // Kept alive by `ref.watch` in build while this screen is mounted, so the
  // recorder and the ML Kit detectors are never disposed mid-capture.
  late EngineRecorder _recorder;
  late CaptureProcessor _processor;

  @override
  void dispose() {
    _ticker?.cancel();
    _levelSub?.cancel();
    super.dispose(); // the provider disposes the recorder (stopping any recording)
  }

  // ---------------------------------------------------------------- audio --

  Future<void> _toggleRecording() async => _recording ? _stop() : _start();

  Future<void> _start() async {
    final recorder = _recorder;
    if (!await recorder.hasPermission()) {
      setState(() => _micDenied = true);
      return;
    }
    final Stream<Float32List> chunks;
    try {
      chunks = await recorder.start();
    } catch (e) {
      _toast('Mikrofon başlatılamadı: $e');
      return;
    }
    setState(() {
      _micDenied = false;
      _recording = true;
      _elapsed = 0;
      _bars.clear();
      _pendingBar.clear();
      _audio = null;
    });
    _stopwatch
      ..reset()
      ..start();
    _levelSub = chunks.listen(_onChunk);
    _ticker = Timer.periodic(_uiTick, (_) {
      // Wall-clock time: robust to throttled timers and uneven chunk sizes.
      setState(() => _elapsed = math.min(_stopwatch.elapsedMilliseconds / 1000, clipSeconds));
      if (_elapsed >= clipSeconds) _stop();
    });
  }

  void _onChunk(Float32List chunk) {
    for (final s in chunk) {
      _pendingBar.add(s);
      if (_pendingBar.length >= _barSamples) {
        final db = Pcm.dbfs(Float32List.fromList(_pendingBar));
        _bars.add(Pcm.meterLevel(db));
        _level = Pcm.meterLevel(db);
        _pendingBar.clear();
      }
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    _stopwatch.stop();
    await _levelSub?.cancel();
    setState(() {
      _recording = false;
      _level = 0;
      _processingAudio = true;
    });

    final raw = await _recorder.stop();
    final seconds = raw.length / AudioSpec.sampleRate;
    if (seconds < AudioSpec.minSeconds) {
      setState(() => _processingAudio = false);
      _toast('Kayıt en az ${AudioSpec.minSeconds.toInt()} saniye olmalı');
      return;
    }
    if (Pcm.peak(raw) < 0.003) {
      setState(() => _processingAudio = false);
      _toast('Ses alınamadı. Mikrofonun kapalı olmadığından emin olun.');
      return;
    }
    final audio = await _processor.finishAudio(raw, _state);
    if (!mounted) return;
    setState(() {
      _audio = audio;
      _processingAudio = false;
    });
  }

  // ---------------------------------------------------------------- photo --

  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, requestFullMetadata: false);
    } catch (e) {
      _toast(source == ImageSource.camera ? 'Kameraya erişilemedi.' : 'Galeriye erişilemedi.');
      return;
    }
    if (file == null) return;
    setState(() => _processingPhoto = true);
    try {
      final photo = await _processor.finishPhoto(file);
      if (!mounted) return;
      setState(() => _photo = photo);
    } catch (e) {
      _toast('Fotoğraf işlenemedi. Başka bir fotoğraf deneyin.');
    } finally {
      if (mounted) setState(() => _processingPhoto = false);
    }
  }

  // ------------------------------------------------------------------ run --

  void _run() {
    final vehicle = ref.read(activeVehicleProvider);
    if (vehicle == null) return;
    context.push(
      '/diagnosing',
      extra: CaptureRequest(vehicle: vehicle, audio: _audio, photo: _photo),
    );
    setState(() {
      _audio = null;
      _photo = null;
      _bars.clear();
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    _recorder = ref.watch(engineRecorderProvider);
    _processor = ref.watch(captureProcessorProvider);
    final vehicle = ref.watch(activeVehicleProvider);
    final consent = ref.watch(consentProvider);
    final canDiagnose = consent?.diagnosis ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teşhis'),
        actions: [
          if (vehicle != null)
            Padding(
              padding: const EdgeInsets.only(right: Space.lg),
              child: Center(
                child: Pill(
                  vehicle.displayName,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.directions_car_rounded,
                ),
              ),
            ),
        ],
      ),
      body: !canDiagnose
          ? EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Teşhis onayı gerekli',
              message: 'Ses ve fotoğraf işlemek için açık rızanız gerekir. Ayarlar\'dan dilediğiniz zaman verebilir veya geri çekebilirsiniz.',
              action: FilledButton(onPressed: () => context.push('/settings'), child: const Text('Ayarlara git')),
            )
          : vehicle == null
          ? EmptyState(
              icon: Icons.directions_car_filled_rounded,
              title: 'Önce aracınızı ekleyin',
              message: 'Rapor, aracınızın modeline ve kilometresine göre hazırlanır.',
              action: FilledButton(onPressed: () => context.push('/vehicle/new'), child: const Text('Araç ekle')),
            )
          : _buildBody(context),
      bottomNavigationBar: canDiagnose && vehicle != null ? _buildRunBar(context) : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    final busy = _recording || _processingAudio || _processingPhoto;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        SegmentedButton<CaptureMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: CaptureMode.audio, icon: Icon(Icons.mic_rounded), label: Text('Motor sesi')),
            ButtonSegment(
              value: CaptureMode.photo,
              icon: Icon(Icons.photo_camera_rounded),
              label: Text('Gösterge paneli'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: busy ? null : (s) => setState(() => _mode = s.first),
        ),
        const Gap(Space.lg),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _mode == CaptureMode.audio ? _audioPanel(context) : _photoPanel(context),
        ),
        const Gap(Space.lg),
        _CaptureSummary(audio: _audio, photo: _photo),
      ],
    );
  }

  Widget _audioPanel(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final remaining = (clipSeconds - _elapsed).clamp(0, clipSeconds);

    return Column(
      key: const ValueKey('audio'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_micDenied) ...[
          const InfoBanner(
            tone: BannerTone.danger,
            icon: Icons.mic_off_rounded,
            title: 'Mikrofon izni verilmedi',
            message: 'Motor sesini kaydetmek için telefon ayarlarından AutoSense\'e mikrofon izni verin.',
          ),
          const Gap(Space.lg),
        ],
        Text('1. Motor durumunu seçin', style: t.titleSmall),
        const Gap(Space.sm),
        Row(
          children: [
            for (final s in RecordingState.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: s == RecordingState.values.last ? 0 : Space.sm),
                  child: _StateCard(
                    state: s,
                    selected: _state == s,
                    onTap: _recording || _processingAudio ? null : () => setState(() => _state = s),
                  ),
                ),
              ),
          ],
        ),
        const Gap(Space.xl),
        Text('2. 10 saniyelik kayıt alın', style: t.titleSmall),
        const Gap(Space.sm),
        AppCard(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(_state.icon, size: 18, color: scheme.onSurfaceVariant),
                  const Gap(6),
                  Expanded(
                    child: Text(_state.hint, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  Text(
                    _recording ? '${remaining.toStringAsFixed(1)} sn' : '10 sn',
                    style: t.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
              const Gap(Space.lg),
              LiveWaveform(samples: _bars, color: _recording ? AppColors.u3 : scheme.primary),
              const Gap(Space.lg),
              LevelMeter(level: _level, active: _recording),
              const Gap(Space.xl),
              if (_processingAudio)
                const SizedBox(width: 96, height: 96, child: Center(child: CircularProgressIndicator()))
              else
                RecordButton(recording: _recording, progress: _elapsed / clipSeconds, onTap: _toggleRecording),
              const Gap(Space.sm),
              Text(
                _processingAudio
                    ? 'Konuşmalar bastırılıyor…'
                    : _recording
                    ? 'Kaydediliyor… telefonu motora yakın ve sabit tutun'
                    : (_audio != null ? 'Yeniden kaydetmek için dokunun' : 'Kaydı başlatmak için dokunun'),
                style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const Gap(Space.md),
        const InfoBanner(
          icon: Icons.record_voice_over_outlined,
          title: 'Konuşmalar cihazda bastırılır',
          message: 'Kayıttaki insan sesi algılanır ve kısılır. Ham kayıt telefondan çıkmaz.',
        ),
      ],
    );
  }

  Widget _photoPanel(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final photo = _photo;
    return Column(
      key: const ValueKey('photo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Yanan uyarı lambalarını çekin', style: t.titleSmall),
        const Gap(Space.sm),
        ClusterFrame(
          captured: photo != null,
          glare: photo?.glare ?? false,
          preview: photo?.jpeg,
          busy: _processingPhoto,
        ),
        if (photo != null) ...[const Gap(Space.md), _PrivacyChips(photo: photo)],
        const Gap(Space.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _processingPhoto ? null : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeriden'),
              ),
            ),
            const Gap(Space.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: _processingPhoto ? null : () => _pickPhoto(ImageSource.camera),
                icon: Icon(photo != null ? Icons.refresh_rounded : Icons.photo_camera_rounded),
                label: Text(photo != null ? 'Tekrar çek' : 'Fotoğraf çek'),
              ),
            ),
          ],
        ),
        const Gap(Space.md),
        const InfoBanner(
          icon: Icons.blur_on_rounded,
          title: 'Yüz ve plakalar bulanıklaştırılır',
          message: 'Fotoğraf gönderilmeden önce cihazda anonimleştirilir; EXIF ve GPS bilgisi silinir.',
        ),
      ],
    );
  }

  Widget _buildRunBar(BuildContext context) {
    final ready = !_recording && !_processingAudio && !_processingPhoto && (_audio != null || _photo != null);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton.icon(
          onPressed: ready ? _run : null,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Teşhisi başlat'),
        ),
      ),
    );
  }
}

class _PrivacyChips extends StatelessWidget {
  const _PrivacyChips({required this.photo});
  final CapturedPhoto photo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        if (photo.detectorRan)
          Pill(
            photo.facesBlurred + photo.platesBlurred == 0
                ? 'Yüz / plaka bulunmadı'
                : '${photo.facesBlurred} yüz · ${photo.platesBlurred} plaka bulanıklaştırıldı',
            color: AppColors.u1,
            icon: Icons.blur_on_rounded,
          )
        else
          const Pill('Bu cihazda yüz/plaka taraması yok', color: AppColors.u2, icon: Icons.warning_amber_rounded),
        Pill(
          photo.gpsRemoved ? 'Konum silindi' : 'Konum verisi yok',
          color: AppColors.u1,
          icon: Icons.location_off_rounded,
        ),
        Pill('${photo.width}×${photo.height}', color: scheme.onSurfaceVariant, icon: Icons.photo_size_select_large),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.state, required this.selected, this.onTap});
  final RecordingState state;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: Space.md + 2),
      color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
      borderColor: selected ? scheme.primary : null,
      child: Column(
        children: [
          Icon(state.icon, color: fg),
          const Gap(6),
          Text(state.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class _CaptureSummary extends StatelessWidget {
  const _CaptureSummary({required this.audio, required this.photo});
  final CapturedAudio? audio;
  final CapturedPhoto? photo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget row(IconData icon, String label, String? value, {String? note}) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            value != null ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: value != null ? AppColors.u1 : scheme.outline,
          ),
          const Gap(Space.md),
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const Gap(6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodyMedium),
                if (note != null) Text(note, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(value ?? 'Eklenmedi', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
    final a = audio;
    final p = photo;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rapora eklenecekler', style: t.titleSmall),
          const Gap(Space.md),
          row(
            Icons.mic_none_rounded,
            'Motor sesi',
            a == null ? null : '${a.state.label} · ${a.seconds.toStringAsFixed(1)} sn',
            note: a == null
                ? null
                : a.speechSuppressed
                ? 'Konuşma algılandı ve kısıldı (%${(a.speechRatio * 100).round()})'
                : 'Konuşma algılanmadı',
          ),
          row(
            Icons.photo_outlined,
            'Gösterge paneli',
            p == null ? null : 'Hazır',
            note: p == null ? null : (p.glare ? 'Parlama var — açıyı değiştirmeniz önerilir' : 'Anonimleştirildi'),
          ),
          const Gap(Space.xs),
          Text(
            'Daha doğru sonuç için ikisini birlikte ekleyebilirsiniz.',
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
