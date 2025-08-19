import 'package:flutter/material.dart';
import '../../theme/marketplace_theme.dart';

/// Responsive marketplace widgets for optimal mobile and desktop experience
class ResponsiveMarketplaceWidgets {
  
  /// Responsive grid that adapts to screen size
  static Widget responsiveGrid({
    required List<Widget> children,
    double aspectRatio = 1.0,
    double spacing = MarketplaceTheme.space3,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {   
        int crossAxisCount;
        
        if (constraints.maxWidth < 600) {
          // Mobile: 1 column for cards, 2 for small items
          crossAxisCount = aspectRatio > 1.5 ? 1 : 2;
        } else if (constraints.maxWidth < 900) {
          // Tablet: 2-3 columns
          crossAxisCount = aspectRatio > 1.5 ? 2 : 3;
        } else {
          // Desktop: 3-4 columns
          crossAxisCount = aspectRatio > 1.5 ? 3 : 4;
        }
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
  
  /// Responsive search bar that adapts to screen size
  static Widget responsiveSearchBar({
    required TextEditingController controller,
    required String hintText,
    Widget? leading,
    List<Widget>? actions,
    VoidCallback? onVoiceSearch,
    Function(String)? onSubmitted,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? MarketplaceTheme.space3 : MarketplaceTheme.space4,
            vertical: MarketplaceTheme.space3,
          ),
          decoration: const BoxDecoration(
            color: MarketplaceTheme.white,
            boxShadow: [MarketplaceTheme.smallShadow],
          ),
          child: Row(
            children: [
              if (leading != null && !isMobile) ...[
                leading,
                const SizedBox(width: MarketplaceTheme.space3),
              ],
              
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: MarketplaceTheme.gray50,
                    borderRadius: BorderRadius.circular(
                      isMobile ? MarketplaceTheme.radiusMd : MarketplaceTheme.radiusLg,
                    ),
                    border: Border.all(color: MarketplaceTheme.gray200),
                  ),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: MarketplaceTheme.bodyMedium.copyWith(
                        color: MarketplaceTheme.gray400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: MarketplaceTheme.gray400,
                      ),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => controller.clear(),
                            )
                          : (onVoiceSearch != null && isMobile)
                              ? IconButton(
                                  icon: const Icon(Icons.mic),
                                  onPressed: onVoiceSearch,
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? MarketplaceTheme.space3 : MarketplaceTheme.space4,
                        vertical: isMobile ? MarketplaceTheme.space2 : MarketplaceTheme.space3,
                      ),
                    ),
                    onSubmitted: onSubmitted,
                  ),
                ),
              ),
              
              if (actions != null && !isMobile) ...[
                const SizedBox(width: MarketplaceTheme.space3),
                ...actions,
              ],
            ],
          ),
        );
      },
    );
  }
  
  /// Responsive navigation that switches between bottom nav and drawer
  static Widget responsiveNavigation({
    required int selectedIndex,
    required List<NavigationItem> items,
    required Function(int) onItemSelected,
    Widget? header,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        
        if (isMobile) {
          return _buildBottomNavigation(
            selectedIndex: selectedIndex,
            items: items,
            onItemSelected: onItemSelected,
          );
        } else {
          return _buildSideNavigation(
            selectedIndex: selectedIndex,
            items: items,
            onItemSelected: onItemSelected,
            header: header,
          );
        }
      },
    );
  }
  
  static Widget _buildBottomNavigation({
    required int selectedIndex,
    required List<NavigationItem> items,
    required Function(int) onItemSelected,
  }) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemSelected,
      type: BottomNavigationBarType.fixed,
      backgroundColor: MarketplaceTheme.white,
      selectedItemColor: MarketplaceTheme.primaryBlue,
      unselectedItemColor: MarketplaceTheme.gray500,
      elevation: 8,
      items: items.take(5).map((item) => BottomNavigationBarItem(
        icon: Icon(item.icon),
        label: item.label,
        backgroundColor: MarketplaceTheme.white,
      )).toList(),
    );
  }
  
  static Widget _buildSideNavigation({
    required int selectedIndex,
    required List<NavigationItem> items,
    required Function(int) onItemSelected,
    Widget? header,
  }) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: MarketplaceTheme.white,
        boxShadow: [MarketplaceTheme.mediumShadow],
      ),
      child: Column(
        children: [
          if (header != null) header,
          const SizedBox(height: MarketplaceTheme.space4),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: MarketplaceTheme.space4),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: MarketplaceTheme.space2),
                  child: ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected 
                          ? MarketplaceTheme.primaryBlue 
                          : MarketplaceTheme.gray500,
                    ),
                    title: Text(
                      item.label,
                      style: MarketplaceTheme.bodyMedium.copyWith(
                        color: isSelected 
                            ? MarketplaceTheme.primaryBlue 
                            : MarketplaceTheme.gray700,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: item.badge != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: MarketplaceTheme.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.badge!,
                              style: const TextStyle(
                                color: MarketplaceTheme.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                    selected: isSelected,
                    selectedTileColor: MarketplaceTheme.primaryBlue.withAlpha(25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
                    ),
                    onTap: () => onItemSelected(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  /// Responsive dashboard layout
  static Widget responsiveDashboard({
    required Widget sidebar,
    required Widget content,
    bool forceMobile = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900 || forceMobile;
        
        if (isMobile) {
          return content; // Full screen content on mobile
        } else {
          return Row(
            children: [
              sidebar,
              Expanded(child: content),
            ],
          );
        }
      },
    );
  }
  
  /// Responsive padding that adjusts to screen size
  static EdgeInsets responsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 600) {
      return const EdgeInsets.all(MarketplaceTheme.space3);
    } else if (screenWidth < 900) {
      return const EdgeInsets.all(MarketplaceTheme.space4);
    } else {
      return const EdgeInsets.all(MarketplaceTheme.space6);
    }
  }
  
  /// Responsive gap that adjusts to screen size
  static double responsiveGap(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 600) {
      return MarketplaceTheme.space3;
    } else if (screenWidth < 900) {
      return MarketplaceTheme.space4;
    } else {
      return MarketplaceTheme.space6;
    }
  }
  
  /// Responsive text size that adjusts to screen size
  static TextStyle responsiveTextStyle({
    required TextStyle baseStyle,
    required BuildContext context,
    double scaleFactor = 1.0,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    double multiplier = 1.0;
    if (screenWidth < 600) {
      multiplier = 0.9; // Slightly smaller on mobile
    } else if (screenWidth > 1200) {
      multiplier = 1.1; // Slightly larger on desktop
    }
    
    return baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14) * multiplier * scaleFactor,
    );
  }
  
  /// Responsive modal that adapts to screen size
  static Future<T?> showResponsiveModal<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    if (isMobile) {
      // Full screen modal on mobile
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        isDismissible: isDismissible,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: MarketplaceTheme.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(MarketplaceTheme.radiusXl),
            ),
          ),
          child: Column(
            children: [
              if (title != null) ...[
                Container(
                  padding: const EdgeInsets.all(MarketplaceTheme.space4),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: MarketplaceTheme.gray200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: MarketplaceTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(child: child),
            ],
          ),
        ),
      );
    } else {
      // Dialog modal on desktop
      return showDialog<T>(
        context: context,
        barrierDismissible: isDismissible,
        builder: (context) => Dialog(
          backgroundColor: MarketplaceTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MarketplaceTheme.radiusXl),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Container(
                    padding: const EdgeInsets.all(MarketplaceTheme.space4),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: MarketplaceTheme.gray200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: MarketplaceTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
                Flexible(child: child),
              ],
            ),
          ),
        ),
      );
    }
  }
  
  /// Responsive app bar that adapts to screen size
  static PreferredSizeWidget responsiveAppBar({
    required String title,
    List<Widget>? actions,
    Widget? leading,
    bool centerTitle = false,
    double? elevation,
  }) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          
          return AppBar(
            title: Text(
              title,
              style: isMobile 
                  ? MarketplaceTheme.titleLarge
                  : MarketplaceTheme.headingMedium,
            ),
            leading: leading,
            actions: actions,
            centerTitle: isMobile ? true : centerTitle,
            elevation: elevation ?? (isMobile ? 1 : 0),
            backgroundColor: MarketplaceTheme.white,
            foregroundColor: MarketplaceTheme.gray900,
            toolbarHeight: isMobile ? 56 : 64,
          );
        },
      ),
    );
  }
}

/// Navigation item model
class NavigationItem {
  final IconData icon;
  final String label;
  final String? badge;
  
  NavigationItem({
    required this.icon,
    required this.label,
    this.badge,
  });
}

/// Responsive breakpoint utilities
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }
  
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }
  
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }
  
  static T responsive<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= ResponsiveBreakpoints.desktop && desktop != null) {
      return desktop;
    } else if (width >= ResponsiveBreakpoints.mobile && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }
}
