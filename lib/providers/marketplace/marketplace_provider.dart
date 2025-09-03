import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/stellar_service.dart';
import '../../services/marketplace/payment_service.dart';
import '../../services/marketplace/search_service.dart';
import '../../models/marketplace/listing.dart';
import '../../models/marketplace/order.dart';
import '../../models/marketplace/messaging.dart';
import '../../models/marketplace/review_system.dart';
import '../../models/marketplace/vendor_profile.dart';

/// Comprehensive marketplace provider managing all marketplace operations
class EnhancedMarketplaceProvider extends ChangeNotifier {
  final StellarService _stellarService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late final MarketplacePaymentService _paymentService;
  late final AdvancedSearchService _searchService;
  
  // Core data
  List<Product> _products = [];
  List<Service> _services = [];
  List<VendorProfile> _vendors = [];
  List<MarketplaceOrder> _userOrders = [];
  List<MarketplaceOrder> _vendorOrders = [];
  List<Conversation> _conversations = [];
  List<Review> _reviews = [];
  
  // Loading states
  bool _isLoading = false;
  bool _isLoadingProducts = false;
  bool _isLoadingServices = false;
  bool _isLoadingOrders = false;
  
  // Error states
  String? _errorMessage;
  
  // Pagination
  DocumentSnapshot? _lastProductDoc;
  DocumentSnapshot? _lastServiceDoc;
  bool _hasMoreProducts = true;
  bool _hasMoreServices = true;
  
  // Search state
  SearchResults? _searchResults;
  String _currentSearchQuery = '';
  
  // Current user context
  String? _currentUserId;
  bool _isVendor = false;
  
  EnhancedMarketplaceProvider({
    required StellarService stellarService,
  }) : _stellarService = stellarService {
    _paymentService = MarketplacePaymentService(stellarService: stellarService);
    _searchService = AdvancedSearchService();
    _initialize();
  }
  
  // Getters
  List<Product> get products => _products;
  List<Service> get services => _services;
  List<VendorProfile> get vendors => _vendors;
  List<MarketplaceOrder> get userOrders => _userOrders;
  List<MarketplaceOrder> get vendorOrders => _vendorOrders;
  List<Conversation> get conversations => _conversations;
  List<Review> get reviews => _reviews;
  
  bool get isLoading => _isLoading;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingServices => _isLoadingServices;
  bool get isLoadingOrders => _isLoadingOrders;
  String? get errorMessage => _errorMessage;
  
  SearchResults? get searchResults => _searchResults;
  String get currentSearchQuery => _currentSearchQuery;
  
  bool get hasMoreProducts => _hasMoreProducts;
  bool get hasMoreServices => _hasMoreServices;
  bool get isVendor => _isVendor;
  
  /// Initialize provider
  Future<void> _initialize() async {
    try {
      await loadInitialData();
    } catch (e) {
      _setError('Failed to initialize marketplace: ${e.toString()}');
    }
  }
  
  /// Retry initialization
  Future<void> retryInitialization() async {
    _clearError();
    await _initialize();
  }
  
  /// Set current user context
  void setUser(String userId, {bool isVendor = false}) {
    _currentUserId = userId;
    _isVendor = isVendor;
    _loadUserData();
    notifyListeners();
  }
  
  /// Load initial marketplace data
  Future<void> loadInitialData() async {
    _setLoading(true);
    
    try {
      await Future.wait([
        _loadFeaturedProducts(),
        _loadFeaturedServices(),
        _loadTopVendors(),
      ]);
    } catch (e) {
      _setError('Failed to load initial data: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Load user-specific data
  Future<void> _loadUserData() async {
    if (_currentUserId == null) return;
    
    try {
      await Future.wait([
        _loadUserOrders(),
        _loadUserConversations(),
        if (_isVendor) _loadVendorOrders(),
      ]);
    } catch (e) {
      _setError('Failed to load user data: ${e.toString()}');
    }
  }
  
  /// Load featured products
  Future<void> _loadFeaturedProducts({bool loadMore = false}) async {
    if (!loadMore) {
      _isLoadingProducts = true;
      _products.clear();
      _lastProductDoc = null;
      _hasMoreProducts = true;
      notifyListeners();
    }
    
    if (!_hasMoreProducts) return;
    
    try {
      Query query = _firestore
          .collection('marketplace_products')
          .where('status', isEqualTo: ListingStatus.active.toString())
          .orderBy('featured', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(20);
      
      if (_lastProductDoc != null) {
        query = query.startAfterDocument(_lastProductDoc!);
      }
      
      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        _hasMoreProducts = false;
      } else {
        _lastProductDoc = snapshot.docs.last;
        
        final newProducts = snapshot.docs.map((doc) {
          return Product.fromJson(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        _products.addAll(newProducts);
      }
      
    } catch (e) {
      _setError('Failed to load products: ${e.toString()}');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }
  
  /// Load featured services
  Future<void> _loadFeaturedServices({bool loadMore = false}) async {
    if (!loadMore) {
      _isLoadingServices = true;
      _services.clear();
      _lastServiceDoc = null;
      _hasMoreServices = true;
      notifyListeners();
    }
    
    if (!_hasMoreServices) return;
    
    try {
      Query query = _firestore
          .collection('marketplace_services')
          .where('status', isEqualTo: ListingStatus.active.toString())
          .orderBy('featured', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(20);
      
      if (_lastServiceDoc != null) {
        query = query.startAfterDocument(_lastServiceDoc!);
      }
      
      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        _hasMoreServices = false;
      } else {
        _lastServiceDoc = snapshot.docs.last;
        
        final newServices = snapshot.docs.map((doc) {
          return Service.fromJson(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        _services.addAll(newServices);
      }
      
    } catch (e) {
      _setError('Failed to load services: ${e.toString()}');
    } finally {
      _isLoadingServices = false;
      notifyListeners();
    }
  }
  
  /// Load top vendors
  Future<void> _loadTopVendors() async {
    try {
      final snapshot = await _firestore
          .collection('vendor_profiles')
          .where('status', isEqualTo: VendorStatus.active.toString())
          .orderBy('analytics.rating', descending: true)
          .limit(10)
          .get();
      
      _vendors = snapshot.docs.map((doc) {
        return VendorProfile.fromJson(doc.data(), doc.id);
      }).toList();
      
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to load vendors: ${e.toString()}');
    }
  }
  
  /// Search marketplace
  Future<void> search(SearchQuery query) async {
    _setLoading(true);
    _currentSearchQuery = query.query;
    
    try {
      _searchResults = await _searchService.search(query);
      notifyListeners();
    } catch (e) {
      _setError('Search failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Get search suggestions
  Future<List<SearchSuggestion>> getSearchSuggestions(String query) async {
    try {
      return await _searchService.getSuggestions(query);
    } catch (e) {
      return [];
    }
  }
  
  /// Purchase product
  Future<bool> purchaseProduct({
    required String productId,
    required int quantity,
    required Map<String, dynamic> selectedVariant,
    required String shippingAddress,
    required PaymentMethod paymentMethod,
    bool useEscrow = true,
  }) async {
    if (_currentUserId == null) {
      _setError('User not authenticated');
      return false;
    }
    
    try {
      _setLoading(true);
      
      // Get product details
      final productDoc = await _firestore
          .collection('marketplace_products')
          .doc(productId)
          .get();
      
      if (!productDoc.exists) {
        _setError('Product not found');
        return false;
      }
      
      final product = Product.fromJson(productDoc.data()!, productId);
      
      // Create order
      final orderId = await _createProductOrder(
        product: product,
        quantity: quantity,
        selectedVariant: selectedVariant,
        shippingAddress: shippingAddress,
      );
      
      // Process payment
      final paymentResult = await _paymentService.processOrderPayment(
        orderId: orderId,
        buyerId: _currentUserId!,
        amount: product.price * quantity,
        currency: 'AKOFA',
        paymentMethod: paymentMethod,
        useEscrow: useEscrow,
      );
      
      if (paymentResult.success) {
        await _loadUserOrders();
        _clearError();
        return true;
      } else {
        _setError(paymentResult.message);
        return false;
      }
      
    } catch (e) {
      _setError('Purchase failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Order service
  Future<bool> orderService({
    required String serviceId,
    required Map<String, dynamic> selectedPackage,
    required Map<String, dynamic> requirements,
    required PaymentMethod paymentMethod,
    bool useEscrow = true,
  }) async {
    if (_currentUserId == null) {
      _setError('User not authenticated');
      return false;
    }
    
    try {
      _setLoading(true);
      
      // Get service details
      final serviceDoc = await _firestore
          .collection('marketplace_services')
          .doc(serviceId)
          .get();
      
      if (!serviceDoc.exists) {
        _setError('Service not found');
        return false;
      }
      
      final service = Service.fromJson(serviceDoc.data()!, serviceId);
      final packagePrice = (selectedPackage['price'] as num).toDouble();
      
      // Create order
      final orderId = await _createServiceOrder(
        service: service,
        selectedPackage: selectedPackage,
        requirements: requirements,
      );
      
      // Process payment
      final paymentResult = await _paymentService.processOrderPayment(
        orderId: orderId,
        buyerId: _currentUserId!,
        amount: packagePrice,
        currency: 'AKOFA',
        paymentMethod: paymentMethod,
        useEscrow: useEscrow,
      );
      
      if (paymentResult.success) {
        await _loadUserOrders();
        _clearError();
        return true;
      } else {
        _setError(paymentResult.message);
        return false;
      }
      
    } catch (e) {
      _setError('Service order failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Load user orders
  Future<void> _loadUserOrders() async {
    if (_currentUserId == null) return;
    
    try {
      _isLoadingOrders = true;
      notifyListeners();
      
      final snapshot = await _firestore
          .collection('marketplace_orders')
          .where('buyerId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get();
      
      _userOrders = snapshot.docs.map((doc) {
        return MarketplaceOrder.fromJson(doc.data(), doc.id);
      }).toList();
      
    } catch (e) {
      _setError('Failed to load orders: ${e.toString()}');
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }
  
  /// Load vendor orders
  Future<void> _loadVendorOrders() async {
    if (_currentUserId == null) return;
    
    try {
      final snapshot = await _firestore
          .collection('marketplace_orders')
          .where('vendorId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get();
      
      _vendorOrders = snapshot.docs.map((doc) {
        return MarketplaceOrder.fromJson(doc.data(), doc.id);
      }).toList();
      
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to load vendor orders: ${e.toString()}');
    }
  }
  
  /// Load user conversations
  Future<void> _loadUserConversations() async {
    if (_currentUserId == null) return;
    
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: _currentUserId)
          .orderBy('updatedAt', descending: true)
          .get();
      
      _conversations = snapshot.docs.map((doc) {
        return Conversation.fromJson(doc.data(), doc.id);
      }).toList();
      
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to load conversations: ${e.toString()}');
    }
  }
  
  /// Update order status (vendor action)
  Future<bool> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? notes,
  }) async {
    if (_currentUserId == null) {
      _setError('User not authenticated');
      return false;
    }
    
    try {
      // Update order status
      await _firestore.collection('marketplace_orders').doc(orderId).update({
        'status': newStatus.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Add timeline event
      await _firestore.collection('marketplace_orders').doc(orderId).update({
        'timeline': FieldValue.arrayUnion([
          {
            'timestamp': FieldValue.serverTimestamp(),
            'event': 'status_updated',
            'description': 'Order status updated to ${newStatus.displayName}',
            'actorId': _currentUserId,
            'actorType': 'vendor',
            'data': {'newStatus': newStatus.toString(), 'notes': notes},
          }
        ]),
      });
      
      // Reload orders
      await Future.wait([
        _loadUserOrders(),
        if (_isVendor) _loadVendorOrders(),
      ]);
      
      return true;
      
    } catch (e) {
      _setError('Failed to update order status: ${e.toString()}');
      return false;
    }
  }
  
  /// Release escrow (admin/auto action)
  Future<bool> releaseEscrow({
    required String escrowId,
    required String reason,
  }) async {
    try {
      final result = await _paymentService.releaseEscrow(
        escrowId: escrowId,
        actorId: _currentUserId ?? 'system',
        reason: reason,
      );
      
      if (result.success) {
        await _loadUserOrders();
        if (_isVendor) await _loadVendorOrders();
        _clearError();
        return true;
      } else {
        _setError(result.message);
        return false;
      }
      
    } catch (e) {
      _setError('Failed to release escrow: ${e.toString()}');
      return false;
    }
  }
  
  /// Request refund
  Future<bool> requestRefund({
    required String orderId,
    required String reason,
  }) async {
    if (_currentUserId == null) {
      _setError('User not authenticated');
      return false;
    }
    
    try {
      // Get order details
      final orderDoc = await _firestore
          .collection('marketplace_orders')
          .doc(orderId)
          .get();
      
      if (!orderDoc.exists) {
        _setError('Order not found');
        return false;
      }
      
      final orderData = orderDoc.data()!;
      final escrowId = orderData['escrowId'] as String?;
      
      if (escrowId != null) {
        // Refund from escrow
        final result = await _paymentService.refundEscrow(
          escrowId: escrowId,
          actorId: _currentUserId!,
          reason: reason,
        );
        
        if (result.success) {
          await _loadUserOrders();
          _clearError();
          return true;
        } else {
          _setError(result.message);
          return false;
        }
      } else {
        _setError('No escrow found for this order');
        return false;
      }
      
    } catch (e) {
      _setError('Refund request failed: ${e.toString()}');
      return false;
    }
  }
  
  /// Load more products
  Future<void> loadMoreProducts() async {
    await _loadFeaturedProducts(loadMore: true);
  }
  
  /// Load more services
  Future<void> loadMoreServices() async {
    await _loadFeaturedServices(loadMore: true);
  }
  
  /// Refresh all data
  Future<void> refresh() async {
    _clearError();
    await loadInitialData();
    if (_currentUserId != null) {
      await _loadUserData();
    }
  }
  
  /// Helper methods for creating orders
  
  Future<String> _createProductOrder({
    required Product product,
    required int quantity,
    required Map<String, dynamic> selectedVariant,
    required String shippingAddress,
  }) async {
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    
    final orderData = {
      'id': orderId,
      'buyerId': _currentUserId!,
      'vendorId': product.vendorId,
      'type': OrderType.product.toString(),
      'status': OrderStatus.pending.toString(),
      'paymentStatus': PaymentStatus.pending.toString(),
      'items': [
        {
          'listingId': product.id,
          'title': product.title,
          'imageUrl': product.images.isNotEmpty ? product.images.first : '',
          'type': OrderItemType.product.toString(),
          'quantity': quantity,
          'unitPrice': product.price,
          'totalPrice': product.price * quantity,
          'variant': selectedVariant,
        }
      ],
      'subtotal': product.price * quantity,
      'shippingCost': 0.0, // Calculate based on shipping method
      'taxAmount': 0.0,
      'discountAmount': 0.0,
      'totalAmount': product.price * quantity,
      'currency': 'AKOFA',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'timeline': [
        {
          'timestamp': FieldValue.serverTimestamp(),
          'event': 'order_created',
          'description': 'Order created',
          'actorId': _currentUserId!,
          'actorType': 'buyer',
        }
      ],
      'shipping': {
        'method': 'standard',
        'cost': 0.0,
        'estimatedDays': 7,
        'address': shippingAddress,
      },
      'billing': {
        'paymentMethod': 'akofa',
        'paidAmount': product.price * quantity,
        'currency': 'AKOFA',
      },
    };
    
    await _firestore.collection('marketplace_orders').doc(orderId).set(orderData);
    
    return orderId;
  }
  
  Future<String> _createServiceOrder({
    required Service service,
    required Map<String, dynamic> selectedPackage,
    required Map<String, dynamic> requirements,
  }) async {
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    final packagePrice = (selectedPackage['price'] as num).toDouble();
    
    final orderData = {
      'id': orderId,
      'buyerId': _currentUserId!,
      'vendorId': service.vendorId,
      'type': OrderType.service.toString(),
      'status': OrderStatus.pending.toString(),
      'paymentStatus': PaymentStatus.pending.toString(),
      'items': [
        {
          'listingId': service.id,
          'title': service.title,
          'imageUrl': service.images.isNotEmpty ? service.images.first : '',
          'type': OrderItemType.service.toString(),
          'quantity': 1,
          'unitPrice': packagePrice,
          'totalPrice': packagePrice,
          'serviceDetails': {
            'package': selectedPackage,
            'requirements': requirements,
          },
        }
      ],
      'subtotal': packagePrice,
      'shippingCost': 0.0,
      'taxAmount': 0.0,
      'discountAmount': 0.0,
      'totalAmount': packagePrice,
      'currency': 'AKOFA',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'timeline': [
        {
          'timestamp': FieldValue.serverTimestamp(),
          'event': 'service_ordered',
          'description': 'Service order created',
          'actorId': _currentUserId!,
          'actorType': 'buyer',
        }
      ],
      'billing': {
        'paymentMethod': 'akofa',
        'paidAmount': packagePrice,
        'currency': 'AKOFA',
      },
    };
    
    await _firestore.collection('marketplace_orders').doc(orderId).set(orderData);
    
    return orderId;
  }
  
  /// State management helpers
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _clearError();
    notifyListeners();
  }
  
  void _setError(String error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
