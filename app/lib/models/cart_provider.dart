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

  void addItem(CartItem item) {
    print('Adding item to cart: \\${item.id}');
    _items.add(item);
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
