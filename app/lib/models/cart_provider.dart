import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String name;
  final String seller;
  final String imageUrl;
  final double price;

  CartItem({
    required this.id,
    required this.name,
    required this.seller,
    required this.imageUrl,
    required this.price,
  });
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.price);

  Future<void> addItem(CartItem item) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300)); // Simulate async operation
      print('Adding item to cart: \\${item.id}');
      _items.add(item);
      notifyListeners();
    } catch (e, stack) {
      print('Error adding item to cart: \\${e}\n\\${stack}');
      rethrow;
    }
  }

  Future<void> removeItem(String id) async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      _items.removeWhere((item) => item.id == id);
      notifyListeners();
    } catch (e, stack) {
      print('Error removing item from cart: \\${e}\n\\${stack}');
      rethrow;
    }
  }

  Future<void> clearCart() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      _items.clear();
      notifyListeners();
    } catch (e, stack) {
      print('Error clearing cart: \\${e}\n\\${stack}');
      rethrow;
    }
  }
  Future<void> loadCart() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      // TODO: Load cart from storage
      notifyListeners();
    } catch (e, stack) {
      print('Error loading cart: \\${e}\n\\${stack}');
      rethrow;
    }
  }
}
