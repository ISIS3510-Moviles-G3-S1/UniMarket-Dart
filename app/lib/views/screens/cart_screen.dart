import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_provider.dart';
import '../views/cart_view.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: Provider.of<CartProvider>(context),
      child: const CartView(),
    );
  }
}
