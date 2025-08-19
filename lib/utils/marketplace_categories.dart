/// Comprehensive marketplace categories for goods and services
class MarketplaceCategories {
  
  /// Main goods categories with detailed subcategories
  static const Map<String, List<String>> goodsCategories = {
    'Retail & Consumer Goods': [
      'Groceries',
      'Clothing & Apparel', 
      'Electronics & Gadgets',
      'Home Appliances',
      'Beauty & Personal Care',
      'Health & Wellness',
    ],
    'Agriculture': [
      'Fresh Produce',
      'Livestock & Poultry',
      'Farming Tools & Equipment', 
      'Fertilizers & Pesticides',
      'Seeds & Nurseries',
    ],
    'Artisanal & Handicrafts': [
      'Jewelry',
      'Textiles & Fashion',
      'Pottery & Ceramics',
      'Cultural Artifacts & Home Decor',
      'Handmade Furniture',
    ],
    'Food & Beverage': [
      'Local Food Vendors',
      'Bakeries & Confectionery',
      'Beverage Suppliers',
      'Packaged & Processed Foods',
      'Organic & Specialty Foods',
    ],
    'Construction & Building Materials': [
      'Raw Materials',
      'Structural Components',
      'Finishing Materials',
      'Construction Tools & Equipment',
    ],
    'Education & Learning': [
      'School Supplies',
      'Libraries & Bookstores',
    ],
    'Automotive & Transportation': [
      'Vehicles & Motorcycles',
      'Auto Parts & Accessories',
    ],
    'Technology & Software': [
      'Computers & Accessories',
      'Software & Digital Solutions',
    ],
  };

  /// Detailed goods subcategories with specific items
  static const Map<String, List<String>> goodsSubcategories = {
    // Retail & Consumer Goods
    'Groceries': [
      'Fresh produce', 'Dairy products', 'Packaged foods', 'Beverages', 
      'Snacks', 'Frozen foods', 'Spices & condiments'
    ],
    'Clothing & Apparel': [
      'Men\'s fashion', 'Women\'s fashion', 'Children\'s wear', 'Footwear',
      'Accessories (belts, bags, hats)'
    ],
    'Electronics & Gadgets': [
      'Smartphones', 'Laptops', 'Tablets', 'Home entertainment', 
      'Gaming consoles', 'Accessories (chargers, cases, headphones)'
    ],
    'Home Appliances': [
      'Kitchen appliances', 'Laundry machines', 'Air conditioners', 
      'Refrigerators', 'Smart home devices'
    ],
    'Beauty & Personal Care': [
      'Skincare', 'Haircare', 'Grooming tools', 'Cosmetics', 
      'Perfumes', 'Hygiene products'
    ],
    'Health & Wellness': [
      'Supplements', 'Vitamins', 'Medical devices', 'Fitness equipment',
      'Alternative medicine'
    ],

    // Agriculture
    'Fresh Produce': [
      'Fruits', 'Vegetables', 'Grains', 'Herbs', 'Organic produce'
    ],
    'Livestock & Poultry': [
      'Cattle', 'Sheep', 'Goats', 'Chickens', 'Eggs', 
      'Dairy products', 'Beekeeping & honey production'
    ],
    'Farming Tools & Equipment': [
      'Tractors', 'Irrigation systems', 'Hand tools', 'Greenhouses', 'Storage silos'
    ],
    'Fertilizers & Pesticides': [
      'Organic fertilizers', 'Chemical fertilizers', 'Pest control products', 'Soil enhancers'
    ],
    'Seeds & Nurseries': [
      'Crop seeds', 'Saplings', 'Indoor gardening supplies', 'Hydroponics'
    ],

    // Artisanal & Handicrafts
    'Jewelry': [
      'Handmade necklaces', 'Bracelets', 'Rings', 'Earrings', 'Beaded accessories'
    ],
    'Textiles & Fashion': [
      'Traditional clothing', 'Scarves', 'Woven fabrics', 'Hand-dyed textiles', 'Leather goods'
    ],
    'Pottery & Ceramics': [
      'Decorative pottery', 'Tableware', 'Sculptures', 'Clay home decor'
    ],
    'Cultural Artifacts & Home Decor': [
      'African masks', 'Wooden carvings', 'Paintings', 'Tapestries', 'Woven baskets'
    ],
    'Handmade Furniture': [
      'Wooden chairs', 'Tables', 'Beds', 'Handcrafted shelving units'
    ],

    // Food & Beverage
    'Local Food Vendors': [
      'Street food', 'Traditional dishes', 'Catering services', 'Fast food outlets'
    ],
    'Bakeries & Confectionery': [
      'Cakes', 'Bread', 'Pastries', 'Sweets', 'Biscuits', 'Chocolates'
    ],
    'Beverage Suppliers': [
      'Tea', 'Coffee', 'Juice', 'Soft drinks', 'Alcoholic beverages', 'Energy drinks'
    ],
    'Packaged & Processed Foods': [
      'Canned goods', 'Frozen meals', 'Snacks', 'Sauces & condiments'
    ],
    'Organic & Specialty Foods': [
      'Gluten-free', 'Vegan', 'Keto-friendly products'
    ],

    // Construction & Building Materials
    'Raw Materials': [
      'Sand', 'Gravel', 'Cement', 'Bricks', 'Tiles', 'Limestone'
    ],
    'Structural Components': [
      'Roofing sheets', 'Steel rods', 'Timber', 'Insulation', 'Prefabricated structures'
    ],
    'Finishing Materials': [
      'Paint', 'Adhesives', 'Flooring', 'Doors & windows', 'Plumbing fixtures'
    ],
    'Construction Tools & Equipment': [
      'Power tools', 'Hand tools', 'Scaffolding', 'Safety gear', 'Heavy machinery rentals'
    ],

    // Education & Learning
    'School Supplies': [
      'Books', 'Stationery', 'Backpacks', 'Uniforms', 'Educational toys'
    ],
    'Libraries & Bookstores': [
      'Textbooks', 'E-books', 'Novels', 'Research materials'
    ],

    // Automotive & Transportation
    'Vehicles & Motorcycles': [
      'New cars', 'Used cars', 'Motorcycles', 'Scooters', 'Electric vehicles'
    ],
    'Auto Parts & Accessories': [
      'Batteries', 'Tires', 'Car audio systems', 'GPS', 'Car maintenance tools'
    ],

    // Technology & Software
    'Computers & Accessories': [
      'Laptops', 'Desktops', 'Storage devices', 'Networking equipment'
    ],
    'Software & Digital Solutions': [
      'Business software', 'Antivirus', 'Design software', 'Cloud solutions'
    ],
  };

  /// Service categories
  static const Map<String, List<String>> serviceCategories = {
    'Home Services': [
      'Plumbing', 'Electrical work', 'Carpentry', 'Cleaning services', 'Painting'
    ],
    'Transportation & Logistics': [
      'Ridesharing (Uber, Bolt)', 'Private taxi services', 'Courier services', 
      'Delivery services', 'Moving & relocation', 'Airport transfers', 
      'Car rentals', 'Heavy-duty vehicle rentals', 'Vehicle leasing options', 
      'Intercity bus services'
    ],
    'Freelance & Digital Services': [
      'Graphic design', 'Web development', 'Writing', 'Social media management', 
      'Translation services'
    ],
    'Event Services': [
      'Catering', 'Photography', 'Videography', 'Event planning', 'Music & DJ services'
    ],
    'Health & Wellness Services': [
      'Personal training', 'Yoga instructors', 'Massage therapy', 
      'Diet & nutrition consulting'
    ],
    'Professional Services': [
      'Contractors', 'Engineers', 'Architects', 'Interior designers'
    ],
    'Education & Training': [
      'Tutoring & private lessons', 'Vocational & skill training', 
      'Online & e-learning platforms'
    ],
    'Tech Services & Repairs': [
      'IT support', 'Gadget repair', 'Cybersecurity consulting'
    ],
    'Financial Services': [
      'Banking & financial services', 'Business consulting & legal services'
    ],
    'Travel & Hospitality': [
      'Hotels & accommodations', 'Travel agencies & tour operators'
    ],
  };

  /// Detailed service subcategories
  static const Map<String, List<String>> serviceSubcategories = {
    // Education & Training detailed breakdown
    'Tutoring & Private Lessons': [
      'Math tutoring', 'Science tutoring', 'Language tutoring', 'Test prep', 'Music lessons'
    ],
    'Vocational & Skill Training': [
      'Coding bootcamps', 'Artisan workshops', 'Farming techniques', 'Fashion design courses'
    ],
    'Online & E-Learning Platforms': [
      'Digital courses', 'Educational apps', 'Virtual training', 'Corporate training programs'
    ],

    // Financial Services detailed breakdown
    'Banking & Financial Services': [
      'Loans', 'Insurance', 'Savings accounts', 'Mobile money services'
    ],
    'Business Consulting & Legal Services': [
      'Business registration', 'Tax consulting', 'Trademark registration', 'Accounting services'
    ],

    // Travel & Hospitality detailed breakdown
    'Hotels & Accommodations': [
      'Hotels', 'Guest houses', 'Airbnb rentals'
    ],
    'Travel Agencies & Tour Operators': [
      'Safari tours', 'Flight bookings', 'Vacation planning'
    ],
  };

  /// Get all categories (both goods and services)
  static List<String> getAllCategories() {
    return [
      ...goodsCategories.keys,
      ...serviceCategories.keys,
    ];
  }

  /// Get all goods categories
  static List<String> getGoodsCategories() {
    return goodsCategories.keys.toList();
  }

  /// Get all service categories
  static List<String> getServiceCategories() {
    return serviceCategories.keys.toList();
  }

  /// Get subcategories for a given category
  static List<String> getSubcategories(String category) {
    if (goodsCategories.containsKey(category)) {
      return goodsCategories[category]!;
    }
    if (serviceCategories.containsKey(category)) {
      return serviceCategories[category]!;
    }
    return [];
  }

  /// Get detailed subcategories (specific items)
  static List<String> getDetailedSubcategories(String subcategory) {
    if (goodsSubcategories.containsKey(subcategory)) {
      return goodsSubcategories[subcategory]!;
    }
    if (serviceSubcategories.containsKey(subcategory)) {
      return serviceSubcategories[subcategory]!;
    }
    return [];
  }

  /// Check if category is for goods
  static bool isGoodsCategory(String category) {
    return goodsCategories.containsKey(category);
  }

  /// Check if category is for services
  static bool isServiceCategory(String category) {
    return serviceCategories.containsKey(category);
  }

  /// Get category type (goods or services)
  static String getCategoryType(String category) {
    if (isGoodsCategory(category)) return 'goods';
    if (isServiceCategory(category)) return 'services';
    return 'unknown';
  }

  /// Get category icon based on category name
  static String getCategoryIcon(String category) {
    const categoryIcons = {
      // Goods
      'Retail & Consumer Goods': '🛍️',
      'Agriculture': '🌾',
      'Artisanal & Handicrafts': '🎨',
      'Food & Beverage': '🍽️',
      'Construction & Building Materials': '🏗️',
      'Education & Learning': '📚',
      'Automotive & Transportation': '🚗',
      'Technology & Software': '💻',
      
      // Services
      'Home Services': '🏠',
      'Transportation & Logistics': '🚚',
      'Freelance & Digital Services': '💼',
      'Event Services': '🎉',
      'Health & Wellness Services': '⚕️',
      'Professional Services': '👔',
      'Education & Training': '🎓',
      'Tech Services & Repairs': '🔧',
      'Financial Services': '💰',
      'Travel & Hospitality': '✈️',
    };
    
    return categoryIcons[category] ?? '📦';
  }

  /// Search categories and subcategories
  static List<String> searchCategories(String query) {
    final results = <String>[];
    final lowerQuery = query.toLowerCase();
    
    // Search main categories
    for (final category in getAllCategories()) {
      if (category.toLowerCase().contains(lowerQuery)) {
        results.add(category);
      }
    }
    
    // Search subcategories
    for (final subcategories in [...goodsCategories.values, ...serviceCategories.values]) {
      for (final subcategory in subcategories) {
        if (subcategory.toLowerCase().contains(lowerQuery)) {
          results.add(subcategory);
        }
      }
    }
    
    return results.toSet().toList(); // Remove duplicates
  }
}