import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/cart_provider.dart';
import '../../models/order_history_provider.dart';
import 'package:provider/provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/browse'),
        ),
        title: const Text('Cart'),
        actions: [
          TextButton(
            onPressed: cart.items.isEmpty ? null : () async {
              try {
                await cart.clearCart();
              } catch (e) {}
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: cart.items.isEmpty
                  ? const Center(child: Text('Your cart is empty.'))
                  : ListView.builder(
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: item.imageUrl.isNotEmpty
                                ? Image.network(item.imageUrl, width: 56, height: 56, fit: BoxFit.cover)
                                : const Icon(Icons.image, size: 56),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(item.seller),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('COP ${item.price.toStringAsFixed(3)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.info_outline, color: Colors.blue),
                                  tooltip: 'View Details',
                                  onPressed: () {
                                    context.go('/item/${item.id}');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Remove',
                                  onPressed: () async {
                                    try {
                                      await cart.removeItem(item.id);
                                    } catch (e) {}
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items', style: TextStyle(color: Colors.grey)),
                        Text('${cart.items.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('COP ${cart.subtotal.toStringAsFixed(3)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: cart.items.isEmpty ? null : () async {
                        try {
                          // Save order to SQLite using OrderHistoryProvider
                          final orderHistory = Provider.of<OrderHistoryProvider>(context, listen: false);
                          await orderHistory.addOrder(
                            items: cart.items,
                            subtotal: cart.subtotal,
                            buyer: 'buyer_id', // Replace with actual user info
                            pickupLocation: 'pickup_location', // Replace as needed
                            paymentDetails: '**** **** **** 1234', // Masked payment info
                          );
                          await cart.clearCart();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Purchase successful!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Checkout failed.')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      child: const Text('Checkout'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shopping_bag),
                      label: const Text('Continue Shopping'),
                      onPressed: () {
                        context.go('/browse');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
