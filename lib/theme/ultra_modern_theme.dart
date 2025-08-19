import 'package:flutter/material.dart';
import 'dart:ui';

/// Ultra-modern theme inspired by world-class fintech and crypto apps
/// Following design principles from Revolut, Coinbase, Robinhood, and Apple
class UltraModernTheme {
  // Color Psychology & Brand Colors
  static const Color primaryGold = Color(0xFFFFD700);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color lightGold = Color(0xFFFFF8E1);
  
  // Neural Network Dark Theme (inspired by premium crypto apps)
  static const Color deepSpace = Color(0xFF0A0A0F);
  static const Color charcoal = Color(0xFF1A1A24);
  static const Color slate = Color(0xFF2A2A3A);
  static const Color graphite = Color(0xFF3A3A4A);
  static const Color steel = Color(0xFF4A4A5A);
  
  // Accent Colors for Data Visualization
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color electricBlue = Color(0xFF0080FF);
  static const Color cyberpunkPurple = Color(0xFF8A2BE2);
  static const Color warningAmber = Color(0xFFFF6B35);
  static const Color errorRed = Color(0xFFFF3366);
  
  // Semantic Colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color infoBlue = Color(0xFF2196F3);
  
  // Glass Morphism Colors
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBlack = Color(0x1A000000);
  static const Color glassPrimary = Color(0x1AFFD700);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x66FFFFFF);
  static const Color textInverse = Color(0xFF000000);
  
  // Gradients inspired by premium apps
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGold, accentGold],
    stops: [0.0, 1.0],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepSpace, charcoal],
    stops: [0.0, 1.0],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x20FFFFFF), Color(0x05FFFFFF)],
    stops: [0.0, 1.0],
  );
  
  static const LinearGradient energyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonGreen, electricBlue],
    stops: [0.0, 1.0],
  );
  
  // Typography inspired by San Francisco, Helvetica Neue, and Roboto
  static const String fontFamily = 'SF Pro Display';
  static const String monoFontFamily = 'SF Mono';
  
  // Text Styles following Apple Human Interface Guidelines
  static const TextStyle largeTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: textPrimary,
    height: 1.2,
  );
  
  static const TextStyle title1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: textPrimary,
    height: 1.3,
  );
  
  static const TextStyle title2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    color: textPrimary,
    height: 1.35,
  );
  
  static const TextStyle title3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
    color: textPrimary,
    height: 1.4,
  );
  
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: textPrimary,
    height: 1.4,
  );
  
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: textPrimary,
    height: 1.47,
  );
  
  static const TextStyle callout = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
    color: textPrimary,
    height: 1.5,
  );
  
  static const TextStyle subheadline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: textSecondary,
    height: 1.53,
  );
  
  static const TextStyle footnote = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: textTertiary,
    height: 1.54,
  );
  
  static const TextStyle caption1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: textTertiary,
    height: 1.5,
  );
  
  static const TextStyle caption2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: textTertiary,
    height: 1.45,
  );
  
  // Monospace for numbers and codes
  static const TextStyle monoLarge = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: primaryGold,
    height: 1.2,
  );
  
  static const TextStyle monoBody = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: textSecondary,
    height: 1.4,
  );
  
  // Spacing following 8pt grid system (Apple & Google Material)
  static const double spacing2xs = 2.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;
  static const double spacing3xl = 64.0;
  
  // Border Radius following iOS design language
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radius2xl = 32.0;
  
  // Shadows following Material Design 3.0
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get strongShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 30,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: primaryGold.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 0),
    ),
  ];
  
  // Animation Durations following iOS Human Interface Guidelines
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration dramaticAnimation = Duration(milliseconds: 800);
  
  // Animation Curves
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve bounceOut = Curves.bounceOut;
  
  // Glass Morphism Decorations
  static BoxDecoration glassCard({
    Color? color,
    double borderRadius = radiusLg,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: color ?? glassWhite,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder ? Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1.0,
      ) : null,
      boxShadow: softShadow,
    );
  }
  
  static BoxDecoration neonCard({
    Color? color,
    double borderRadius = radiusLg,
  }) {
    return BoxDecoration(
      color: color ?? glassBlack,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: primaryGold.withOpacity(0.3),
        width: 1.0,
      ),
      boxShadow: glowShadow,
    );
  }
  
  // Button Styles
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primaryGold,
    foregroundColor: textInverse,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: spacingLg,
      vertical: spacingMd,
    ),
    textStyle: headline,
  );
  
  static ButtonStyle secondaryButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: textPrimary,
    elevation: 0,
    shadowColor: Colors.transparent,
    side: BorderSide(
      color: Colors.white.withOpacity(0.2),
      width: 1.0,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: spacingLg,
      vertical: spacingMd,
    ),
    textStyle: headline,
  );
  
  // Layout Breakpoints for Responsive Design
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;
  
  // Responsive padding
  static EdgeInsets responsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) {
      return const EdgeInsets.all(spacing2xl);
    } else if (width >= tabletBreakpoint) {
      return const EdgeInsets.all(spacingXl);
    } else {
      return const EdgeInsets.all(spacingLg);
    }
  }
  
  // Responsive font scaling
  static double responsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) {
      return baseSize * 1.2;
    } else if (width >= tabletBreakpoint) {
      return baseSize * 1.1;
    } else {
      return baseSize;
    }
  }
}
