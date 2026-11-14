import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/synced_list_notifier.dart';
import '../domain/report.dart';

final reportsProvider = NotifierProvider<ReportsNotifier, List<DiagnosticReport>>(ReportsNotifier.new);

final reportByIdProvider = Provider.family<DiagnosticReport?, String>(
  (ref, id) => ref.watch(reportsProvider).where((r) => r.id == id).firstOrNull,
);

/// Newest first. Synced to `users/{uid}/reports`.
class ReportsNotifier extends SyncedListNotifier<DiagnosticReport> {
  @override
  String get collection => 'reports';
  @override
  DiagnosticReport fromJson(Map<String, dynamic> json) => DiagnosticReport.fromJson(json);
  @override
  Map<String, dynamic> toJson(DiagnosticReport item) => item.toJson();
  @override
  String idOf(DiagnosticReport item) => item.id;
  @override
  List<DiagnosticReport> sort(List<DiagnosticReport> items) =>
      items..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> add(DiagnosticReport report) => upsert(report);

  Future<void> remove(String id) => removeById(id);
}
