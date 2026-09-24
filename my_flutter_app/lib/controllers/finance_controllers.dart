import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/finance_repository.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(
    client: ref.watch(supabaseClientProvider),
    rpc: ref.watch(rpcClientProvider),
  );
});

/// Screen 13: authoritative invoice management list.
final invoiceManagementProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(financeRepositoryProvider).fetchInvoices();
});

/// Screen 13: active fee structures available for batch invoice generation.
final activeFeeStructuresProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(financeRepositoryProvider).fetchActiveFeeStructures();
});

/// Screen 14: payment ledger including unmatched incoming payments.
final paymentsLedgerProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(financeRepositoryProvider).fetchPayments();
});
