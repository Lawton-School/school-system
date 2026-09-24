import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../repositories/marketplace_repository.dart';

/// Compatibility facade for existing Marketplace widgets/providers.
///
/// Read/listing behavior remains unchanged, while order placement is routed
/// through the atomic server-authoritative PostgreSQL RPC via
/// [MarketplaceRepository]. Client supplied totals and prices are ignored.
class MarketplaceService {
  final SupabaseClient _client;
  late final MarketplaceRepository _repository = MarketplaceRepository(_client);

  MarketplaceService(this._client);

  Future<List<MarketplaceItemModel>> getItems(String schoolId, {String? status}) {
    return _repository.fetchItems(schoolId, status: status);
  }

  Future<MarketplaceItemModel> createItem({
    required String schoolId,
    required String title,
    String? description,
    required double price,
    int stockQuantity = 1,
    String? imageUrl,
    required String sellerProfileId,
  }) async {
    final response = await _client.from('marketplace_items').insert({
      'school_id': schoolId,
      'title': title,
      'description': description,
      'price': price,
      'stock_quantity': stockQuantity,
      'image_url': imageUrl,
      'seller_profile_id': sellerProfileId,
      'status': 'available',
    }).select('*, profiles!marketplace_items_seller_profile_id_fkey(*)').single();

    return MarketplaceItemModel.fromMap(response);
  }

  Future<List<MarketplaceOrderModel>> getOrders(
    String schoolId, {
    String? buyerProfileId,
  }) {
    return _repository.fetchOrders(schoolId, buyerProfileId: buyerProfileId);
  }

  Future<MarketplaceOrderModel> placeOrder({
    required String schoolId,
    required String buyerProfileId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) {
    // schoolId, buyerProfileId, totalAmount and item prices are intentionally
    // not trusted here. The active profile, tenant, prices, stock and total are
    // all derived and validated server-side by place_marketplace_order().
    return _repository.placeOrder(items: items);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    if (status == 'cancelled') {
      await _repository.cancelOrder(orderId);
      return;
    }

    final fulfillmentStatus = switch (status) {
      'pending' => 'pending',
      'processing' => 'processing',
      'ready' => 'ready',
      'completed' => 'collected',
      _ => throw ArgumentError.value(status, 'status', 'Unsupported marketplace order status'),
    };

    await _repository.setFulfillmentStatus(
      orderId: orderId,
      status: fulfillmentStatus,
    );
  }
}
