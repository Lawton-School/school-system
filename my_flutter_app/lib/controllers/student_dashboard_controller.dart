import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/student_repository.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(ref.watch(rpcClientProvider));
});

final studentDashboardSummaryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, studentProfileId) async {
  if (studentProfileId.isEmpty) return const <String, dynamic>{};
  return ref.watch(studentRepositoryProvider).fetchStudent360(studentProfileId);
});
