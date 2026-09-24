import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/announcements_repository.dart';

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  final repository = AnnouncementsRepository(ref.watch(supabaseClientProvider));
  ref.onDispose(repository.disposeRealtime);
  return repository;
});

final announcementsManagementProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, schoolId) async {
  return ref.watch(announcementsRepositoryProvider).fetchAnnouncements(schoolId);
});
