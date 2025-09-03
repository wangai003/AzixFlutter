import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import '../widgets/enhanced_buy_akofa_dialog.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onBuy;

  const QuickActionsRow({
    Key? key,
    required this.onSend,
    required this.onReceive,
    required this.onBuy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine layout based on screen size
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final isLargeDesktop = ResponsiveLayout.isLargeDesktop(context);
    final isWebPlatform = kIsWeb;
    
    void _showBuyAkofaDialog() {
      showDialog(
        context: context,
        builder: (context) => const EnhancedBuyAkofaDialog(),
      );
    }
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 24 : 16,
        horizontal: isDesktop ? 32 : 16,
      ),
      decoration: isDesktop ? BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.grey.withOpacity(0.3),
          width: 1,
        ),
      ) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.send,
            label: 'Send',
            onTap: onSend,
            isLarge: isDesktop || isTablet,
          ),
          _ActionButton(
            icon: Icons.qr_code,
            label: 'Receive',
            onTap: onReceive,
            isLarge: isDesktop || isTablet,
          ),
          _ActionButton(
            icon: Icons.shopping_cart,
            label: 'Buy Akofa',
            onTap: _showBuyAkofaDialog,
            isLarge: isDesktop || isTablet,
          ),
          if (isDesktop)
            _ActionButton(
              icon: Icons.add_card,
              label: 'Buy',
              onTap: _showBuyAkofaDialog,
              isLarge: true,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLarge;

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLarge = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isLarge ? 20 : 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGold.withOpacity(0.2),
                  blurRadius: isLarge ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon, 
              color: AppTheme.black, 
              size: isLarge ? 36 : 28,
            ),
          ),
          SizedBox(height: isLarge ? 12 : 8),
          Text(
            label, 
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.primaryGold,
              fontSize: isLarge ? 16 : null,
              fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
} 