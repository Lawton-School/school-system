import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Repository for Marketplace reads and server-authoritative order mutations.
///
/// Pricing, stock validation, stock decrement, buyer identity and order totals
/// are deliberately resolved by PostgreSQL through `place_marketplace_order`.
/// The Flutter client only submits item IDs and requested quantities.
class MarketplaceRepository {
  final SupabaseClient _client;

  MarketplaceRepository(this._client);

  Future<List<MarketplaceItemModel>> fetchItems(String schoolId, {String? status}) async {
    var query = _client
        .from('marketplace_items')
        .select('*, profiles!marketplace_items_seller_profile_id_fkey(*)')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (status != null) {
      query = query.eq('status', status);
    } else {
      query = query.neq('status', 'hidden');
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((m) => MarketplaceItemModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<List<MarketplaceOrderModel>> fetchOrders(
    String schoolId, {
    String? buyerProfileId,
  }) async {
    var query = _client
        .from('marketplace_orders')
        .select(
          '*, profiles!marketplace_orders_buyer_profile_id_fkey(*), marketplace_order_items(*, marketplace_items(*))',
        )
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null);

    if (buyerProfileId != null) {
      query = query.eq('buyer_profile_id', buyerProfileId);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((m) => MarketplaceOrderModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<MarketplaceOrderModel> placeOrder({
    required List<Map<String, dynamic>> items,
  }) async {
    final payload = items
        .map((item) => {
              'item_id': item['item_id'],
              'quantity': item['quantity'],
            })
        .toList(growable: false);

    final response = await _client.rpc(
      'place_marketplace_order',
      params: {'p_items': payload},
    );

    final map = Map<String, dynamic>.from(response as Map);
    final order = map['order'];
    if (order is! Map) {
      throw StateError('Marketplace order RPC returned no order payload.');
    }

    return MarketplaceOrderModel.fromMap(Map<String, dynamic>.from(order));
  }

  Future<void> cancelOrder(String orderId) async {
    await _client.rpc(
      'cancel_marketplace_order',
      params: {'p_order_id': orderId},
    );
  }

  Future<void> setFulfillmentStatus({
    required String orderId,
    required String status,
  }) async {
    await _client.rpc(
      'set_marketplace_fulfillment_status',
      params: {
        'p_order_id': orderId,
        'p_fulfillment_status': status,
      },
    );
  }
}
