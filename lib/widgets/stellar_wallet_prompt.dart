import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import 'custom_button.dart';

class StellarWalletPrompt extends StatelessWidget {
  const StellarWalletPrompt({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final stellarProvider = Provider.of<StellarProvider>(context);
    
    // If the user already has a wallet, don't show the prompt
    if (stellarProvider.hasWallet) {
      return const SizedBox.shrink();
    }
    
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.primaryGold,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stellar Wallet Required',
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.primaryGold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'To use all features of this app, you need to create a Stellar wallet. Your wallet will be stored in your account.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (stellarProvider.isLoading)
              Center(
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                ),
              )
            else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () {
                      // This is just a temporary dismissal, the prompt will appear again
                      // on next app launch or reload
                      Navigator.of(context).pop(false);
                    },
                    child: Text(
                      'Later',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  CustomButton(
                    onPressed: () async {
                      try {
                        final success = await stellarProvider.createWallet(context);
                        if (success) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Stellar wallet created successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop(true); // Return true to indicate success
                          }
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(stellarProvider.error ?? 'Failed to create wallet'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unexpected error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    text: 'Create',
                    icon: Icons.add_circle_outline,
                    width: 100, // Further reduced width
                  ),
                ],
              ),
            if (stellarProvider.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  stellarProvider.error!.contains('Invalid or corrupted pad block')
                      ? 'Previous wallet data was corrupted. Please create a new wallet.'
                      : stellarProvider.error!,
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        )
        .slideY(
          begin: 0.2,
          end: 0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
  }
}