import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class EnhancedBalanceDisplay extends StatelessWidget {
  final String xlmBalance;
  final String akofaBalance;
  final bool hasAkofaTrustline;
  final String publicKey;

  const EnhancedBalanceDisplay({
    super.key,
    required this.xlmBalance,
    required this.akofaBalance,
    required this.hasAkofaTrustline,
    required this.publicKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // XLM Balance
          _buildBalanceItem(
            'XLM Balance',
            xlmBalance,
            'XLM',
            Icons.currency_bitcoin,
            Colors.blue,
          ),

          const SizedBox(height: 16),

          // AKOFA Balance
          _buildBalanceItem(
            'AKOFA Balance',
            akofaBalance,
            'AKOFA',
            Icons.token,
            AppTheme.primaryGold,
            showTrustline: true,
          ),

          const SizedBox(height: 16),

          // Public Key
          _buildPublicKeySection(),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(
    String label,
    String balance,
    String symbol,
    IconData icon,
    Color color, {
    bool showTrustline = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    balance,
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    symbol,
                    style: AppTheme.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (showTrustline) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasAkofaTrustline
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasAkofaTrustline ? 'Trustline Active' : 'Trustline Required',
                    style: AppTheme.bodySmall.copyWith(
                      color: hasAkofaTrustline ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPublicKeySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet Address',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color: AppTheme.primaryGold,
                  size: 16,
                ),
                onPressed: _copyPublicKey,
                tooltip: 'Copy Address',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatPublicKey(publicKey),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.white,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _formatPublicKey(String key) {
    if (key.length <= 20) return key;
    return '${key.substring(0, 10)}...${key.substring(key.length - 10)}';
  }

  void _copyPublicKey() {
    Clipboard.setData(ClipboardData(text: publicKey));
    // You would typically show a snackbar here, but since this is a widget,
    // we'll let the parent handle the feedback
  }
}