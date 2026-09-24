import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../repositories/marketplace_repository.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MarketplaceRepository(client);
});

final marketplaceCurrencyProvider =
    FutureProvider.autoDispose.family<String, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('schools')
      .select('default_currency')
      .eq('id', schoolId)
      .single();
  return row['default_currency']?.toString().toUpperCase() ?? 'USD';
});

/// Thin application controller for Marketplace mutations.
/// Keeps widgets free from direct order writes and enforces use of the
/// server-authoritative Marketplace RPCs.
class MarketplaceController {
  final MarketplaceRepository _repository;

  const MarketplaceController(this._repository);

  Future<MarketplaceOrderModel> placeOrder({
    required List<Map<String, dynamic>> items,
  }) {
    return _repository.placeOrder(items: items);
  }

  Future<void> cancelOrder(String orderId) {
    return _repository.cancelOrder(orderId);
  }

  Future<void> setFulfillmentStatus({
    required String orderId,
    required String status,
  }) {
    return _repository.setFulfillmentStatus(orderId: orderId, status: status);
  }
}

final marketplaceControllerProvider = Provider<MarketplaceController>((ref) {
  return MarketplaceController(ref.watch(marketplaceRepositoryProvider));
});
