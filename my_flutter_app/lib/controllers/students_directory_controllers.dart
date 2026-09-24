import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/students_directory_repository.dart';

final studentsDirectoryRepositoryProvider =
    Provider<StudentsDirectoryRepository>((ref) {
  return StudentsDirectoryRepository(ref.watch(rpcClientProvider));
});

final studentsDirectoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, academicYearId) async {
  return ref
      .watch(studentsDirectoryRepositoryProvider)
      .fetchStudents(academicYearId);
});
