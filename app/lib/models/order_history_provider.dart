import 'package:flutter/material.dart';
import '../models/cart_provider.dart';
import '../data/order_history_database.dart';
import 'dart:convert';

class OrderHistoryProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _orders = [];

  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);

  Future<void> addOrder({
    required List<CartItem> items,
    required double subtotal,
    required String buyer,
    required String pickupLocation,
    required String paymentDetails,
  }) async {
    final order = {
      'id': UniqueKey().toString(),
      'date': DateTime.now().toIso8601String(),
      'subtotal': subtotal,
      'buyer': buyer,
      'pickupLocation': pickupLocation,
      'paymentDetails': paymentDetails,
      'productSnapshot': jsonEncode(items.map((e) => {
        'id': e.id,
        'name': e.name,
        'seller': e.seller,
        'imageUrl': e.imageUrl,
        'price': e.price,
      }).toList()),
    };
    await OrderHistoryDatabase().insertOrder(order);
    _orders.insert(0, order);
    notifyListeners();
  }

  Future<void> loadOrders() async {
    final dbOrders = await OrderHistoryDatabase().getOrders();
    _orders.clear();
    _orders.addAll(dbOrders);
    notifyListeners();
  }
}
