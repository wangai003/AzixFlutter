import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/service.dart';
import '../../providers/unified_cart_provider.dart';
import '../../theme/marketplace_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../utils/marketplace_categories.dart';
import 'functional_search_screen.dart';
import 'functional_cart_screen.dart';
import '../product_detail_screen.dart';
import '../service_detail_screen.dart';
import '../customer/customer_orders_screen.dart';
import '../vendor/vendor_registration_screen.dart';
import '../../widgets/enhanced_image_widget.dart';

/// Fully functional responsive marketplace without dummy data
class FunctionalResponsiveMarketplace extends StatefulWidget {
  const FunctionalResponsiveMarketplace({Key? key}) : super(key: key);

  @override
  State<FunctionalResponsiveMarketplace> createState() => _FunctionalResponsiveMarketplaceState();
}

class _FunctionalResponsiveMarketplaceState extends State<FunctionalResponsiveMarketplace>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = 'All'; // Reset category when switching tabs
        });
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      body: SafeArea(
        child: Column(
          children: [
            _buildResponsiveHeader(),
            _buildResponsiveSearchSection(),
            _buildResponsiveTabSection(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResponsiveHeader() {
    return Container(
      padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
      decoration: const BoxDecoration(
        color: MarketplaceTheme.white,
        boxShadow: [MarketplaceTheme.smallShadow],
      ),
      child: ResponsiveLayout.isTabletOrDesktop(context)
          ? _buildDesktopHeader()
          : _buildMobileHeader(),
    );
  }
  
  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketplace',
                    style: MarketplaceTheme.headingLarge.copyWith(
                      color: MarketplaceTheme.primaryBlue,
                      fontSize: ResponsiveLayout.getResponsiveFontSize(context, 24),
                    ),
                  ),
                  Text(
                    'Buy & sell with confidence',
                    style: MarketplaceTheme.bodyMedium.copyWith(
                      fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ],
    );
  }
  
  Widget _buildDesktopHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marketplace',
                style: MarketplaceTheme.headingLarge.copyWith(
                  color: MarketplaceTheme.primaryBlue,
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 32),
                ),
              ),
              Text(
                'Discover amazing products & services from verified vendors',
                style: MarketplaceTheme.bodyMedium.copyWith(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
                ),
              ),
            ],
          ),
        ),
        _buildActionButtons(),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search button
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FunctionalSearchScreen()),
          ),
          icon: const Icon(Icons.search),
          color: MarketplaceTheme.primaryBlue,
        ),
        // Cart button with real data
        Consumer<UnifiedCartProvider>(
          builder: (context, cart, _) {
            return Stack(
              children: [
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FunctionalCartScreen()),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined),
                  color: MarketplaceTheme.primaryBlue,
                ),
                if (cart.totalQuantity > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: MarketplaceTheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        cart.totalQuantity > 9 ? '9+' : cart.totalQuantity.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // Orders button
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerOrdersScreen()),
          ),
          icon: const Icon(Icons.receipt_long),
          color: MarketplaceTheme.primaryBlue,
        ),
        // Become vendor button (conditionally shown)
        _buildVendorButton(),
      ],
    );
  }
  
  Widget _buildVendorButton() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final userRole = userData['role'] ?? 'user';
        final isVendor = userRole == 'vendor' || userRole == 'goods_vendor' || userRole == 'service_vendor';
        
        if (isVendor) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(left: 8),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorRegistrationScreen()),
            ),
            icon: const Icon(Icons.store, size: 16),
            label: Text(
              ResponsiveLayout.isMobile(context) ? 'Sell' : 'Start Selling',
              style: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketplaceTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.getResponsivePadding(context),
                vertical: 8,
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildResponsiveSearchSection() {
    return Container(
      padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
      color: MarketplaceTheme.white,
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: MarketplaceTheme.gray50,
              borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
              border: Border.all(color: MarketplaceTheme.gray200),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products, services...',
                hintStyle: MarketplaceTheme.bodyMedium.copyWith(
                  color: MarketplaceTheme.gray400,
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
                ),
                prefixIcon: const Icon(Icons.search, color: MarketplaceTheme.gray400),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveLayout.getResponsivePadding(context),
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          
          SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 12)),
          
          // Dynamic categories from Firestore
          _buildDynamicCategories(),
        ],
      ),
    );
  }
  
  Widget _buildDynamicCategories() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _buildCategoryChips(),
      ),
    );
  }
  
  List<Widget> _buildCategoryChips() {
    final List<String> displayCategories = ['All'];
    
    // Add relevant categories based on current tab
    if (_tabController.index == 0) {
      // Products tab - show goods categories
      displayCategories.addAll(MarketplaceCategories.getGoodsCategories());
    } else {
      // Services tab - show service categories  
      displayCategories.addAll(MarketplaceCategories.getServiceCategories());
    }
    
    return displayCategories.map((category) {
      final isSelected = _selectedCategory == category;
      return Container(
        margin: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _selectedCategory = category),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.getResponsivePadding(context) * 0.75,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected 
                  ? MarketplaceTheme.primaryBlue 
                  : MarketplaceTheme.white,
              borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
              border: Border.all(
                color: isSelected 
                    ? MarketplaceTheme.primaryBlue 
                    : MarketplaceTheme.gray200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (category != 'All') ...[
                  Icon(
                    _getCategoryIconData(MarketplaceCategories.getCategoryIcon(category)),
                    size: 16,
                    color: isSelected ? Colors.white : MarketplaceTheme.gray600,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    category,
                    style: MarketplaceTheme.labelMedium.copyWith(
                      color: isSelected ? Colors.white : MarketplaceTheme.gray600,
                      fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
  
  IconData _getCategoryIconData(String iconName) {
    switch (iconName) {
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'agriculture':
        return Icons.agriculture;
      case 'handmade':
        return Icons.handyman;
      case 'restaurant':
        return Icons.restaurant;
      case 'construction':
        return Icons.construction;
      case 'school':
        return Icons.school;
      case 'directions_car':
        return Icons.directions_car;
      case 'computer':
        return Icons.computer;
      case 'home_repair_service':
        return Icons.home_repair_service;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'design_services':
        return Icons.design_services;
      case 'event':
        return Icons.event;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'engineering':
        return Icons.engineering;
      case 'menu_book':
        return Icons.menu_book;
      case 'build':
        return Icons.build;
      case 'account_balance':
        return Icons.account_balance;
      case 'hotel':
        return Icons.hotel;
      default:
        return Icons.category;
    }
  }
  
  Widget _buildResponsiveTabSection() {
    return Container(
      color: MarketplaceTheme.white,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Products'),
          Tab(text: 'Services'),
        ],
        labelColor: MarketplaceTheme.primaryBlue,
        unselectedLabelColor: MarketplaceTheme.gray500,
        indicatorColor: MarketplaceTheme.primaryBlue,
        indicatorWeight: 3,
        labelStyle: TextStyle(
          fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
        ),
      ),
    );
  }
  
  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildProductsGrid(),
        _buildServicesGrid(),
      ],
    );
  }
  
  Widget _buildProductsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid();
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No products found', Icons.inventory_2);
        }
        
        final products = snapshot.data!.docs
            .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        
        return _buildResponsiveProductGrid(products);
      },
    );
  }
  
  Widget _buildServicesGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getServicesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid();
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No services found', Icons.work);
        }
        
        final services = snapshot.data!.docs
            .map((doc) => Service.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        
        return _buildResponsiveServiceGrid(services);
      },
    );
  }
  
  Stream<QuerySnapshot> _getProductsStream() {
    Query query = FirebaseFirestore.instance.collection('products');
    
    // Apply category filter
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThan: _searchQuery + 'z');
    }
    
    return query.orderBy('createdAt', descending: true).snapshots();
  }
  
  Stream<QuerySnapshot> _getServicesStream() {
    Query query = FirebaseFirestore.instance.collection('services');
    
    // Apply category filter
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('title', isGreaterThanOrEqualTo: _searchQuery)
          .where('title', isLessThan: _searchQuery + 'z');
    }
    
    return query.orderBy('createdAt', descending: true).snapshots();
  }
  
  Widget _buildResponsiveProductGrid(List<Product> products) {
    final crossAxisCount = ResponsiveLayout.getGridCrossAxisCount(context);
    final childAspectRatio = ResponsiveLayout.getGridChildAspectRatio(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {}); // Refresh the stream
      },
      child: GridView.builder(
        padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: ResponsiveLayout.getResponsiveSpacing(context, 12),
          mainAxisSpacing: ResponsiveLayout.getResponsiveSpacing(context, 12),
          childAspectRatio: childAspectRatio,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }
  
  Widget _buildResponsiveServiceGrid(List<Service> services) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {}); // Refresh the stream
      },
      child: ListView.builder(
        padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          return Container(
            margin: EdgeInsets.only(
              bottom: ResponsiveLayout.getResponsiveSpacing(context, 12),
            ),
            child: _buildServiceCard(service),
          );
        },
      ),
    );
  }
  
  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
          boxShadow: const [MarketplaceTheme.smallShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(MarketplaceTheme.radiusLg),
                ),
                child: ProductImageWidget(
                  imageUrl: product.images.isNotEmpty ? product.images.first : null,
                  isGrid: true,
                ),
              ),
            ),
            // Product details
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        product.name,
                        style: MarketplaceTheme.titleLarge.copyWith(
                          fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: MarketplaceTheme.titleLarge.copyWith(
                          color: MarketplaceTheme.primaryBlue,
                          fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
                        ),
                      ),
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
  
  Widget _buildServiceCard(Service service) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(service: service),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
          boxShadow: const [MarketplaceTheme.smallShadow],
        ),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
          child: Row(
            children: [
              // Service image
              ClipRRect(
                borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
                child: SizedBox(
                  width: ResponsiveLayout.isMobile(context) ? 80 : 120,
                  height: ResponsiveLayout.isMobile(context) ? 80 : 120,
                  child: ServiceImageWidget(
                    imageUrl: service.images.isNotEmpty ? service.images.first : null,
                    size: ResponsiveLayout.isMobile(context) ? 80 : 120,
                  ),
                ),
              ),
              
              SizedBox(width: ResponsiveLayout.getResponsiveSpacing(context, 12)),
              
              // Service details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: MarketplaceTheme.titleLarge.copyWith(
                        fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.description,
                      style: MarketplaceTheme.bodyMedium.copyWith(
                        color: MarketplaceTheme.gray600,
                        fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'From \$${service.packages.isNotEmpty ? service.packages.first.price.toStringAsFixed(2) : '0.00'}',
                      style: MarketplaceTheme.titleLarge.copyWith(
                        color: MarketplaceTheme.primaryGreen,
                        fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlaceholderImage() {
    return Container(
      color: MarketplaceTheme.gray100,
      child: const Icon(
        Icons.image,
        color: MarketplaceTheme.gray400,
        size: 40,
      ),
    );
  }
  
  Widget _buildLoadingGrid() {
    final crossAxisCount = ResponsiveLayout.getGridCrossAxisCount(context);
    
    return GridView.builder(
      padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: ResponsiveLayout.getResponsiveSpacing(context, 12),
        mainAxisSpacing: ResponsiveLayout.getResponsiveSpacing(context, 12),
        childAspectRatio: ResponsiveLayout.getGridChildAspectRatio(context),
      ),
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }
  
  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
        boxShadow: const [MarketplaceTheme.smallShadow],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                color: MarketplaceTheme.gray200,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(MarketplaceTheme.radiusLg),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.gray200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 80,
                    decoration: BoxDecoration(
                      color: MarketplaceTheme.gray200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: ResponsiveLayout.getResponsiveFontSize(context, 64),
            color: MarketplaceTheme.gray400,
          ),
          SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 16)),
          Text(
            message,
            style: MarketplaceTheme.headingMedium.copyWith(
              color: MarketplaceTheme.gray600,
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 18),
            ),
          ),
          SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 8)),
          Text(
            'Try adjusting your search or category filter',
            style: MarketplaceTheme.bodyMedium.copyWith(
              color: MarketplaceTheme.gray500,
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
