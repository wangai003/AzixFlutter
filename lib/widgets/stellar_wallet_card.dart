import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import 'friendly_bot_funding_dialog.dart';
import 'custom_button.dart';

class StellarWalletCard extends StatefulWidget {
  final String? publicKey;
  final String balance;
  final bool hasWallet;
  final bool isLoading;
  final bool hasAkofaTrustline;
  final String akofaBalance;

  const StellarWalletCard({
    Key? key,
    required this.publicKey,
    required this.balance,
    required this.hasWallet,
    this.isLoading = false,
    this.hasAkofaTrustline = false,
    this.akofaBalance = '0',
  }) : super(key: key);

  @override
  State<StellarWalletCard> createState() => _StellarWalletCardState();
}

class _StellarWalletCardState extends State<StellarWalletCard> {
  bool _copied = false;

  void _copyToClipboard() {
    if (widget.publicKey != null) {
      Clipboard.setData(ClipboardData(text: widget.publicKey!));
      setState(() {
        _copied = true;
      });
      
      // Reset the copied state after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _copied = false;
          });
        }
      });
    }
  }

  String _formatPublicKey(String? key) {
    if (key == null) return 'N/A';
    if (key.length <= 12) return key;
    return '${key.substring(0, 6)}...${key.substring(key.length - 6)}';
  }
  
  // Show dialog to add Akofa trustline with automatic funding if needed
  void _showAddTrustlineDialog(BuildContext context) async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    // First check if the account has enough XLM
    final xlmCheck = await stellarProvider.checkAccountXlmBalance();
    
    if (!xlmCheck['hasEnough'] && context.mounted) {
      // Account needs funding, show the funding dialog first
      final fundingResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => FriendlyBotFundingDialog(
          onFundingComplete: () {
            // After funding is complete, try to add the trustline
            _addAkofaTrustline(context);
          },
        ),
      );
      
      // If user cancelled the funding dialog, don't proceed
      if (fundingResult != true) {
        return;
      }
    } else {
      // Account has enough XLM, proceed with adding the trustline
      _addAkofaTrustline(context);
    }
  }
  
  // Add Akofa trustline
  void _addAkofaTrustline(BuildContext context) async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
          ),
        ),
      ),
    );
    
    try {
      final result = await stellarProvider.addAkofaTrustline();
      
      // Close the loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (result['success'] == true) {
        // Trustline added successfully
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['wasFunded'] == true 
                ? 'Your account was funded and Akofa trustline was added successfully!' 
                : 'Akofa trustline added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Failed to add trustline
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to add Akofa trustline'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close the loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // For debugging purposes, always show the card
    // Comment this out for production
    print("StellarWalletCard build - hasWallet: ${widget.hasWallet}, publicKey: ${widget.publicKey}");
    
    // If there's no wallet or the publicKey is null, don't show the card
    // Temporarily commented out for debugging
    // if (!widget.hasWallet || widget.publicKey == null) {
    //   return const SizedBox.shrink();
    // }

    // Check if we're on a desktop/large screen
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
    final isLargeDesktop = MediaQuery.of(context).size.width >= 1200;
    final isWebPlatform = kIsWeb;

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: isDesktop ? 24 : 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGold.withOpacity(0.8),
            AppTheme.primaryGold.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGold.withOpacity(0.3),
            blurRadius: isDesktop ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _copyToClipboard,
          borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
            child: isDesktop 
                ? _buildDesktopLayout()
                : _buildMobileTabletLayout(isTablet),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.black,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Stellar Wallet',
                  style: AppTheme.headingMedium.copyWith(
                    color: AppTheme.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (widget.publicKey != null)
                  SelectableText(
                    _formatPublicKey(widget.publicKey),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.black,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      fontSize: 16,
                    ),
                  ),
                const SizedBox(width: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _copied
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                          key: ValueKey('copied'),
                        )
                      : const Icon(
                          Icons.copy,
                          color: AppTheme.black,
                          size: 24,
                          key: ValueKey('copy'),
                        ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'XLM Balance:',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.black.withOpacity(0.7),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                widget.isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.black.withOpacity(0.7),
                          ),
                        ),
                      )
                    : Text(
                        '${widget.balance} XLM',
                        style: AppTheme.headingMedium.copyWith(
                          color: AppTheme.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
              ],
            ),
            if (widget.hasWallet && widget.publicKey != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Akofa Balance:',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.black.withOpacity(0.7),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  widget.isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.black.withOpacity(0.7),
                            ),
                          ),
                        )
                      : widget.hasAkofaTrustline
                          ? Text(
                              '${widget.akofaBalance} AKOFA',
                              style: AppTheme.headingMedium.copyWith(
                                color: AppTheme.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            )
                          : Row(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Trustline Not Added',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                ],
              ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMobileTabletLayout(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.black,
                  size: isTablet ? 24 : 20,
                ),
                SizedBox(width: isTablet ? 10 : 8),
                Text(
                  'Stellar Wallet',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.black,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 18 : null,
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _copied
                  ? Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: isTablet ? 22 : 20,
                      key: const ValueKey('copied'),
                    )
                  : Icon(
                      Icons.copy,
                      color: AppTheme.black,
                      size: isTablet ? 22 : 20,
                      key: const ValueKey('copy'),
                    ),
            ),
          ],
        ),
        SizedBox(height: isTablet ? 16 : 12),
        Text(
          _formatPublicKey(widget.publicKey),
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.black,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            fontSize: isTablet ? 16 : null,
          ),
        ),
        SizedBox(height: isTablet ? 12 : 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Balance:',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.black.withOpacity(0.7),
                fontSize: isTablet ? 14 : null,
              ),
            ),
            widget.isLoading
                ? SizedBox(
                    width: isTablet ? 18 : 16,
                    height: isTablet ? 18 : 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.black.withOpacity(0.7),
                      ),
                    ),
                  )
                : Text(
                    '${widget.balance} XLM',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.black,
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 18 : null,
                    ),
                  ),
          ],
        ),
                
        // Akofa Trustline Status
        if (widget.hasWallet && widget.publicKey != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Akofa Trustline:',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.black.withOpacity(0.7),
                    ),
                  ),
                  widget.isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.black.withOpacity(0.7),
                            ),
                          ),
                        )
                      : widget.hasAkofaTrustline
                          ? Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Not Added',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                ],
              ),
              
              // Show Akofa balance if trustline is active
              if (widget.hasAkofaTrustline)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Akofa Balance:',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.black.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        '${widget.akofaBalance} AKOFA',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Add Akofa Trustline button if not added yet
              if (!widget.hasAkofaTrustline)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showAddTrustlineDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.black,
                        foregroundColor: AppTheme.primaryGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Add Akofa Trustline'),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}