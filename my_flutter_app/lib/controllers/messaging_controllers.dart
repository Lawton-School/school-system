import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/messaging_repository.dart';

/// Shared messaging repository for the staff-facing Direct Messaging screen.
final directMessagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(activeSessionProvider);

  final repository = MessagingRepository(
    client: client,
    getActiveProfileId: () => session?.profileId,
    getActiveSchoolId: () => session?.schoolId,
  );

  ref.onDispose(repository.disposeRealtime);
  return repository;
});

final directMessageConversationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(directMessagingRepositoryProvider);
  return repository.fetchConversations();
});

final directMessageContactsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(directMessagingRepositoryProvider);
  return repository.fetchAvailableContacts();
});
