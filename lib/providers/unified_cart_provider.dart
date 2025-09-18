import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import '../models/unified_cart_item.dart';
import '../models/product.dart';
import '../models/service.dart';

/// Enhanced cart provider with support for products, services, and persistence
class UnifiedCartProvider extends ChangeNotifier {
  final List<UnifiedCartItem> _items = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  String? _error;

  // Getters
  List<UnifiedCartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Get total price for all items
  double get totalPrice => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Get items grouped by vendor
  Map<String, List<UnifiedCartItem>> get itemsByVendor {
    final Map<String, List<UnifiedCartItem>> grouped = {};
    for (final item in _items) {
      final vendorId = item.vendorId;
      grouped[vendorId] ??= [];
      grouped[vendorId]!.add(item);
    }
    return grouped;
  }

  /// Get product items only
  List<UnifiedCartItem> get productItems => 
      _items.where((item) => item.type == CartItemType.product).toList();

  /// Get service items only
  List<UnifiedCartItem> get serviceItems => 
      _items.where((item) => item.type == CartItemType.service).toList();

  /// Initialize cart (load from persistence)
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadCartFromPersistence();
    } catch (e) {
      _setError('Failed to load cart: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== PRODUCT METHODS ====================

  /// Add product to cart
  Future<void> addProduct(Product product, {int quantity = 1}) async {
    try {
      final existingIndex = _items.indexWhere(
        (item) => item.type == CartItemType.product && item.product?.id == product.id,
      );

      if (existingIndex >= 0) {
        // Update existing item quantity
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: _items[existingIndex].quantity + quantity,
        );
      } else {
        // Add new item
        _items.add(UnifiedCartItem.product(
          product: product,
          quantity: quantity,
        ));
      }

      await _saveCartToPersistence();
      notifyListeners();
    } catch (e) {
      _setError('Failed to add product to cart: $e');
    }
  }

  /// Remove product from cart
  Future<void> removeProduct(String productId) async {
    try {
      _items.removeWhere(
        (item) => item.type == CartItemType.product && item.product?.id == productId,
      );
      
      await _saveCartToPersistence();
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove product from cart: $e');
    }
  }

  /// Update product quantity
  Future<void> updateProductQuantity(String productId, int quantity) async {
    try {
      final index = _items.indexWhere(
        (item) => item.type == CartItemType.product && item.product?.id == productId,
      );

      if (index >= 0) {
        if (quantity <= 0) {
          _items.removeAt(index);
        } else {
          _items[index] = _items[index].copyWith(quantity: quantity);
        }
        
        await _saveCartToPersistence();
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to update product quantity: $e');
    }
  }

  // ==================== SERVICE METHODS ====================

  /// Add service to cart
  Future<void> addService(
    Service service, {
    required Map<String, dynamic> servicePackage,
    Map<String, String>? requirements,
    int quantity = 1,
  }) async {
    try {
      final packageName = servicePackage['name'] as String?;
      final existingIndex = _items.indexWhere(
        (item) => 
          item.type == CartItemType.service && 
          item.service?.id == service.id &&
          item.servicePackage?['name'] == packageName,
      );

      if (existingIndex >= 0) {
        // For services, typically replace rather than add quantity
        // But allow quantity for services that support it
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: _items[existingIndex].quantity + quantity,
          serviceRequirements: requirements,
        );
      } else {
        // Add new service item
        _items.add(UnifiedCartItem.service(
          service: service,
          servicePackage: servicePackage,
          requirements: requirements,
          quantity: quantity,
        ));
      }

      await _saveCartToPersistence();
      notifyListeners();
    } catch (e) {
      _setError('Failed to add service to cart: $e');
    }
  }

  /// Remove service from cart
  Future<void> removeService(String serviceId, String packageName) async {
    try {
      _items.removeWhere(
        (item) => 
          item.type == CartItemType.service && 
          item.service?.id == serviceId &&
          item.servicePackage?['name'] == packageName,
      );
      
      await _saveCartToPersistence();
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove service from cart: $e');
    }
  }

  /// Update service requirements
  Future<void> updateServiceRequirements(
    String serviceId, 
    String packageName, 
    Map<String, String> requirements,
  ) async {
    try {
      final index = _items.indexWhere(
        (item) => 
          item.type == CartItemType.service && 
          item.service?.id == serviceId &&
          item.servicePackage?['name'] == packageName,
      );

      if (index >= 0) {
        _items[index] = _items[index].copyWith(serviceRequirements: requirements);
        await _saveCartToPersistence();
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to update service requirements: $e');
    }
  }

  // ==================== GENERAL CART METHODS ====================

  /// Remove item by unified cart item ID
  Future<void> removeItem(String itemId) async {
    try {
      _items.removeWhere((item) => item.id == itemId);
      await _saveCartToPersistence();
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove item from cart: $e');
    }
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    try {
      _items.clear();
      await _saveCartToPersistence();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear cart: $e');
    }
  }

  /// Get cart summary
  Map<String, dynamic> getCartSummary() {
    final productCount = productItems.length;
    final serviceCount = serviceItems.length;
    final vendorCount = itemsByVendor.keys.length;

    return {
      'totalItems': itemCount,
      'totalQuantity': totalQuantity,
      'totalPrice': totalPrice,
      'productCount': productCount,
      'serviceCount': serviceCount,
      'vendorCount': vendorCount,
      'categories': _items.map((item) => item.category).toSet().toList(),
    };
  }

  /// Check if a product is in cart
  bool isProductInCart(String productId) {
    return _items.any(
      (item) => item.type == CartItemType.product && item.product?.id == productId,
    );
  }

  /// Check if a service package is in cart
  bool isServiceInCart(String serviceId, String packageName) {
    return _items.any(
      (item) => 
        item.type == CartItemType.service && 
        item.service?.id == serviceId &&
        item.servicePackage?['name'] == packageName,
    );
  }

  /// Get product quantity in cart
  int getProductQuantity(String productId) {
    final item = _items.firstWhere(
      (item) => item.type == CartItemType.product && item.product?.id == productId,
      orElse: () => UnifiedCartItem.product(
        product: Product(
          id: '',
          vendorId: '',
          name: '',
          description: '',
          images: [],
          price: 0.0,
          inventory: 0,
          category: '',
          subcategory: '',
          shippingOptions: [],
          createdAt: DateTime.now(),
        ),
        quantity: 0,
      ),
    );
    return item.quantity;
  }

  // ==================== PERSISTENCE METHODS ====================

  /// Save cart to local storage and cloud (if authenticated)
  Future<void> _saveCartToPersistence() async {
    try {
      // Save to local storage
      await _saveToLocalStorage();
      
      // Save to cloud if user is authenticated
      final user = _auth.currentUser;
      if (user != null) {
        await _saveToCloud(user.uid);
      }
    } catch (e) {
    }
  }

  /// Load cart from persistence
  Future<void> _loadCartFromPersistence() async {
    try {
      final user = _auth.currentUser;
      bool loadedFromCloud = false;
      
      // Try to load from cloud first if user is authenticated
      if (user != null) {
        loadedFromCloud = await _loadFromCloud(user.uid);
      }
      
      // Fallback to local storage if cloud loading failed
      if (!loadedFromCloud) {
        await _loadFromLocalStorage();
      }
    } catch (e) {
    }
  }

  /// Save to SharedPreferences
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = _items.map((item) => item.toJson()).toList();
      await prefs.setString('unified_cart', json.encode(cartData));
    } catch (e) {
    }
  }

  /// Load from SharedPreferences
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString('unified_cart');
      
      if (cartString != null) {
        final cartData = json.decode(cartString) as List<dynamic>;
        _items.clear();
        _items.addAll(
          cartData.map((item) => UnifiedCartItem.fromJson(Map<String, dynamic>.from(item))),
        );
      }
    } catch (e) {
    }
  }

  /// Save to Firestore
  Future<void> _saveToCloud(String userId) async {
    try {
      final cartData = _items.map((item) => item.toJson()).toList();
      await _firestore.collection('user_carts').doc(userId).set({
        'items': cartData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    }
  }

  /// Load from Firestore
  Future<bool> _loadFromCloud(String userId) async {
    try {
      final doc = await _firestore.collection('user_carts').doc(userId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final cartData = data['items'] as List<dynamic>?;
        
        if (cartData != null) {
          _items.clear();
          _items.addAll(
            cartData.map((item) => UnifiedCartItem.fromJson(Map<String, dynamic>.from(item))),
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Sync cart when user logs in
  Future<void> syncOnLogin() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Load from cloud and merge with local cart
      final localItems = List<UnifiedCartItem>.from(_items);
      
      final cloudLoaded = await _loadFromCloud(user.uid);
      if (cloudLoaded) {
        // Merge local items that aren't in cloud
        for (final localItem in localItems) {
          if (!_items.any((item) => item.id == localItem.id)) {
            _items.add(localItem);
          }
        }
        
        // Save merged cart back to cloud
        await _saveToCloud(user.uid);
        notifyListeners();
      }
    }
  }

  /// Clear cart data on logout
  Future<void> clearOnLogout() async {
    try {
      // Keep local cart but clear cloud reference
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('unified_cart');
      
      // Optionally clear cart entirely
      // _items.clear();
      // notifyListeners();
    } catch (e) {
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
