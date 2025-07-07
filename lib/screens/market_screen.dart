import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({Key? key}) : super(key: key);

  final String? marketplaceUrl = null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.black, Color(0xFF212121)],
          ),
        ),
        child: SafeArea(
          child: marketplaceUrl != null
              ? _buildMarketplaceWebView()
              : _buildComingSoonUI(context, colorScheme, textTheme),
        ),
      ),
    );
  }

  Widget _buildMarketplaceWebView() {
    return const Center(
      child: Text(
        'Marketplace WebView would be here',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildComingSoonUI(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        _buildAppBar(context, textTheme, colorScheme),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Animated Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.darkGrey.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryGold, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.shopping_cart,
                      color: AppTheme.primaryGold,
                      size: 60,
                    )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: const Duration(seconds: 2))
                        .shimmer(duration: const Duration(seconds: 2), color: AppTheme.primaryGold.withOpacity(0.5)),
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

                const SizedBox(height: 30),

                Text(
                  'Marketplace Coming Soon',
                  style: textTheme.headlineLarge?.copyWith(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 300.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 16),

                Text(
                  'We\'re building an exciting marketplace where you can buy and sell goods and services using your Akofa coins from your Stellar wallet. Stay tuned for the launch!',
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.onBackground),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 500.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 30),

                _buildFeaturesPreview(textTheme, colorScheme),

                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: () => _showNotifyDialog(context, textTheme, colorScheme),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_active),
                      const SizedBox(width: 8),
                      Text(
                        'Notify Me When Available',
                        style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 700.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          Text(
            'Marketplace',
            style: textTheme.headlineMedium?.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.primaryGold),
            onPressed: () {},
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: const Duration(seconds: 2)),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildFeaturesPreview(TextTheme textTheme, ColorScheme colorScheme) {
    final features = [
      {
        'icon': Icons.shopping_bag,
        'title': 'Buy & Sell',
        'description': 'Trade goods and services',
      },
      {
        'icon': Icons.security,
        'title': 'Secure',
        'description': 'Protected transactions',
      },
      {
        'icon': Icons.public,
        'title': 'Global',
        'description': 'Connect worldwide',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;

        final children = features.asMap().entries.map((entry) {
          final index = entry.key;
          final feature = entry.value;

          return Container(
            width: isSmallScreen ? double.infinity : 100,
            margin: isSmallScreen ? const EdgeInsets.only(bottom: 16) : null,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
            ),
            child: isSmallScreen
                ? Row(
                    children: [
                      Icon(feature['icon'] as IconData, color: AppTheme.primaryGold, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feature['title'] as String,
                              style: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feature['description'] as String,
                              style: textTheme.bodySmall?.copyWith(color: AppTheme.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Icon(feature['icon'] as IconData, color: AppTheme.primaryGold, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        feature['title'] as String,
                        style: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature['description'] as String,
                        style: textTheme.bodySmall?.copyWith(color: AppTheme.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: Duration(milliseconds: 600 + index * 100))
              .slideY(begin: 0.2, end: 0);
        }).toList();

        return isSmallScreen
            ? Column(children: children)
            : Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: children);
      },
    );
  }

  void _showNotifyDialog(BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.primaryGold, width: 2),
        ),
        title: Text(
          'Get Notified',
          style: textTheme.headlineMedium?.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We\'ll let you know as soon as the marketplace is available!',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              style: textTheme.bodyMedium?.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your email',
                hintStyle: textTheme.bodyMedium?.copyWith(color: AppTheme.grey),
                filled: true,
                fillColor: AppTheme.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.email, color: AppTheme.primaryGold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: textTheme.bodyMedium?.copyWith(color: AppTheme.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'You\'ll be notified when the marketplace launches!',
                    style: textTheme.bodyMedium?.copyWith(color: AppTheme.black),
                  ),
                  backgroundColor: AppTheme.primaryGold,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Text(
              'Notify Me',
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
