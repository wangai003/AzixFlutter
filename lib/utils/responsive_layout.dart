import 'package:flutter/material.dart';

/// A utility class that provides responsive layout functionality
class ResponsiveLayout {
  // Device size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Returns true if the current screen width is for a mobile device
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Returns true if the current screen width is for a tablet device
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Returns true if the current screen width is for a desktop device
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Returns true if the current screen width is for a large desktop device
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Returns the appropriate value based on the screen size
  static T getValueForScreenType<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    if (isLargeDesktop(context) && largeDesktop != null) {
      return largeDesktop;
    }
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// Returns a widget based on the screen size
  static Widget builder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
    Widget? largeDesktop,
  }) {
    if (isLargeDesktop(context) && largeDesktop != null) {
      return largeDesktop;
    }
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// Returns the appropriate padding based on screen size
  static EdgeInsets getHorizontalPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: getValueForScreenType<double>(
        context: context,
        mobile: 20.0,
        tablet: 40.0,
        desktop: 60.0,
        largeDesktop: 80.0,
      ),
    );
  }

  /// Returns a responsive width that scales with the screen size
  static double getResponsiveWidth(BuildContext context, {double percentage = 1.0}) {
    return MediaQuery.of(context).size.width * percentage;
  }

  /// Returns a responsive container width based on screen size
  static double getContentMaxWidth(BuildContext context) {
    return getValueForScreenType<double>(
      context: context,
      mobile: MediaQuery.of(context).size.width,
      tablet: 700.0,
      desktop: 1000.0,
      largeDesktop: 1200.0,
    );
  }

  /// Returns true if the current screen is tablet or desktop
  static bool isTabletOrDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  /// Returns responsive padding based on screen size
  static double getResponsivePadding(BuildContext context) {
    return getValueForScreenType<double>(
      context: context,
      mobile: 16.0,
      tablet: 20.0,
      desktop: 24.0,
      largeDesktop: 32.0,
    );
  }

  /// Returns responsive spacing based on screen size
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final multiplier = getValueForScreenType<double>(
      context: context,
      mobile: 1.0,
      tablet: 1.2,
      desktop: 1.4,
      largeDesktop: 1.6,
    );
    return baseSpacing * multiplier;
  }

  /// Returns responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final multiplier = getValueForScreenType<double>(
      context: context,
      mobile: 1.0,
      tablet: 1.1,
      desktop: 1.2,
      largeDesktop: 1.3,
    );
    return baseFontSize * multiplier;
  }

  /// Returns grid cross axis count based on screen size
  static int getGridCrossAxisCount(BuildContext context) {
    return getValueForScreenType<int>(
      context: context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
      largeDesktop: 5,
    );
  }

  /// Returns grid child aspect ratio based on screen size
  static double getGridChildAspectRatio(BuildContext context) {
    return getValueForScreenType<double>(
      context: context,
      mobile: 0.75,
      tablet: 0.8,
      desktop: 0.85,
      largeDesktop: 0.9,
    );
  }
}

/// A widget that adapts its layout based on screen size
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext, BoxConstraints) mobileBuilder;
  final Widget Function(BuildContext, BoxConstraints)? tabletBuilder;
  final Widget Function(BuildContext, BoxConstraints)? desktopBuilder;
  final Widget Function(BuildContext, BoxConstraints)? largeDesktopBuilder;

  const ResponsiveLayoutBuilder({
    Key? key,
    required this.mobileBuilder,
    this.tabletBuilder,
    this.desktopBuilder,
    this.largeDesktopBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveLayout.desktopBreakpoint && largeDesktopBuilder != null) {
          return largeDesktopBuilder!(context, constraints);
        }
        if (constraints.maxWidth >= ResponsiveLayout.tabletBreakpoint && desktopBuilder != null) {
          return desktopBuilder!(context, constraints);
        }
        if (constraints.maxWidth >= ResponsiveLayout.mobileBreakpoint && tabletBuilder != null) {
          return tabletBuilder!(context, constraints);
        }
        return mobileBuilder(context, constraints);
      },
    );
  }
}

/// A widget that creates a responsive container with max width
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;
  final double? maxWidth;
  final Color? color;
  final BoxDecoration? decoration;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.padding,
    this.alignment = Alignment.center,
    this.maxWidth,
    this.color,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? ResponsiveLayout.getContentMaxWidth(context);
    
    return Container(
      width: double.infinity,
      color: color,
      decoration: decoration,
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          padding: padding ?? ResponsiveLayout.getHorizontalPadding(context),
          child: child,
        ),
      ),
    );
  }
}