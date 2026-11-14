import 'report.dart';
import 'telltales.dart';
import 'urgency.dart';

/// Deterministic post-generation checks (P0 §4, "Guardrail" and R2).
///
/// The server applies the same rules; the app re-applies them so that a
/// report can never be displayed with an unsafe urgency.
abstract final class Guardrails {
  /// A red telltale detected at or above this confidence forces U3.
  static const redTelltaleConfidence = 0.75;

  static DiagnosticReport apply(DiagnosticReport report) {
    var result = _dropUnknownCitations(report);
    result = _enforceRedTelltaleRule(result);
    return result;
  }

  /// Never report a confidently detected red telltale below U3.
  static DiagnosticReport _enforceRedTelltaleRule(DiagnosticReport r) {
    final hasConfidentRed = r.telltales.any(
      (t) => t.color == TelltaleColor.red && t.confidence >= redTelltaleConfidence,
    );
    if (hasConfidentRed && r.urgency != Urgency.u3) {
      return r.copyWith(urgency: Urgency.u3, guardrailApplied: true);
    }
    return r;
  }

  /// Causes may only reference passages that were actually retrieved.
  static DiagnosticReport _dropUnknownCitations(DiagnosticReport r) {
    final known = r.citations.map((c) => c.id).toSet();
    final causes = r.causes.map((c) => c.copyWith(citationIds: c.citationIds.where(known.contains).toList())).toList();
    return r.copyWith(causes: causes);
  }
}
