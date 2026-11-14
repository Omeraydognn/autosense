import 'audio_classes.dart';
import 'telltales.dart';
import 'urgency.dart';

/// Track A output: on-device engine-sound classification.
class AudioFinding {
  const AudioFinding({required this.state, required this.label, required this.confidence, this.topK = const []});

  final RecordingState state;
  final EngineSoundClass label;
  final double confidence;
  final List<ClassScore> topK;

  Map<String, dynamic> toJson() => {
    'state': state.name,
    'label': label.id,
    'confidence': confidence,
    'topK': topK.map((e) => e.toJson()).toList(),
  };

  factory AudioFinding.fromJson(Map<String, dynamic> j) => AudioFinding(
    state: RecordingState.values.byName(j['state'] as String),
    label: EngineSoundClass.fromId(j['label'] as String),
    confidence: (j['confidence'] as num).toDouble(),
    topK: (j['topK'] as List? ?? []).map((e) => ClassScore.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
  );
}

class ClassScore {
  const ClassScore(this.label, this.score);
  final EngineSoundClass label;
  final double score;

  Map<String, dynamic> toJson() => {'label': label.id, 'score': score};
  factory ClassScore.fromJson(Map<String, dynamic> j) =>
      ClassScore(EngineSoundClass.fromId(j['label'] as String), (j['score'] as num).toDouble());
}

/// Track B vision output: one detected dashboard telltale.
class TelltaleFinding {
  const TelltaleFinding({required this.telltaleId, required this.color, required this.confidence});

  final String telltaleId;
  final TelltaleColor color;
  final double confidence;

  TelltaleSpec? get spec => Telltales.byId(telltaleId);
  String get name => spec?.name ?? telltaleId;

  Map<String, dynamic> toJson() => {'id': telltaleId, 'color': color.name, 'confidence': confidence};
  factory TelltaleFinding.fromJson(Map<String, dynamic> j) => TelltaleFinding(
    telltaleId: j['id'] as String,
    color: TelltaleColor.values.byName(j['color'] as String),
    confidence: (j['confidence'] as num).toDouble(),
  );
}

/// A retrieved owner's-manual passage the model cited.
class Citation {
  const Citation({required this.id, required this.source, required this.page, required this.excerpt});

  final String id;
  final String source;
  final int page;
  final String excerpt;

  Map<String, dynamic> toJson() => {'id': id, 'source': source, 'page': page, 'excerpt': excerpt};
  factory Citation.fromJson(Map<String, dynamic> j) => Citation(
    id: j['id'] as String,
    source: j['source'] as String,
    page: (j['page'] as num).toInt(),
    excerpt: j['excerpt'] as String,
  );
}

class RankedCause {
  const RankedCause({
    required this.title,
    required this.likelihood,
    required this.explanation,
    this.citationIds = const [],
  });

  final String title;
  final double likelihood;
  final String explanation;
  final List<String> citationIds;

  RankedCause copyWith({List<String>? citationIds}) => RankedCause(
    title: title,
    likelihood: likelihood,
    explanation: explanation,
    citationIds: citationIds ?? this.citationIds,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'likelihood': likelihood,
    'explanation': explanation,
    'citationIds': citationIds,
  };
  factory RankedCause.fromJson(Map<String, dynamic> j) => RankedCause(
    title: j['title'] as String,
    likelihood: (j['likelihood'] as num).toDouble(),
    explanation: j['explanation'] as String,
    citationIds: List<String>.from(j['citationIds'] as List? ?? const []),
  );
}

/// Validated JSON report returned by `diagnose()` (P0 §4, S4).
class DiagnosticReport {
  const DiagnosticReport({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.createdAt,
    required this.urgency,
    required this.summary,
    this.audio,
    this.telltales = const [],
    this.causes = const [],
    this.citations = const [],
    this.checklist = const [],
    this.insufficientInfo = false,
    this.guardrailApplied = false,
    this.mediaPaths = const [],
  });

  final String id;
  final String vehicleId;
  final String vehicleName;
  final DateTime createdAt;
  final Urgency urgency;
  final String summary;
  final AudioFinding? audio;
  final List<TelltaleFinding> telltales;
  final List<RankedCause> causes;
  final List<Citation> citations;
  final List<String> checklist;
  final bool insufficientInfo;

  /// True when the deterministic red-telltale rule raised the urgency.
  final bool guardrailApplied;

  /// Anonymised media in Cloud Storage (`users/{uid}/media/...`), if uploaded.
  final List<String> mediaPaths;

  static const lowConfidenceThreshold = 0.6;

  /// Highest perception confidence across audio and photo findings.
  double get topConfidence {
    final values = [if (audio != null) audio!.confidence, ...telltales.map((t) => t.confidence)];
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  bool get lowConfidence => insufficientInfo || topConfidence < lowConfidenceThreshold;

  String get headline {
    if (audio != null && !audio!.label.isNormal && audio!.label != EngineSoundClass.unknown) {
      return audio!.label.label;
    }
    if (telltales.isNotEmpty) return telltales.first.name;
    if (audio != null) return audio!.label.label;
    return 'Ön teşhis';
  }

  Citation? citationById(String id) {
    for (final c in citations) {
      if (c.id == id) return c;
    }
    return null;
  }

  DiagnosticReport copyWith({
    Urgency? urgency,
    List<RankedCause>? causes,
    bool? guardrailApplied,
    bool? insufficientInfo,
    List<String>? mediaPaths,
  }) => DiagnosticReport(
    id: id,
    vehicleId: vehicleId,
    vehicleName: vehicleName,
    createdAt: createdAt,
    urgency: urgency ?? this.urgency,
    summary: summary,
    audio: audio,
    telltales: telltales,
    causes: causes ?? this.causes,
    citations: citations,
    checklist: checklist,
    insufficientInfo: insufficientInfo ?? this.insufficientInfo,
    guardrailApplied: guardrailApplied ?? this.guardrailApplied,
    mediaPaths: mediaPaths ?? this.mediaPaths,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'vehicleName': vehicleName,
    'createdAt': createdAt.toIso8601String(),
    'urgency': urgency.code,
    'summary': summary,
    'audio': audio?.toJson(),
    'telltales': telltales.map((e) => e.toJson()).toList(),
    'causes': causes.map((e) => e.toJson()).toList(),
    'citations': citations.map((e) => e.toJson()).toList(),
    'checklist': checklist,
    'insufficientInfo': insufficientInfo,
    'guardrailApplied': guardrailApplied,
    'mediaPaths': mediaPaths,
  };

  factory DiagnosticReport.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> maps(String key) =>
        (j[key] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return DiagnosticReport(
      id: j['id'] as String,
      vehicleId: j['vehicleId'] as String,
      vehicleName: j['vehicleName'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      urgency: Urgency.fromCode(j['urgency'] as String),
      summary: j['summary'] as String,
      audio: j['audio'] == null ? null : AudioFinding.fromJson(Map<String, dynamic>.from(j['audio'] as Map)),
      telltales: maps('telltales').map(TelltaleFinding.fromJson).toList(),
      causes: maps('causes').map(RankedCause.fromJson).toList(),
      citations: maps('citations').map(Citation.fromJson).toList(),
      checklist: List<String>.from(j['checklist'] as List? ?? const []),
      insufficientInfo: j['insufficientInfo'] as bool? ?? false,
      guardrailApplied: j['guardrailApplied'] as bool? ?? false,
      mediaPaths: List<String>.from(j['mediaPaths'] as List? ?? const []),
    );
  }
}
