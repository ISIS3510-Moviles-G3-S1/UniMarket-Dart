import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/cart_provider.dart';
import '../data/order_history_database.dart';
import 'dart:convert';

class PendingOrder {
  final Map<String, dynamic> order;
  PendingOrder(this.order);
}

class OrderHistoryProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _orders = [];
  final List<PendingOrder> _pendingOrders = [];

  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);
  List<PendingOrder> get pendingOrders => List.unmodifiable(_pendingOrders);

  Future<void> addOrder({
    required List<CartItem> items,
    required double subtotal,
    required String buyer,
    required String pickupLocation,
    required String paymentDetails,
    bool isOffline = false,
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
    if (kIsWeb) {
      _orders.insert(0, order);
      notifyListeners();
      return;
    }
    if (isOffline) {
      _pendingOrders.add(PendingOrder(order));
      _orders.insert(0, order);
      notifyListeners();
      return;
    }
    await OrderHistoryDatabase().insertOrder(order);
    _orders.insert(0, order);
    notifyListeners();
  }

  Future<void> loadOrders() async {
    if (kIsWeb) {
      notifyListeners();
      return;
    }
    final dbOrders = await OrderHistoryDatabase().getOrders();
    _orders.clear();
    _orders.addAll(dbOrders);
    notifyListeners();
  }

  Future<void> syncPendingOrders() async {
    if (kIsWeb) return;
    for (final pending in List<PendingOrder>.from(_pendingOrders)) {
      await OrderHistoryDatabase().insertOrder(pending.order);
      _pendingOrders.remove(pending);
    }
    notifyListeners();
  }
}
