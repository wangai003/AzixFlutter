import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({Key? key}) : super(key: key);

  // This would be replaced with an actual URL if provided
  final String? marketplaceUrl = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.black,
            Color(0xFF212121),
          ],
        ),
      ),
      child: SafeArea(
        child: marketplaceUrl != null
            ? _buildMarketplaceWebView()
            : _buildComingSoonUI(context),
      ),
    );
  }

  Widget _buildMarketplaceWebView() {
    // This would be implemented with a WebView to load the marketplace URL
    return const Center(
      child: Text(
        'Marketplace WebView would be here',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildComingSoonUI(BuildContext context) {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Marketplace Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.darkGrey.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryGold,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.shopping_cart,
                        color: AppTheme.primaryGold,
                        size: 60,
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.1, 1.1),
                            duration: const Duration(seconds: 2),
                          )
                          .shimmer(
                            duration: const Duration(seconds: 2),
                            color: AppTheme.primaryGold.withOpacity(0.5),
                          ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 800))
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        curve: Curves.easeOut,
                        duration: const Duration(milliseconds: 800),
                      ),
                  const SizedBox(height: 30),
                  
                  // Coming Soon Text
                  Text(
                    'Marketplace Coming Soon',
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 300),
                      )
                      .slideY(
                        begin: 0.2,
                        end: 0,
                        curve: Curves.easeOut,
                        duration: const Duration(milliseconds: 800),
                      ),
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'We\'re building an exciting marketplace where you can buy and sell goods and services using your Akofa coins from your Stellar wallet. Stay tuned for the launch!',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.white,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 500),
                      )
                      .slideY(
                        begin: 0.2,
                        end: 0,
                        curve: Curves.easeOut,
                        duration: const Duration(milliseconds: 800),
                      ),
                  const SizedBox(height: 30),
                  
                  // Features Preview
                  _buildFeaturesPreview(),
                  
                  const SizedBox(height: 30),
                  
                  // Notify Me Button
                  ElevatedButton(
                    onPressed: () {
                      _showNotifyDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: AppTheme.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_active),
                        const SizedBox(width: 8),
                        Text(
                          'Notify Me When Available',
                          style: AppTheme.buttonText.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 700),
                      )
                      .slideY(
                        begin: 0.2,
                        end: 0,
                        curve: Curves.easeOut,
                        duration: const Duration(milliseconds: 800),
                      ),
                  
                  // Add some bottom padding to ensure everything is visible
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          Text(
            'Marketplace',
            style: AppTheme.headingLarge.copyWith(
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
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: const Duration(seconds: 2),
              ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 500))
        .slideY(begin: -0.2, end: 0, curve: Curves.easeOut);
  }

  Widget _buildFeaturesPreview() {
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
        // Check if we need to use a column layout for small screens
        final isSmallScreen = constraints.maxWidth < 400;
        
        if (isSmallScreen) {
          // Column layout for small screens
          return Column(
            children: features.asMap().entries.map((entry) {
              final index = entry.key;
              final feature = entry.value;
              
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.grey.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      feature['icon'] as IconData,
                      color: AppTheme.primaryGold,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature['title'] as String,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feature['description'] as String,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 600 + (100 * index)),
                  )
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    curve: Curves.easeOut,
                    duration: const Duration(milliseconds: 600),
                  );
            }).toList(),
          );
        } else {
          // Row layout for larger screens
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: features.asMap().entries.map((entry) {
              final index = entry.key;
              final feature = entry.value;
              
              return Container(
                width: 100,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.grey.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      feature['icon'] as IconData,
                      color: AppTheme.primaryGold,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feature['title'] as String,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature['description'] as String,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 600 + (100 * index)),
                  )
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    curve: Curves.easeOut,
                    duration: const Duration(milliseconds: 600),
                  );
            }).toList(),
          );
        }
      },
    );
  }

  void _showNotifyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: AppTheme.primaryGold,
            width: 2,
          ),
        ),
        title: Text(
          'Get Notified',
          style: AppTheme.headingMedium.copyWith(
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
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: 'Enter your email',
                hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                filled: true,
                fillColor: AppTheme.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.email,
                  color: AppTheme.primaryGold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'You\'ll be notified when the marketplace launches!',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.black,
                    ),
                  ),
                  backgroundColor: AppTheme.primaryGold,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Notify Me',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}