import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/marketplace_controller.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final Map<String, int> _cart = {};

  void _showSellItemDialog(
    BuildContext context,
    String schoolId,
    String profileId,
    String currency,
  ) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sell Item on School Marketplace'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Condition / Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Price ($currency)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Available Stock Quantity'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
              final price = double.tryParse(priceCtrl.text.trim());
              final qty = int.tryParse(qtyCtrl.text.trim());
              if (price == null || price <= 0 || qty == null || qty <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid positive price and stock quantity.')),
                );
                return;
              }

              final client = ref.read(supabaseClientProvider);
              await MarketplaceService(client).createItem(
                schoolId: schoolId,
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                price: price,
                stockQuantity: qty,
                sellerProfileId: profileId,
              );
              ref.invalidate(marketplaceItemsProvider(schoolId));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item listed in School Marketplace.')),
                );
              }
            },
            child: const Text('List Item'),
          ),
        ],
      ),
    );
  }

  void _showCartCheckout(
    BuildContext context,
    String schoolId,
    String profileId,
    List<MarketplaceItemModel> allItems,
    String currency,
  ) {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty. Add items first.')),
      );
      return;
    }

    final cartItems = allItems.where((item) => _cart.containsKey(item.id)).toList();
    double displayedTotal = 0.0;
    for (final item in cartItems) {
      displayedTotal += item.price * (_cart[item.id] ?? 1);
    }
    var placing = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cart Checkout', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...cartItems.map((item) {
                final qty = _cart[item.id] ?? 1;
                return ListTile(
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$currency ${item.price.toStringAsFixed(2)} × $qty'),
                  trailing: Text(
                    '$currency ${(item.price * qty).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
                  ),
                );
              }),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '$currency ${displayedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.success),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Final price and stock are validated by the server when the order is placed.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: placing
                    ? null
                    : () async {
                        setSheetState(() => placing = true);
                        try {
                          final orderItems = cartItems
                              .map((item) => {
                                    'item_id': item.id,
                                    'quantity': _cart[item.id] ?? 1,
                                  })
                              .toList(growable: false);

                          final order = await ref
                              .read(marketplaceControllerProvider)
                              .placeOrder(items: orderItems);

                          if (!mounted) return;
                          setState(_cart.clear);
                          ref.invalidate(marketplaceItemsProvider(schoolId));
                          ref.invalidate(marketplaceOrdersProvider((schoolId, profileId)));

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Order ${order.id.substring(0, 8)} placed successfully.',
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Order could not be placed: $error')),
                            );
                            setSheetState(() => placing = false);
                          }
                        }
                      },
                icon: placing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_bag_rounded),
                label: const Text('Place Order'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final schoolId = session.schoolId;
    final itemsAsync = ref.watch(marketplaceItemsProvider(schoolId));
    final ordersAsync = ref.watch(marketplaceOrdersProvider((schoolId, session.profileId)));
    final currency = ref.watch(marketplaceCurrencyProvider(schoolId)).valueOrNull ?? 'Currency';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('School Marketplace'),
          actions: [
            IconButton(
              onPressed: () {
                final allItems = itemsAsync.value ?? [];
                _showCartCheckout(
                  context,
                  schoolId,
                  session.profileId,
                  allItems,
                  currency,
                );
              },
              icon: Badge(
                label: Text('${_cart.values.fold(0, (a, b) => a + b)}'),
                isLabelVisible: _cart.isNotEmpty,
                child: const Icon(Icons.shopping_cart_rounded),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.storefront_rounded), text: 'Browse Catalog'),
              Tab(icon: Icon(Icons.receipt_long_rounded), text: 'My Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 54, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        const Text('No items listed in your school marketplace yet.', style: TextStyle(color: AppTheme.textMuted)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showSellItemDialog(
                            context,
                            schoolId,
                            session.profileId,
                            currency,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Sell First Item'),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final inCart = _cart[item.id] ?? 0;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 70,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.checkroom_rounded, size: 36, color: AppTheme.primary),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Text(
                              '$currency ${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seller: ${item.seller?.fullName ?? "School Community"}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: item.stockQuantity <= 0
                                    ? null
                                    : () {
                                        if (inCart >= item.stockQuantity) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Maximum available stock is already in your cart.')),
                                          );
                                          return;
                                        }
                                        setState(() => _cart[item.id] = inCart + 1);
                                      },
                                icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                                label: Text(
                                  item.stockQuantity <= 0
                                      ? 'Sold Out'
                                      : inCart > 0
                                          ? 'Add ($inCart)'
                                          : 'Add to Cart',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading catalog: $e')),
            ),
            ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(
                    child: Text('No orders placed yet.', style: TextStyle(color: AppTheme.textMuted)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final order = orders[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.cardDark,
                          child: Icon(Icons.receipt_rounded, color: AppTheme.secondary),
                        ),
                        title: Text(
                          'Order #${order.id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Date: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} • Recorded total: ${order.totalAmount.toStringAsFixed(2)}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading orders: $e')),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showSellItemDialog(
            context,
            schoolId,
            session.profileId,
            currency,
          ),
          icon: const Icon(Icons.sell_rounded),
          label: const Text('Sell Item'),
        ),
      ),
    );
  }
}
