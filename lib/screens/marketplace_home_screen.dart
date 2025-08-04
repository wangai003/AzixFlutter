import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/service.dart';
import 'product_detail_screen.dart';
import 'service_detail_screen.dart';
import 'cart_screen.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import 'onboarding/vendor_type_selection_screen.dart';
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({Key? key}) : super(key: key);

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _goodsSearchQuery = '';
  String _selectedGoodsCategory = 'Retail & Consumer Goods';
  String? _selectedGoodsSubcategory;
  String _selectedServiceCategory = 'Services';
  String? _selectedServiceSubcategory;

  // Replace the old _categories list with structured categories
  final Map<String, List<String>> goodsCategories = {
    'Retail & Consumer Goods': [
      'Groceries', 'Clothing & Apparel', 'Electronics & Gadgets', 'Home Appliances', 'Beauty & Personal Care', 'Health & Wellness'
    ],
    'Agriculture': [
      'Fresh Produce', 'Livestock & Poultry', 'Farming Tools & Equipment', 'Fertilizers & Pesticides', 'Seeds & Nurseries'
    ],
    'Artisanal & Handicrafts': [
      'Jewelry', 'Textiles & Fashion', 'Pottery & Ceramics', 'Cultural Artifacts & Home Decor', 'Handmade Furniture'
    ],
    'Food & Beverage': [
      'Local Food Vendors', 'Bakeries & Confectionery', 'Beverage Suppliers', 'Packaged & Processed Foods', 'Organic & Specialty Foods'
    ],
    'Construction & Building Materials': [
      'Raw Materials', 'Structural Components', 'Finishing Materials', 'Construction Tools & Equipment'
    ],
    'Education & Learning': [
      'School Supplies', 'Libraries & Bookstores'
    ],
    'Automotive & Transportation': [
      'Vehicles & Motorcycles', 'Auto Parts & Accessories', 'Vehicle Rentals & Leasing'
    ],
    'Technology & Software': [
      'Computers & Accessories', 'Software & Digital Solutions'
    ],
    'Finance & Business Services': [
      'Banking & Financial Services'
    ],
    'Travel & Hospitality': [
      'Hotels & Accommodations'
    ],
  };

  final Map<String, List<String>> serviceCategories = {
    'Services': [
      'Home Services', 'Transportation & Logistics', 'Freelance & Digital Services', 'Event Services', 'Health & Wellness Services'
    ],
    'Agriculture': [
      'Farming Tools & Equipment', 'Fertilizers & Pesticides', 'Seeds & Nurseries'
    ],
    'Artisanal & Handicrafts': [
      'Jewelry', 'Textiles & Fashion', 'Pottery & Ceramics', 'Cultural Artifacts & Home Decor', 'Handmade Furniture'
    ],
    'Food & Beverage': [
      'Catering Services', 'Event Services'
    ],
    'Construction & Building Materials': [
      'Professional Services'
    ],
    'Education & Learning': [
      'Tutoring & Private Lessons', 'Vocational & Skill Training', 'Online & E-Learning Platforms'
    ],
    'Automotive & Transportation': [
      'Repair & Maintenance Services'
    ],
    'Technology & Software': [
      'Tech Services & Repairs'
    ],
    'Finance & Business Services': [
      'Business Consulting & Legal Services'
    ],
    'Travel & Hospitality': [
      'Travel Agencies & Tour Operators', 'Transportation Services'
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Marketplace'),
        backgroundColor: AppTheme.black,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.white,
          indicatorColor: AppTheme.primaryGold,
          tabs: const [
            Tab(text: 'Goods'),
            Tab(text: 'Services'),
          ],
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: AppTheme.primaryGold),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                ),
                if (cart.items.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGold,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.items.length}',
                        style: const TextStyle(color: AppTheme.black, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // GOODS SECTION (Alibaba-style)
          _buildGoodsSection(context),
          // SERVICES SECTION (Fiverr-style)
          _buildServicesSection(context),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: AppTheme.black,
        icon: const Icon(Icons.store_mall_directory),
        label: const Text('Become a Vendor', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VendorTypeSelectionScreen()),
          );
        },
      ),
    );
  }

  Widget _buildGoodsSection(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Sliding Banner (Swiper)
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: SizedBox(
              height: 120,
              child: Swiper(
                itemCount: 3,
                autoplay: true,
                duration: 600,
                autoplayDelay: 4000,
                pagination: const SwiperPagination(),
                itemBuilder: (context, index) {
                  final ads = [
                    {'img': 'https://placehold.co/600x200/FFD700/000000?text=Super+Sale', 'caption': 'Super Sale! Up to 50% off.'},
                    {'img': 'https://placehold.co/600x200/000000/FFD700?text=New+Arrivals', 'caption': 'New Arrivals: Shop Now'},
                    {'img': 'https://placehold.co/600x200/FFF/000?text=Advertise+Here', 'caption': 'Advertise your business here!'},
                  ];
                  return _buildAdBanner(ads[index]['img']!, ads[index]['caption']!);
                },
              ),
            ),
          ),
          // Hero Banner
          Container(
            width: double.infinity,
            height: 180,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: AppTheme.goldGradient,
              boxShadow: AppTheme.cardShadow,
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Big Deals, Small Prices', style: AppTheme.headingLarge.copyWith(color: AppTheme.black)),
                        const SizedBox(height: 8),
                        Text('Shop the best products now!', style: AppTheme.bodyLarge.copyWith(color: AppTheme.black)),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24.0),
                    child: Icon(Icons.local_mall, size: 80, color: AppTheme.primaryGold.withOpacity(0.3)),
                  ),
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search goods...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                filled: true,
                fillColor: AppTheme.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _goodsSearchQuery = value),
            ),
          ),
          // Horizontal Main Categories
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: goodsCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final cat = goodsCategories.keys.elementAt(index);
                return ChoiceChip(
                  label: Text(cat, style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: _selectedGoodsCategory == cat,
                  selectedColor: AppTheme.primaryGold,
                  backgroundColor: AppTheme.white,
                  labelStyle: TextStyle(
                    color: _selectedGoodsCategory == cat ? AppTheme.black : AppTheme.black,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedGoodsCategory = cat;
                      _selectedGoodsSubcategory = null;
                    });
                  },
                );
              },
            ),
          ),
          // Subcategories
          if (goodsCategories[_selectedGoodsCategory] != null)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: goodsCategories[_selectedGoodsCategory]!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final sub = goodsCategories[_selectedGoodsCategory]![index];
                  return ChoiceChip(
                    label: Text(sub),
                    selected: _selectedGoodsSubcategory == sub,
                    selectedColor: AppTheme.primaryGold,
                    backgroundColor: AppTheme.white,
                    labelStyle: TextStyle(
                      color: _selectedGoodsSubcategory == sub ? AppTheme.black : AppTheme.black,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedGoodsSubcategory = sub);
                    },
                  );
                },
              ),
            ),
          // Clear filter button
          if (_selectedGoodsSubcategory != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 16, right: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _selectedGoodsSubcategory = null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Subcategory Filter'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGold),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Product Grid
          SizedBox(
            height: 600, // Set a fixed height for the grid to allow scrolling
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                List<Product> products = snapshot.data!.docs.map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>, doc.id)).toList();
                if (_goodsSearchQuery.isNotEmpty) {
                  products = products.where((p) => p.name.toLowerCase().contains(_goodsSearchQuery.toLowerCase())).toList();
                }
                // Filter by main category and subcategory
                if (_selectedGoodsCategory != 'All') {
                  products = products.where((p) => p.category == _selectedGoodsCategory).toList();
                }
                if (_selectedGoodsSubcategory != null) {
                  products = products.where((p) => p.subcategory == _selectedGoodsSubcategory).toList();
                }
                if (products.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: product),
                          ),
                        );
                      },
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 6,
                        color: AppTheme.white,
                        shadowColor: AppTheme.primaryGold.withOpacity(0.2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: product.images.isNotEmpty
                                  ? Image.network(
                                      product.images.first,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 120,
                                      errorBuilder: (context, error, stackTrace) => Image.network('https://placehold.co/600x400', fit: BoxFit.cover, width: double.infinity, height: 120),
                                    )
                                  : Image.network('https://placehold.co/600x400', fit: BoxFit.cover, width: double.infinity, height: 120),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(product.name, style: AppTheme.headingSmall.copyWith(color: AppTheme.black), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Ksh ${product.price}', style: AppTheme.bodyLarge.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.star, color: AppTheme.primaryGold, size: 16),
                                  const SizedBox(width: 4),
                                  Text('4.8', style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Text('(120)', style: AppTheme.bodyTiny.copyWith(color: AppTheme.grey)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              child: Text(product.category, style: AppTheme.bodyTiny.copyWith(color: AppTheme.grey)),
                            ),
                            if (product.subcategory != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                child: Text(product.subcategory!, style: AppTheme.bodyTiny.copyWith(color: AppTheme.primaryGold)),
                              ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryGold,
                                        foregroundColor: AppTheme.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () {
                                        Provider.of<CartProvider>(context, listen: false).addToCart(product);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart!')));
                                      },
                                      child: const Text('Add to Cart'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.favorite_border),
                                    color: AppTheme.primaryGold,
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    return Row(
      children: [
        // Sidebar Categories (desktop/tablet)
        if (MediaQuery.of(context).size.width > 800)
          Container(
            width: 200,
            color: AppTheme.black,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: serviceCategories.keys.map((cat) => ListTile(
                title: Text(cat, style: AppTheme.bodyMedium.copyWith(color: _selectedServiceCategory == cat ? AppTheme.primaryGold : AppTheme.white, fontWeight: FontWeight.bold)),
                selected: _selectedServiceCategory == cat,
                selectedTileColor: AppTheme.primaryGold.withOpacity(0.1),
                onTap: () => setState(() {
                  _selectedServiceCategory = cat;
                  _selectedServiceSubcategory = null;
                }),
              )).toList(),
            ),
          ),
        // Main Content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Sliding Banner (Swiper)
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                  child: SizedBox(
                    height: 120,
                    child: Swiper(
                      itemCount: 3,
                      autoplay: true,
                      duration: 600,
                      autoplayDelay: 4000,
                      pagination: const SwiperPagination(),
                      itemBuilder: (context, index) {
                        final ads = [
                          {'img': 'https://placehold.co/600x200/FFD700/000000?text=Hire+Top+Talent', 'caption': 'Hire Top Talent for Your Project'},
                          {'img': 'https://placehold.co/600x200/000000/FFD700?text=Service+Deals', 'caption': 'Service Deals: Save Big!'},
                          {'img': 'https://placehold.co/600x200/FFF/000?text=Advertise+Here', 'caption': 'Advertise your service here!'},
                        ];
                        return _buildAdBanner(ads[index]['img']!, ads[index]['caption']!);
                      },
                    ),
                  ),
                ),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Find services (e.g. logo design, web dev...)',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                      filled: true,
                      fillColor: AppTheme.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                // Horizontal Main Categories (mobile)
                if (MediaQuery.of(context).size.width <= 800)
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: serviceCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final cat = serviceCategories.keys.elementAt(index);
                        return ChoiceChip(
                          label: Text(cat, style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: _selectedServiceCategory == cat,
                          selectedColor: AppTheme.primaryGold,
                          backgroundColor: AppTheme.white,
                          labelStyle: TextStyle(
                            color: _selectedServiceCategory == cat ? AppTheme.black : AppTheme.black,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedServiceCategory = cat;
                              _selectedServiceSubcategory = null;
                            });
                          },
                        );
                      },
                    ),
                  ),
                // Subcategories
                if (serviceCategories[_selectedServiceCategory] != null)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: serviceCategories[_selectedServiceCategory]!.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final sub = serviceCategories[_selectedServiceCategory]![index];
                        return ChoiceChip(
                          label: Text(sub),
                          selected: _selectedServiceSubcategory == sub,
                          selectedColor: AppTheme.primaryGold,
                          backgroundColor: AppTheme.white,
                          labelStyle: TextStyle(
                            color: _selectedServiceSubcategory == sub ? AppTheme.black : AppTheme.black,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedServiceSubcategory = sub);
                          },
                        );
                      },
                    ),
                  ),
                // Clear filter button
                if (_selectedServiceSubcategory != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 16, right: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _selectedServiceSubcategory = null),
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear Subcategory Filter'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGold),
                      ),
                    ),
                  ),
                // Fiverr-style Gig Grid
                SizedBox(
                  height: 600, // Set a fixed height for the grid to allow scrolling
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('services').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      List<Service> services = snapshot.data!.docs.map((doc) => Service.fromJson(doc.data() as Map<String, dynamic>, doc.id)).toList();
                      if (_searchQuery.isNotEmpty) {
                        services = services.where((s) => s.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                      }
                      // Filter by main category and subcategory
                      if (_selectedServiceCategory != 'All') {
                        services = services.where((s) => s.category == _selectedServiceCategory).toList();
                      }
                      if (_selectedServiceSubcategory != null) {
                        services = services.where((s) => s.subcategory == _selectedServiceSubcategory).toList();
                      }
                      if (services.isEmpty) {
                        return const Center(child: Text('No services found.'));
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 2,
                          childAspectRatio: 0.95,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: services.length,
                        itemBuilder: (context, index) {
                          final service = services[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ServiceDetailScreen(service: service),
                                ),
                              );
                            },
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 6,
                              color: AppTheme.white,
                              shadowColor: AppTheme.primaryGold.withOpacity(0.2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    child: service.images.isNotEmpty
                                        ? Image.network(
                                            service.images.first,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 120,
                                            errorBuilder: (context, error, stackTrace) => Image.network('https://placehold.co/600x400', fit: BoxFit.cover, width: double.infinity, height: 120),
                                          )
                                        : Image.network('https://placehold.co/600x400', fit: BoxFit.cover, width: double.infinity, height: 120),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AppTheme.primaryGold.withOpacity(0.1),
                                          child: const Icon(Icons.person, color: AppTheme.primaryGold),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            service.title,
                                            style: AppTheme.headingSmall.copyWith(color: AppTheme.black),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.star, color: AppTheme.primaryGold, size: 16),
                                        const SizedBox(width: 4),
                                        Text('4.9', style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Text('(120)', style: AppTheme.bodyTiny.copyWith(color: AppTheme.grey)),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: service.packages.isNotEmpty
                                        ? Text('From: Ksh ${service.packages.map((p) => p.price).reduce((a, b) => a < b ? a : b)}', style: AppTheme.bodyLarge.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold))
                                        : const Text('No packages', style: TextStyle(color: AppTheme.grey)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    child: Text(service.category, style: AppTheme.bodyTiny.copyWith(color: AppTheme.grey)),
                                  ),
                                  if (service.subcategory != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                      child: Text(service.subcategory!, style: AppTheme.bodyTiny.copyWith(color: AppTheme.primaryGold)),
                                    ),
                                  const Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryGold,
                                              foregroundColor: AppTheme.black,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ServiceDetailScreen(service: service),
                                                ),
                                              );
                                            },
                                            child: const Text('Order Now'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.favorite_border),
                                          color: AppTheme.primaryGold,
                                          onPressed: () {},
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdBanner(String imageUrl, String caption) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.primaryGold,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGold.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => Image.network('https://placehold.co/600x400', fit: BoxFit.cover, width: double.infinity, height: double.infinity),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                caption,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 