import 'package:flutter/material.dart';
import '../models/product.dart';

class WishlistProvider extends ChangeNotifier {
  final List<Product> _items = [];

  List<Product> get items => List.unmodifiable(_items);

  void addToWishlist(Product product) {
    if (!_items.any((item) => item.id == product.id)) {
      _items.add(product);
      notifyListeners();
    }
  }

  void removeFromWishlist(String productId) {
    _items.removeWhere((item) => item.id == productId);
    notifyListeners();
  }

  void moveToCart(Product product, void Function(Product) addToCart) {
    removeFromWishlist(product.id);
    addToCart(product);
  }
} 