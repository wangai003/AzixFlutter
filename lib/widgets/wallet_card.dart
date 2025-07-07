import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/responsive_layout.dart';

class WalletCard extends StatelessWidget {
  final String balance;
  final String akofaBalance;
  final String? publicKey;
  final bool hasAkofaTrustline;
  final VoidCallback onShowQR;

  const WalletCard({
    Key? key,
    required this.balance,
    required this.akofaBalance,
    required this.publicKey,
    required this.hasAkofaTrustline,
    required this.onShowQR,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final isLargeDesktop = ResponsiveLayout.isLargeDesktop(context);
    final isWebPlatform = kIsWeb;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGold, AppTheme.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 32 : 24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGold.withOpacity(0.2),
            blurRadius: isDesktop ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isDesktop 
          ? _buildDesktopLayout(context)
          : _buildMobileTabletLayout(context, isTablet),
    );
  }
  
  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Wallet', 
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.black,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                )
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (publicKey != null)
                  TextButton.icon(
                    icon: const Icon(Icons.copy, color: AppTheme.black),
                    label: Text(
                      'Copy',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.black),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: publicKey!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address copied to clipboard'))
                      );
                    },
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code, color: AppTheme.black, size: 32),
                  tooltip: 'Show QR',
                  onPressed: onShowQR,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column - Balances
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$balance XLM', 
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.black, 
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                    )
                  ),
                  const SizedBox(height: 16),
                  hasAkofaTrustline
                    ? Text(
                        '$akofaBalance AKOFA', 
                        style: AppTheme.headingMedium.copyWith(
                          color: AppTheme.black,
                          fontSize: 28,
                        )
                      )
                    : Text(
                        'No Akofa Trustline', 
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.black,
                          fontSize: 18,
                        )
                      ),
                ],
              ),
            ),
            // Right column - Public key display
            if (publicKey != null)
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Public Address:',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        publicKey!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.black.withOpacity(0.8),
                          fontFamily: 'Monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share, size: 20, color: AppTheme.black),
                            tooltip: 'Share Address',
                            onPressed: () {
                              Share.share(publicKey!);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMobileTabletLayout(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Wallet', 
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.black,
                  fontSize: isTablet ? 24 : null,
                )
              ),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code, color: AppTheme.black, size: 28),
              tooltip: 'Show QR',
              onPressed: onShowQR,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '$balance XLM', 
          style: AppTheme.headingLarge.copyWith(
            color: AppTheme.black, 
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 32 : null,
          )
        ),
        const SizedBox(height: 8),
        hasAkofaTrustline
          ? Text(
              '$akofaBalance AKOFA', 
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.black,
                fontSize: isTablet ? 24 : null,
              )
            )
          : Text(
              'No Akofa Trustline', 
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.black)
            ),
        const SizedBox(height: 16),
        if (publicKey != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  publicKey!,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.black.withOpacity(0.7)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20, color: AppTheme.black),
                tooltip: 'Copy Address',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: publicKey!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied!'))
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 20, color: AppTheme.black),
                tooltip: 'Share Address',
                onPressed: () {
                  Share.share(publicKey!);
                },
              ),
            ],
          ),
      ],
    );
  }

  void _showReceiveSheet(BuildContext context, String? publicKey) {
    if (publicKey == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppTheme.black,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Receive XLM or AKOFA', style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold)),
              const SizedBox(height: 16),
              QrImageView(
                data: publicKey,
                size: 180.0,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              SelectableText(publicKey, style: AppTheme.bodyLarge.copyWith(color: AppTheme.white)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppTheme.primaryGold),
                    tooltip: 'Copy Address',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: publicKey));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied!')));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: AppTheme.primaryGold),
                    tooltip: 'Share Address',
                    onPressed: () async {
                      await Share.share(publicKey);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
} 