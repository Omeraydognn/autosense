/// Separately recorded, versioned and withdrawable consents (KVKK, P0 §5).
class Consent {
  const Consent({
    required this.version,
    required this.acceptedAt,
    required this.diagnosis,
    required this.modelImprovement,
    required this.notifications,
  });

  static const currentVersion = '1.0';

  final String version;
  final DateTime acceptedAt;
  final bool diagnosis;
  final bool modelImprovement;
  final bool notifications;

  Consent copyWith({bool? diagnosis, bool? modelImprovement, bool? notifications}) => Consent(
    version: currentVersion,
    acceptedAt: DateTime.now(),
    diagnosis: diagnosis ?? this.diagnosis,
    modelImprovement: modelImprovement ?? this.modelImprovement,
    notifications: notifications ?? this.notifications,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'acceptedAt': acceptedAt.toIso8601String(),
    'diagnosis': diagnosis,
    'modelImprovement': modelImprovement,
    'notifications': notifications,
  };

  factory Consent.fromJson(Map<String, dynamic> j) => Consent(
    version: j['version'] as String,
    acceptedAt: DateTime.parse(j['acceptedAt'] as String),
    diagnosis: j['diagnosis'] as bool,
    modelImprovement: j['modelImprovement'] as bool,
    notifications: j['notifications'] as bool,
  );
}
