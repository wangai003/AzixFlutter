import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import 'custom_button.dart';

class FriendlyBotFundingDialog extends StatefulWidget {
  final Function? onFundingComplete;
  
  const FriendlyBotFundingDialog({
    Key? key,
    this.onFundingComplete,
  }) : super(key: key);

  @override
  State<FriendlyBotFundingDialog> createState() => _FriendlyBotFundingDialogState();
}

class _FriendlyBotFundingDialogState extends State<FriendlyBotFundingDialog> {
  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  bool _fundingComplete = false;
  
  @override
  Widget build(BuildContext context) {
    final stellarProvider = Provider.of<StellarProvider>(context);
    
    return Dialog(
      backgroundColor: AppTheme.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.primaryGold.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Friendly Bot Funding',
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.primaryGold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _successMessage ?? 'Your Stellar account needs to be funded before you can add the Akofa trustline. Our friendly bot can fund your account for free on the test network.',
              style: AppTheme.bodyMedium.copyWith(
                color: _successMessage != null ? Colors.green : AppTheme.white,
              ),
            ),
            const SizedBox(height: 24),
            
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Funding your account...',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                      ),
                    ),
                  ],
                ),
              )
            else if (_fundingComplete)
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Account funded successfully!',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Continue',
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        if (widget.onFundingComplete != null) {
                          widget.onFundingComplete!();
                        }
                      },
                    ),
                  ],
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: Text(
                      'Cancel',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  CustomButton(
                    text: 'Fund My Account',
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      
                      try {
                        final result = await stellarProvider.ensureAccountFunded();
                        
                        if (result['success'] == true) {
                          setState(() {
                            _isLoading = false;
                            _fundingComplete = true;
                            _successMessage = result['message'];
                          });
                        } else {
                          setState(() {
                            _isLoading = false;
                            _error = result['message'];
                          });
                        }
                      } catch (e) {
                        setState(() {
                          _isLoading = false;
                          _error = 'Unexpected error: $e';
                        });
                      }
                    },
                  ),
                ],
              ),
              
            if (_error != null && !_fundingComplete)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _error!,
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}