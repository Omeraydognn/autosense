import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../capture/domain/captured_media.dart';
import '../../vehicle/domain/vehicle.dart';
import '../../vehicle/domain/vehicle_catalog.dart';
import '../domain/audio_classes.dart';
import '../domain/guardrails.dart';
import '../domain/report.dart';
import '../domain/telltales.dart';
import '../domain/urgency.dart';

/// What the user captured on S3, already processed on-device.
class CaptureRequest {
  const CaptureRequest({required this.vehicle, this.audio, this.photo});

  final Vehicle vehicle;

  /// Speech-suppressed engine clip (on-device processed).
  final CapturedAudio? audio;

  /// Anonymised dashboard photo (faces/plates blurred, EXIF stripped).
  final CapturedPhoto? photo;

  RecordingState? get recordingState => audio?.state;
  bool get hasAudio => audio != null;
  bool get hasPhoto => photo != null;
  bool get isValid => hasAudio || hasPhoto;
}

/// The four stages of the Track B pipeline (P0 §6), shown live on screen.
enum DiagnosisStage {
  perception('Algılama', 'Ses sınıflandırılıyor, gösterge paneli okunuyor'),
  retrieval('Kılavuz araması', 'Kullanım kılavuzunda ilgili bölümler aranıyor'),
  generation('Rapor oluşturma', 'Kaynaklı açıklama hazırlanıyor'),
  guardrails('Güvenlik kontrolü', 'Şema, kaynak ve U3 kuralı doğrulanıyor');

  const DiagnosisStage(this.title, this.detail);
  final String title;
  final String detail;
}

abstract interface class DiagnosisService {
  Future<DiagnosticReport> diagnose(CaptureRequest request, {void Function(DiagnosisStage stage)? onStage});
}

final diagnosisServiceProvider = Provider<DiagnosisService>((ref) => MockDiagnosisService());

/// Deterministic-looking fake pipeline so the UI can be built end to end
/// before the YAMNet model and the `diagnose()` function exist.
class MockDiagnosisService implements DiagnosisService {
  MockDiagnosisService({Random? random, this.stageDelay = const Duration(milliseconds: 750)})
    : _random = random ?? Random();

  final Random _random;
  final Duration stageDelay;

  @override
  Future<DiagnosticReport> diagnose(CaptureRequest request, {void Function(DiagnosisStage stage)? onStage}) async {
    for (final stage in DiagnosisStage.values) {
      onStage?.call(stage);
      await Future<void>.delayed(stageDelay);
    }
    return Guardrails.apply(_build(request));
  }

  DiagnosticReport _build(CaptureRequest req) {
    final v = req.vehicle;
    final manual = VehicleCatalog.hasManual(v.make, v.model) ? '${v.displayName} Kullanım Kılavuzu' : null;

    AudioFinding? audio;
    if (req.hasAudio) audio = _audioFor(req.recordingState!);

    final telltales = <TelltaleFinding>[];
    if (req.hasPhoto) telltales.add(_randomTelltale());

    final abnormal = audio != null && !audio.label.isNormal;
    final light = telltales.firstOrNull;

    // Model-proposed urgency (before guardrails). Note: a red telltale is
    // deliberately proposed as U2 here to demonstrate the U3 rule.
    var urgency = Urgency.u0;
    if (abnormal) urgency = audio.label == EngineSoundClass.lowOil ? Urgency.u2 : Urgency.u1;
    if (light != null) urgency = urgency.max(light.color == TelltaleColor.red ? Urgency.u2 : Urgency.u1);

    final citations = manual == null
        ? <Citation>[]
        : [
            Citation(
              id: 'c1',
              source: manual,
              page: 112 + _random.nextInt(40),
              excerpt: light != null
                  ? '"${light.name}" uyarı lambası sürüş sırasında yanarsa, aracı güvenli bir yerde durdurun ve yetkili servise başvurun.'
                  : 'Motor bölmesinden gelen olağandışı sesler, kayış gerginliği veya yağ seviyesi kontrol edilerek değerlendirilmelidir.',
            ),
            Citation(
              id: 'c2',
              source: manual,
              page: 230 + _random.nextInt(30),
              excerpt: 'Periyodik bakım tablosunda belirtilen aralıklara uyulması, motor ve yardımcı sistemlerin ömrünü uzatır.',
            ),
          ];

    final causes = _causesFor(audio, light, hasManual: manual != null);
    final insufficient = manual == null && audio == null;

    return DiagnosticReport(
      id: const Uuid().v4(),
      vehicleId: v.id,
      vehicleName: v.displayName,
      createdAt: DateTime.now(),
      urgency: urgency,
      summary: _summary(audio, light, urgency),
      audio: audio,
      telltales: telltales,
      causes: causes,
      citations: citations,
      checklist: _checklist(audio, light, v),
      insufficientInfo: insufficient,
    );
  }

  AudioFinding _audioFor(RecordingState state) {
    final classes = EngineSoundClass.forState(state);
    final picked = classes[_random.nextInt(classes.length)];
    final top = 0.55 + _random.nextDouble() * 0.4;
    final rest = classes.where((c) => c != picked).toList()..shuffle(_random);
    final second = (1 - top) * (0.5 + _random.nextDouble() * 0.3);
    return AudioFinding(
      state: state,
      label: picked,
      confidence: top,
      topK: [
        ClassScore(picked, top),
        if (rest.isNotEmpty) ClassScore(rest[0], second),
        if (rest.length > 1) ClassScore(rest[1], (1 - top - second).clamp(0, 1)),
      ],
    );
  }

  TelltaleFinding _randomTelltale() {
    const pool = ['check_engine', 'oil_pressure', 'battery', 'abs', 'tpms', 'coolant_temp'];
    final spec = Telltales.byId(pool[_random.nextInt(pool.length)])!;
    return TelltaleFinding(telltaleId: spec.id, color: spec.color, confidence: 0.78 + _random.nextDouble() * 0.2);
  }

  List<RankedCause> _causesFor(AudioFinding? audio, TelltaleFinding? light, {required bool hasManual}) {
    final cite = hasManual ? ['c1'] : <String>[];
    final citeBoth = hasManual ? ['c1', 'c2'] : <String>[];
    final label = audio?.label;

    if (light?.telltaleId == 'oil_pressure' || label == EngineSoundClass.lowOil) {
      return [
        RankedCause(
          title: 'Düşük motor yağı seviyesi',
          likelihood: 0.62,
          explanation:
              'Yağ seviyesi minimumun altına düştüğünde yağ basıncı azalır ve motor parçaları yeterince yağlanmaz.',
          citationIds: cite,
        ),
        RankedCause(
          title: 'Yağ pompası arızası',
          likelihood: 0.21,
          explanation: 'Seviye normal olduğu halde basınç düşükse pompa veya müşür kontrol edilmelidir.',
          citationIds: citeBoth,
        ),
        const RankedCause(
          title: 'Yağ basınç sensörü',
          likelihood: 0.12,
          explanation: 'Hatalı sensör yanlış uyarıya neden olabilir; ancak bu, ölçüm yapılmadan varsayılmamalıdır.',
        ),
      ];
    }
    if (label == EngineSoundClass.serpentineBelt || label == EngineSoundClass.powerSteering) {
      return [
        RankedCause(
          title: 'V kayışı gerginliği / aşınma',
          likelihood: 0.58,
          explanation: 'Soğuk motorda artan cırlama sesi genellikle kayış kayması veya aşınmasıyla ilişkilidir.',
          citationIds: cite,
        ),
        RankedCause(
          title: 'Gergi rulmanı',
          likelihood: 0.24,
          explanation: 'Rulman aşındığında sürekli bir uğultu veya tıkırtı duyulabilir.',
          citationIds: citeBoth,
        ),
        const RankedCause(
          title: 'Hidrolik direksiyon pompası',
          likelihood: 0.11,
          explanation: 'Direksiyon çevrilirken ses artıyorsa pompa veya hidrolik seviyesi kontrol edilmelidir.',
        ),
      ];
    }
    if (label == EngineSoundClass.badIgnition || light?.telltaleId == 'check_engine') {
      return [
        RankedCause(
          title: 'Ateşleme bobini',
          likelihood: 0.47,
          explanation: 'Tekleme ve motor arıza lambası birlikte görülüyorsa bobin arızası olasıdır.',
          citationIds: cite,
        ),
        RankedCause(
          title: 'Buji aşınması',
          likelihood: 0.31,
          explanation: 'Değişim aralığı geçmiş bujiler ilk çalıştırmada teklemeye neden olur.',
          citationIds: citeBoth,
        ),
        const RankedCause(
          title: 'Oksijen / MAP sensörü',
          likelihood: 0.14,
          explanation: 'Arıza kodu okunmadan kesinleştirilemez; OBD taraması istenmelidir.',
        ),
      ];
    }
    if (label == EngineSoundClass.deadBattery || light?.telltaleId == 'battery') {
      return [
        RankedCause(
          title: 'Zayıf akü',
          likelihood: 0.55,
          explanation: 'Yavaş dönen marş motoru, akünün yeterli akım veremediğini gösterir.',
          citationIds: cite,
        ),
        RankedCause(
          title: 'Şarj dinamosu (alternatör)',
          likelihood: 0.27,
          explanation: 'Akü şarj olmuyorsa dinamo çıkış voltajı ölçülmelidir.',
          citationIds: citeBoth,
        ),
        const RankedCause(
          title: 'Gevşek / oksitli kutup başı',
          likelihood: 0.12,
          explanation: 'Basit bir temizlik ve sıkma sorunu çözebilir.',
        ),
      ];
    }
    if (label == EngineSoundClass.wornBrakes || light?.telltaleId == 'abs') {
      return [
        RankedCause(
          title: 'Aşınmış fren balatası',
          likelihood: 0.64,
          explanation: 'Metalik sürtünme sesi, balata aşınma göstergesinin diske değdiğini gösterir.',
          citationIds: cite,
        ),
        RankedCause(
          title: 'Disk yüzeyinde çizik',
          likelihood: 0.2,
          explanation: 'Uzun süre aşınmış balata ile sürüş diske zarar verebilir.',
          citationIds: citeBoth,
        ),
        const RankedCause(
          title: 'ABS sensörü kirlenmesi',
          likelihood: 0.1,
          explanation: 'ABS lambası da yanıyorsa teker sensörleri kontrol edilmelidir.',
        ),
      ];
    }
    if (light != null) {
      return [
        RankedCause(
          title: '${light.name} uyarısı',
          likelihood: 0.5,
          explanation: 'Bu lambanın anlamı ve önerilen işlem kılavuzunuzda açıklanmıştır.',
          citationIds: cite,
        ),
        RankedCause(
          title: 'Sensör / bağlantı sorunu',
          likelihood: 0.2,
          explanation: 'Lamba aralıklı yanıyorsa bağlantı veya sensör kaynaklı olabilir.',
          citationIds: citeBoth,
        ),
      ];
    }
    return [
      RankedCause(
        title: 'Normal çalışma sesi',
        likelihood: 0.7,
        explanation: 'Kayıt, aynı durumdaki sağlıklı motor kayıtlarına benziyor.',
        citationIds: cite,
      ),
    ];
  }

  String _summary(AudioFinding? audio, TelltaleFinding? light, Urgency u) {
    final parts = <String>[];
    if (audio != null) {
      parts.add(
        audio.label.isNormal
            ? '${audio.state.label} kaydı normal görünüyor.'
            : '${audio.state.label} kaydında "${audio.label.label}" ile uyumlu bir ses tespit edildi.',
      );
    }
    if (light != null) {
      parts.add('Gösterge panelinde ${light.color.label.toLowerCase()} "${light.name}" lambası algılandı.');
    }
    // Advice is NOT baked in here: guardrails may still raise the urgency,
    // so the UI always derives it from the final `urgency`.
    return parts.join(' ');
  }

  List<String> _checklist(AudioFinding? audio, TelltaleFinding? light, Vehicle v) => [
    'Aracım ${v.year} model ${v.displayName}, ${v.mileageKm} km. Bu kilometrede bu belirti yaygın mı?',
    if (light != null) 'OBD cihazıyla arıza kodunu okuyup bana gösterebilir misiniz?',
    if (audio != null && !audio.label.isNormal)
      'Kaydettiğim sesi dinleyip "${audio.label.label}" olasılığını kontrol eder misiniz?',
    'Değişmesi gereken parçayı değiştirmeden önce bana gösterebilir misiniz?',
    'İşçilik ve parça fiyatını ayrı ayrı yazılı verebilir misiniz?',
    'Orijinal mi, yan sanayi parça mı kullanılacak? Garanti süresi nedir?',
    'Bu sorun ertelenirse başka bir parçaya zarar verir mi?',
  ];
}
