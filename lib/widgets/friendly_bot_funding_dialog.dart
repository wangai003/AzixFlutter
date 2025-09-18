import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import 'custom_button.dart';

class AccountMaintenanceDialog extends StatefulWidget {
  const AccountMaintenanceDialog({Key? key}) : super(key: key);

  @override
  State<AccountMaintenanceDialog> createState() => _AccountMaintenanceDialogState();
}

class _AccountMaintenanceDialogState extends State<AccountMaintenanceDialog> {
  bool _isLoading = false;
  Map<String, dynamic>? _maintenanceResult;
  String? _error;

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
                  Icons.build_circle,
                  color: AppTheme.primaryGold,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Account Maintenance',
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.primaryGold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _maintenanceResult != null
                  ? 'Maintenance completed successfully!'
                  : 'Check and fix unfunded accounts and missing trustlines.',
              style: AppTheme.bodyMedium.copyWith(
                color: _error != null ? Colors.red : AppTheme.white,
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
                      'Checking and fixing accounts...',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                      ),
                    ),
                  ],
                ),
              )
            else if (_maintenanceResult != null)
              _buildResultsDisplay()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                  const SizedBox(width: 16),
                  CustomButton(
                    text: 'Check & Fix Accounts',
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });

                      try {
                        final result = await stellarProvider.findAndFixUnfundedAccounts();

                        if (result['success'] == true) {
                          setState(() {
                            _isLoading = false;
                            _maintenanceResult = result;
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

            if (_error != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _error!,
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),

            if (_maintenanceResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(_maintenanceResult);
                      },
                      child: Text(
                        'Close',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsDisplay() {
    if (_maintenanceResult == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultRow('Accounts Found', _maintenanceResult!['accountsFound'].toString()),
        _buildResultRow('Accounts Funded', _maintenanceResult!['accountsFunded'].toString(), color: Colors.green),
        _buildResultRow('Trustlines Added', _maintenanceResult!['trustlinesAdded'].toString(), color: Colors.blue),

        const SizedBox(height: 16),
        Text(
          'Details:',
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGold,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: (_maintenanceResult!['details'] as List).length,
            itemBuilder: (context, index) {
              final detail = _maintenanceResult!['details'][index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  '${detail['publicKey'].substring(0, 8)}...: ${detail['funded'] ? '✅' : '❌'} Funded, ${detail['trustlineAdded'] ? '✅' : '❌'} Trustline',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.white,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.grey,
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: color ?? AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

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