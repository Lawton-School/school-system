import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(
    client: ref.watch(supabaseClientProvider),
    rpc: ref.watch(rpcClientProvider),
  );
});

final libraryDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(libraryRepositoryProvider).fetchDashboard();
});

final libraryBorrowersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, schoolId) async {
    return ref.watch(libraryRepositoryProvider).fetchBorrowers(schoolId);
  },
);

final libraryFinesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, schoolId) async {
    return ref.watch(libraryRepositoryProvider).fetchFines(schoolId);
  },
);

final libraryCurrencyProvider =
    FutureProvider.autoDispose.family<String, String>((ref, schoolId) async {
  return ref.watch(libraryRepositoryProvider).fetchSchoolCurrency(schoolId);
});
