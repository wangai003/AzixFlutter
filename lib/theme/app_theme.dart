import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryGold = Color(0xFFFFD700);
  static const Color secondaryGold = Color(0xFFFFA500);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Color(0xFF9E9E9E);
  static const Color gray = Color(0xFF9E9E9E); // Alias for grey
  static const Color darkGrey = Color(0xFF424242);
  static const Color darkGray = Color(0xFF424242); // Alias for darkGrey
  static const Color lightGrey = Color(0xFFE0E0E0);
  static const Color red = Color(0xFFE53935);
  static const Color green = Color(0xFF4CAF50);
  static const Color blue = Color(0xFF2196F3);
  static const Color orange = Color(0xFFFF9800);
  static const Color purple = Color(0xFF9C27B0);
  static const Color teal = Color(0xFF009688);
  static const Color indigo = Color(0xFF3F51B5);
  static const Color pink = Color(0xFFE91E63);
  static const Color lime = Color(0xFFCDDC39);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color amber = Color(0xFFFFC107);
  static const Color deepOrange = Color(0xFFFF5722);
  static const Color lightBlue = Color(0xFF03A9F4);
  static const Color deepPurple = Color(0xFF673AB7);
  static const Color lightGreen = Color(0xFF8BC34A);
  static const Color brown = Color(0xFF795548);
  static const Color blueGrey = Color(0xFF607D8B);

  // Font Family - Use system fonts for maximum compatibility
  static const String fontFamily = 'system-ui'; // Cross-platform system font
  static const String fallbackFontFamily = 'Arial, Helvetica, sans-serif';

  // Text Styles with robust font fallbacks
  static TextStyle get _baseTextStyle => TextStyle(
    fontFamily: fontFamily,
    color: white,
    fontWeight: FontWeight.normal,
  );

  // Heading Styles
  static TextStyle get headingLarge => _baseTextStyle.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static TextStyle get headingMedium => _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle get headingSmall => _baseTextStyle.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // Body Styles
  static TextStyle get bodyLarge => _baseTextStyle.copyWith(
    fontSize: 18,
    height: 1.5,
  );

  static TextStyle get bodyMedium => _baseTextStyle.copyWith(
    fontSize: 16,
    height: 1.5,
  );

  static TextStyle get bodySmall => _baseTextStyle.copyWith(
    fontSize: 14,
    height: 1.4,
  );

  static TextStyle get bodyTiny => _baseTextStyle.copyWith(
    fontSize: 12,
    height: 1.3,
  );

  // Button Styles
  static TextStyle get buttonLarge => _baseTextStyle.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static TextStyle get buttonMedium => _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static TextStyle get buttonSmall => _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // Label Styles
  static TextStyle get labelLarge => _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get labelMedium => _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get labelSmall => _baseTextStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // Caption Styles
  static TextStyle get caption => _baseTextStyle.copyWith(
    fontSize: 12,
    height: 1.3,
    color: grey,
  );

  // Overline Styles
  static TextStyle get overline => _baseTextStyle.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 1.5,
    color: grey,
  );

  // Theme Data
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryGold,
      secondary: secondaryGold,
      surface: white,
      background: white,
      error: red,
      onPrimary: black,
      onSecondary: black,
      onSurface: black,
      onBackground: black,
      onError: white,
    ),
    fontFamily: fontFamily,
    textTheme: TextTheme(
      displayLarge: headingLarge.copyWith(color: black, fontFamily: fontFamily),
      displayMedium: headingMedium.copyWith(color: black, fontFamily: fontFamily),
      displaySmall: headingSmall.copyWith(color: black, fontFamily: fontFamily),
      headlineLarge: headingLarge.copyWith(color: black, fontFamily: fontFamily),
      headlineMedium: headingMedium.copyWith(color: black, fontFamily: fontFamily),
      headlineSmall: headingSmall.copyWith(color: black, fontFamily: fontFamily),
      titleLarge: labelLarge.copyWith(color: black, fontFamily: fontFamily),
      titleMedium: labelMedium.copyWith(color: black, fontFamily: fontFamily),
      titleSmall: labelSmall.copyWith(color: black, fontFamily: fontFamily),
      bodyLarge: bodyLarge.copyWith(color: black, fontFamily: fontFamily),
      bodyMedium: bodyMedium.copyWith(color: black, fontFamily: fontFamily),
      bodySmall: bodySmall.copyWith(color: black, fontFamily: fontFamily),
      labelLarge: labelLarge.copyWith(color: black, fontFamily: fontFamily),
      labelMedium: labelMedium.copyWith(color: black, fontFamily: fontFamily),
      labelSmall: labelSmall.copyWith(color: black, fontFamily: fontFamily),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGold,
        foregroundColor: black,
        textStyle: buttonMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGold,
        side: const BorderSide(color: primaryGold),
        textStyle: buttonMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGold,
        textStyle: buttonMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightGrey.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: grey.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: grey.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGold),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: red),
      ),
      labelStyle: labelMedium.copyWith(color: grey),
      hintStyle: bodyMedium.copyWith(color: grey.withOpacity(0.7)),
    ),
    cardTheme: CardThemeData(
      color: white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: black,
      foregroundColor: white,
      elevation: 0,
      titleTextStyle: headingMedium.copyWith(color: white),
      iconTheme: const IconThemeData(color: white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: black,
      selectedItemColor: primaryGold,
      unselectedItemColor: grey,
      type: BottomNavigationBarType.fixed,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: black,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: white,
      iconColor: primaryGold,
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primaryGold,
      secondary: secondaryGold,
      surface: darkGrey,
      background: black,
      error: red,
      onPrimary: black,
      onSecondary: black,
      onSurface: white,
      onBackground: white,
      onError: white,
    ),
    fontFamily: fontFamily,
    textTheme: TextTheme(
      displayLarge: headingLarge.copyWith(fontFamily: fontFamily),
      displayMedium: headingMedium.copyWith(fontFamily: fontFamily),
      displaySmall: headingSmall.copyWith(fontFamily: fontFamily),
      headlineLarge: headingLarge.copyWith(fontFamily: fontFamily),
      headlineMedium: headingMedium.copyWith(fontFamily: fontFamily),
      headlineSmall: headingSmall.copyWith(fontFamily: fontFamily),
      titleLarge: labelLarge.copyWith(fontFamily: fontFamily),
      titleMedium: labelMedium.copyWith(fontFamily: fontFamily),
      titleSmall: labelSmall.copyWith(fontFamily: fontFamily),
      bodyLarge: bodyLarge.copyWith(fontFamily: fontFamily),
      bodyMedium: bodyMedium.copyWith(fontFamily: fontFamily),
      bodySmall: bodySmall.copyWith(fontFamily: fontFamily),
      labelLarge: labelLarge.copyWith(fontFamily: fontFamily),
      labelMedium: labelMedium.copyWith(fontFamily: fontFamily),
      labelSmall: labelSmall.copyWith(fontFamily: fontFamily),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGold,
        foregroundColor: black,
        textStyle: buttonMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGold,
        side: const BorderSide(color: primaryGold),
        textStyle: buttonMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGold,
        textStyle: buttonMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkGrey.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: grey.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: grey.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGold),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: red),
      ),
      labelStyle: labelMedium.copyWith(color: grey),
      hintStyle: bodyMedium.copyWith(color: grey.withOpacity(0.7)),
    ),
    cardTheme: CardThemeData(
      color: darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: black,
      foregroundColor: white,
      elevation: 0,
      titleTextStyle: headingMedium.copyWith(color: white),
      iconTheme: const IconThemeData(color: white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: black,
      selectedItemColor: primaryGold,
      unselectedItemColor: grey,
      type: BottomNavigationBarType.fixed,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: black,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: white,
      iconColor: primaryGold,
    ),
  );

  // Custom Colors for specific use cases
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFE53935);
  static const Color infoBlue = Color(0xFF2196F3);
  static const Color neutralGrey = Color(0xFF9E9E9E);

  // Gradient Colors
  static const LinearGradient goldGradient = LinearGradient(
    colors: [primaryGold, secondaryGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [black, darkGrey],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadow Styles
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: black.withOpacity(0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryGold.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // Border Radius
  static const BorderRadius borderRadiusSmall = BorderRadius.all(Radius.circular(8));
  static const BorderRadius borderRadiusMedium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius borderRadiusLarge = BorderRadius.all(Radius.circular(16));
  static const BorderRadius borderRadiusExtraLarge = BorderRadius.all(Radius.circular(24));

  // Spacing
  static const double spacingTiny = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingExtraLarge = 32.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Custom Icons
  static const IconData receive = Icons.call_received;
  static const IconData encrypt = Icons.lock;
}