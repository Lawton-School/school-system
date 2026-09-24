import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/sync_engine.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../repositories/teacher_repository.dart';

/// Repository provider for Teacher operations
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final rpc = ref.watch(rpcClientProvider);
  final db = ref.watch(appDatabaseProvider);
  final syncEngine = ref.watch(syncEngineProvider.notifier);

  return TeacherRepository(
    client: client,
    rpc: rpc,
    db: db,
    syncEngine: syncEngine,
  );
});

/// Controller for Screen 03: Teacher Dashboard
/// Consumes authoritative `get_teacher_dashboard_metrics()` with zero hardcoded fallbacks.
class TeacherDashboardController
    extends StateNotifier<AsyncValue<TeacherDashboardMetrics>> {
  final TeacherRepository _repository;

  TeacherDashboardController(this._repository)
      : super(const AsyncValue.loading()) {
    loadMetrics();
  }

  Future<void> loadMetrics() async {
    state = const AsyncValue.loading();
    try {
      final metrics = await _repository.fetchDashboardMetrics();
      state = AsyncValue.data(metrics);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await loadMetrics();
  }
}

final teacherDashboardControllerProvider = StateNotifierProvider.autoDispose<
    TeacherDashboardController, AsyncValue<TeacherDashboardMetrics>>((ref) {
  final repo = ref.watch(teacherRepositoryProvider);
  return TeacherDashboardController(repo);
});

/// Screen 04: Roll call data provider for selected class section & date
final teacherRollCallProvider = FutureProvider.autoDispose.family<
    Map<String, dynamic>, ({String sectionId, DateTime date})>((ref, args) async {
  final repo = ref.watch(teacherRepositoryProvider);
  return repo.fetchAttendanceRollCall(
    classSectionId: args.sectionId,
    date: args.date,
  );
});

/// Screen 05: Authoritative gradebook matrix provider
final teacherGradebookProvider = FutureProvider.autoDispose.family<
    Map<String, dynamic>,
    ({String sectionId, String subjectId, String termId})>((ref, args) async {
  final repo = ref.watch(teacherRepositoryProvider);
  return repo.fetchGradebook(
    classSectionId: args.sectionId,
    subjectId: args.subjectId,
    termId: args.termId,
  );
});

/// Screen 26: Gradebook setup provider.
///
/// The backend source of truth returns validation under `weight_validation`
/// (`total_percent` / `is_valid`) and category percentages as
/// `weight_percent`. Compatibility aliases are added here for the frozen
/// Screen 26 UI so it never interprets a valid setup as 0%/invalid.
final teacherGradebookSetupProvider = FutureProvider.autoDispose.family<
    Map<String, dynamic>,
    ({String sectionId, String subjectId, String termId})>((ref, args) async {
  final repo = ref.watch(teacherRepositoryProvider);
  final payload = await repo.fetchGradebookSetup(
    classSectionId: args.sectionId,
    subjectId: args.subjectId,
    termId: args.termId,
  );

  final validation = _asMap(payload['weight_validation']);
  final categories = _mapList(payload['categories'])
      .map(
        (category) => <String, dynamic>{
          ...category,
          'percentage': category['weight_percent'] ??
              ((category['weight'] as num?)?.toDouble() ?? 0) * 100,
        },
      )
      .toList(growable: false);

  return <String, dynamic>{
    ...payload,
    'categories': categories,
    'total_percentage': validation['total_percent'] ?? 0,
    'weights_valid': validation['is_valid'] ?? false,
  };
});

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
