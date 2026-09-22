import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../repositories/messaging_repository.dart';
import '../repositories/parent_repository.dart';

/// Repository provider for Parent operations
final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final rpc = ref.watch(rpcClientProvider);
  final session = ref.watch(activeSessionProvider);

  return ParentRepository(
    client: client,
    rpc: rpc,
    getActiveProfileId: () => session?.profileId,
  );
});

/// Repository provider for Messaging operations (Screens 09 & 16)
final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(activeSessionProvider);

  return MessagingRepository(
    client: client,
    getActiveProfileId: () => session?.profileId,
    getActiveSchoolId: () => session?.schoolId,
  );
});

/// Provider for authorized children of the authenticated parent
final parentChildrenProvider = FutureProvider.autoDispose<List<AuthorizedChild>>((ref) async {
  final repo = ref.watch(parentRepositoryProvider);
  return await repo.fetchAuthorizedChildren();
});

/// Index of currently selected child
final selectedChildIndexProvider = StateProvider<int>((ref) => 0);

/// Currently active selected child
final activeSelectedChildProvider = Provider<AuthorizedChild?>((ref) {
  final childrenAsync = ref.watch(parentChildrenProvider);
  final index = ref.watch(selectedChildIndexProvider);

  return childrenAsync.when(
    data: (children) => (children.isNotEmpty && index < children.length) ? children[index] : null,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Controller for Screen 06: Parent Dashboard
final parentDashboardDataProvider = FutureProvider.autoDispose<ParentDashboardData?>((ref) async {
  final child = ref.watch(activeSelectedChildProvider);
  if (child == null) return null;

  final repo = ref.watch(parentRepositoryProvider);
  return await repo.fetchParentDashboard(
    studentProfileId: child.studentId,
    studentName: child.fullName,
    className: child.className,
  );
});

/// Screen 08: Student invoices provider (multi-currency, server-authoritative)
final studentInvoicesProvider = FutureProvider.autoDispose.family<List<InvoiceModel>, String>((ref, studentProfileId) async {
  final repo = ref.watch(parentRepositoryProvider);
  return await repo.fetchStudentInvoices(studentProfileId);
});

/// Screen 08: Student payments provider
final studentPaymentsProvider = FutureProvider.autoDispose.family<List<PaymentModel>, String>((ref, studentProfileId) async {
  final repo = ref.watch(parentRepositoryProvider);
  return await repo.fetchStudentPayments(studentProfileId);
});

/// Screen 07: Student 360 summary provider
final student360SummaryProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, studentProfileId) async {
  final repo = ref.watch(parentRepositoryProvider);
  return await repo.fetchStudent360(studentProfileId);
});

/// Controller for Screen 09: Direct Messaging (Conversations & Realtime stream)
class ParentMessagesController extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final MessagingRepository _repository;

  ParentMessagesController(this._repository) : super(const AsyncValue.loading()) {
    loadConversations();
  }

  Future<void> loadConversations() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repository.fetchConversations();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await loadConversations();
  }
}

final parentMessagesControllerProvider =
    StateNotifierProvider.autoDispose<ParentMessagesController, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final repo = ref.watch(messagingRepositoryProvider);
  return ParentMessagesController(repo);
});

