import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/admissions_repository.dart';

final admissionsRepositoryProvider = Provider<AdmissionsRepository>((ref) {
  return AdmissionsRepository(
    client: ref.watch(supabaseClientProvider),
    rpc: ref.watch(rpcClientProvider),
  );
});

/// Screen 15: server-authoritative admissions pipeline.
final admissionsPipelineProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(admissionsRepositoryProvider).fetchPipeline();
});

/// Application documents stored in the private admissions document domain.
final admissionDocumentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, applicationId) async {
  return ref.watch(admissionsRepositoryProvider).fetchDocuments(applicationId);
});

/// Active student profiles available to staff for accepted-application linking.
final admissionStudentCandidatesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(admissionsRepositoryProvider).fetchStudentCandidates();
});

/// Reception front-desk enquiries, appointments and active visits.
final frontDeskWorkspaceProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(admissionsRepositoryProvider).fetchFrontDeskWorkspace();
});
