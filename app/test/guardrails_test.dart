import 'dart:math' as math;
import 'dart:typed_data';

import 'package:autosense/features/capture/domain/captured_media.dart';
import 'package:autosense/features/diagnosis/data/diagnosis_service.dart';
import 'package:autosense/features/diagnosis/domain/audio_classes.dart';
import 'package:autosense/features/vehicle/domain/vehicle.dart';
import 'package:autosense/features/diagnosis/domain/guardrails.dart';
import 'package:autosense/features/diagnosis/domain/report.dart';
import 'package:autosense/features/diagnosis/domain/telltales.dart';
import 'package:autosense/features/diagnosis/domain/urgency.dart';
import 'package:flutter_test/flutter_test.dart';

DiagnosticReport _report({
  Urgency urgency = Urgency.u1,
  List<TelltaleFinding> telltales = const [],
  List<RankedCause> causes = const [],
  List<Citation> citations = const [],
  AudioFinding? audio,
}) => DiagnosticReport(
  id: 'r1',
  vehicleId: 'v1',
  vehicleName: 'Fiat Egea',
  createdAt: DateTime(2026, 11, 12, 10),
  urgency: urgency,
  summary: 'test',
  audio: audio,
  telltales: telltales,
  causes: causes,
  citations: citations,
  checklist: const ['Soru 1'],
);

void main() {
  group('U3 red-telltale rule', () {
    test('confident red telltale forces U3', () {
      final r = Guardrails.apply(
        _report(
          urgency: Urgency.u1,
          telltales: const [TelltaleFinding(telltaleId: 'oil_pressure', color: TelltaleColor.red, confidence: 0.9)],
        ),
      );
      expect(r.urgency, Urgency.u3);
      expect(r.guardrailApplied, isTrue);
    });

    test('low-confidence red telltale does not force U3', () {
      final r = Guardrails.apply(
        _report(
          telltales: const [TelltaleFinding(telltaleId: 'oil_pressure', color: TelltaleColor.red, confidence: 0.5)],
        ),
      );
      expect(r.urgency, Urgency.u1);
      expect(r.guardrailApplied, isFalse);
    });

    test('amber telltale is left alone', () {
      final r = Guardrails.apply(
        _report(
          telltales: const [TelltaleFinding(telltaleId: 'check_engine', color: TelltaleColor.amber, confidence: 0.99)],
        ),
      );
      expect(r.urgency, Urgency.u1);
    });

    test('already U3 is not flagged as changed', () {
      final r = Guardrails.apply(
        _report(
          urgency: Urgency.u3,
          telltales: const [TelltaleFinding(telltaleId: 'battery', color: TelltaleColor.red, confidence: 0.95)],
        ),
      );
      expect(r.guardrailApplied, isFalse);
    });
  });

  test('citations not in the retrieved set are dropped', () {
    final r = Guardrails.apply(
      _report(
        citations: const [Citation(id: 'c1', source: 'Kılavuz', page: 10, excerpt: '...')],
        causes: const [
          RankedCause(title: 'A', likelihood: 0.5, explanation: 'x', citationIds: ['c1', 'c9']),
        ],
      ),
    );
    expect(r.causes.single.citationIds, ['c1']);
  });

  test('report survives a JSON round trip', () {
    final original = _report(
      audio: const AudioFinding(
        state: RecordingState.idle,
        label: EngineSoundClass.serpentineBelt,
        confidence: 0.81,
        topK: [ClassScore(EngineSoundClass.serpentineBelt, 0.81)],
      ),
      telltales: const [TelltaleFinding(telltaleId: 'abs', color: TelltaleColor.amber, confidence: 0.88)],
      citations: const [Citation(id: 'c1', source: 'Kılavuz', page: 10, excerpt: 'alıntı')],
      causes: const [
        RankedCause(title: 'Kayış', likelihood: 0.6, explanation: 'x', citationIds: ['c1']),
      ],
    );
    final copy = DiagnosticReport.fromJson(original.toJson());
    expect(copy.toJson(), original.toJson());
    expect(copy.headline, 'V kayışı (serpantin)');
  });

  test('lowConfidence when top perception score is below 0.6', () {
    final r = _report(
      audio: const AudioFinding(state: RecordingState.startup, label: EngineSoundClass.badIgnition, confidence: 0.42),
    );
    expect(r.lowConfidence, isTrue);
  });

  test('mock pipeline never bakes urgency advice into the summary', () async {
    // The guardrail can raise urgency after the summary is written, so advice
    // must come from the final urgency (rendered separately in the UI).
    final service = MockDiagnosisService(stageDelay: Duration.zero, random: math.Random(3));
    for (var i = 0; i < 20; i++) {
      final r = await service.diagnose(
        CaptureRequest(
          vehicle: const Vehicle(
            id: 'v',
            make: 'Fiat',
            model: 'Egea',
            year: 2020,
            engine: '1.3 Multijet',
            fuel: FuelType.diesel,
            transmission: Transmission.manual,
            mileageKm: 1000,
          ),
          photo: CapturedPhoto(
            jpeg: Uint8List(1),
            width: 1,
            height: 1,
            facesBlurred: 0,
            platesBlurred: 0,
            metadataRemoved: false,
            gpsRemoved: false,
            glare: false,
            detectorRan: true,
          ),
        ),
      );
      for (final u in Urgency.values) {
        expect(r.summary.contains(u.advice), isFalse, reason: 'summary must not contain "${u.advice}"');
      }
    }
  });
}
