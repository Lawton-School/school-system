import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/behavior_repository.dart';

final behaviorRepositoryProvider = Provider<BehaviorRepository>((ref) {
  return BehaviorRepository(
    client: ref.watch(supabaseClientProvider),
    rpc: ref.watch(rpcClientProvider),
  );
});

final behaviorDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(behaviorRepositoryProvider).fetchDashboard();
});

final behaviorStudentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, schoolId) async {
    return ref.watch(behaviorRepositoryProvider).fetchStudents(schoolId);
  },
);
