import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  // In-memory cache using Map for fast access
  final Map<String, CartItem> _itemCache = {};

  List<CartItem> get items => List.unmodifiable(_itemCache.values);

  double get subtotal => _itemCache.values.fold(0, (sum, item) => sum + item.price);

  Future<void> addItem(CartItem item) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300)); // Simulate async operation
      print('Adding item to cart: ${item.id}');
      _itemCache[item.id] = item;
      await _saveCartToStorage();
      notifyListeners();
    } catch (e, stack) {
      print('Error adding item to cart: $e\n$stack');
      rethrow;
    }
  }

  Future<void> removeItem(String id) async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      _itemCache.remove(id);
      await _saveCartToStorage();
      notifyListeners();
    } catch (e, stack) {
      print('Error removing item from cart: $e\n$stack');
      rethrow;
    }
  }

  Future<void> clearCart() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      _itemCache.clear();
      await _saveCartToStorage();
      notifyListeners();
    } catch (e, stack) {
      print('Error clearing cart: $e\n$stack');
      rethrow;
    }
  }
  Future<void> loadCart() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      _itemCache.clear();
      if (cartJson != null) {
        final List<dynamic> decoded = jsonDecode(cartJson);
        for (var item in decoded) {
          final cartItem = CartItem(
            id: item['id'],
            name: item['name'],
            seller: item['seller'],
            imageUrl: item['imageUrl'],
            price: (item['price'] as num).toDouble(),
          );
          _itemCache[cartItem.id] = cartItem;
        }
      }
      notifyListeners();
    } catch (e, stack) {
      print('Error loading cart: $e\n$stack');
      rethrow;
    }
  }

  Future<void> _saveCartToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> itemsList = _itemCache.values.map((item) => {
      'id': item.id,
      'name': item.name,
      'seller': item.seller,
      'imageUrl': item.imageUrl,
      'price': item.price,
    }).toList();
    await prefs.setString('cart_items', jsonEncode(itemsList));
  }
}
