import 'package:flutter/material.dart';

/// World-class marketplace theme inspired by Jiji, Upwork, Amazon, Fiverr
class MarketplaceTheme {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color primaryGreen = Color(0xFF059669);
  static const Color primaryOrange = Color(0xFFF59E0B);
  
  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Shadows
  static const BoxShadow smallShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 4,
    offset: Offset(0, 1),
  );
  
  static const BoxShadow mediumShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 8,
    offset: Offset(0, 4),
  );
  
  // Border Radius
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  
  // Spacing
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;
  
  // Typography
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: gray900,
    height: 1.3,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: gray900,
    height: 1.4,
  );
  
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: gray900,
    height: 1.5,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: gray700,
    height: 1.6,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: gray700,
    height: 1.6,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: gray600,
    height: 1.4,
  );
  
  // Card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: white,
    borderRadius: BorderRadius.circular(radiusXl),
    boxShadow: const [mediumShadow],
    border: Border.all(color: gray200),
  );
  
  // Status colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'completed':
      case 'verified':
        return success;
      case 'pending':
      case 'processing':
        return warning;
      case 'cancelled':
      case 'failed':
        return error;
      default:
        return gray500;
    }
  }
  
  // Category colors
  static Color getCategoryColor(String category) {
    const categoryColors = {
      'electronics': Color(0xFF3B82F6),
      'fashion': Color(0xFFEC4899),
      'home': Color(0xFF059669),
      'services': Color(0xFF7C3AED),
      'automotive': Color(0xFF7C2D12),
    };
    return categoryColors[category.toLowerCase()] ?? primaryBlue;
  }
}