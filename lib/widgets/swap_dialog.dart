import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';

class SwapDialog extends StatefulWidget {
  const SwapDialog({Key? key}) : super(key: key);

  @override
  State<SwapDialog> createState() => _SwapDialogState();
}

class _SwapDialogState extends State<SwapDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  
  String _fromAsset = 'XLM';
  String _toAsset = 'AKOFA';
  double _exchangeRate = 0.0;
  double _estimatedReceiveAmount = 0.0;
  
  bool _isSwapping = false;
  String? _swapError;
  String? _swapSuccess;
  
  @override
  void initState() {
    super.initState();
    _loadAssets();
  }
  
  Future<void> _loadAssets() async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load supported assets (ensure Akofa, XLM, USDC, and other popular tokens)
      await stellarProvider.loadSupportedAssets();
      // TODO: Fetch and add more popular Stellar tokens dynamically
      await stellarProvider.loadAllAssetBalances();
      
      // Get initial exchange rate
      await _updateExchangeRate();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load assets: $e';
      });
    }
  }
  
  Future<void> _updateExchangeRate() async {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    try {
      final rate = await stellarProvider.getExchangeRate(_fromAsset, _toAsset);
      setState(() {
        _exchangeRate = rate;
        _updateEstimatedAmount();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get exchange rate: $e';
      });
    }
  }
  
  void _updateEstimatedAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      _estimatedReceiveAmount = amount * _exchangeRate;
    });
  }
  
  void _swapAssets() {
    final temp = _fromAsset;
    setState(() {
      _fromAsset = _toAsset;
      _toAsset = temp;
      _amountController.clear();
      _estimatedReceiveAmount = 0.0;
    });
    _updateExchangeRate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stellarProvider = Provider.of<StellarProvider>(context);
    final assetBalances = stellarProvider.assetBalances;
    final supportedAssets = stellarProvider.supportedAssets;
    
    return AlertDialog(
      backgroundColor: AppTheme.black,
      title: Text(
        'Swap Assets',
        style: AppTheme.headingSmall.copyWith(
          color: AppTheme.primaryGold,
        ),
        textAlign: TextAlign.center,
      ),
      content: _isLoading && supportedAssets.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              ),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exchange your assets at the current market rate',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // From Asset Selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              color: AppTheme.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _fromAsset,
                                  dropdownColor: AppTheme.darkGrey,
                                  style: const TextStyle(color: AppTheme.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  items: supportedAssets.map((asset) {
                                    return DropdownMenuItem<String>(
                                      value: asset['code'],
                                      child: Text(
                                        '${asset['code']} - ${asset['name']}',
                                        style: const TextStyle(color: AppTheme.white),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null && value != _fromAsset) {
                                      setState(() {
                                        _fromAsset = value;
                                        // If the new from asset is the same as to asset, swap them
                                        if (_fromAsset == _toAsset) {
                                          _toAsset = supportedAssets
                                              .map((a) => a['code']!)
                                              .firstWhere((code) => code != _fromAsset, orElse: () => 'XLM');
                                        }
                                        _amountController.clear();
                                        _estimatedReceiveAmount = 0.0;
                                      });
                                      _updateExchangeRate();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              hintText: 'Amount',
                              hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.7)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              suffixText: _fromAsset,
                            ),
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}')),
                            ],
                            onChanged: (value) {
                              _updateEstimatedAmount();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an amount';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Please enter a valid amount';
                              }
                              
                              final balance = double.tryParse(assetBalances[_fromAsset] ?? '0') ?? 0.0;
                              if (amount > balance) {
                                return 'Insufficient balance';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Available: ${assetBalances[_fromAsset] ?? '0'} $_fromAsset',
                            style: TextStyle(
                              color: AppTheme.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Swap button
                    Center(
                      child: IconButton(
                        onPressed: _swapAssets,
                        icon: const Icon(
                          Icons.swap_vert,
                          color: AppTheme.primaryGold,
                          size: 32,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.darkGrey.withOpacity(0.3),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                    
                    // To Asset Selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To',
                            style: TextStyle(
                              color: AppTheme.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _toAsset,
                                  dropdownColor: AppTheme.darkGrey,
                                  style: const TextStyle(color: AppTheme.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  items: supportedAssets.map((asset) {
                                    return DropdownMenuItem<String>(
                                      value: asset['code'],
                                      child: Text(
                                        '${asset['code']} - ${asset['name']}',
                                        style: const TextStyle(color: AppTheme.white),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null && value != _toAsset) {
                                      setState(() {
                                        _toAsset = value;
                                        // If the new to asset is the same as from asset, swap them
                                        if (_fromAsset == _toAsset) {
                                          _fromAsset = supportedAssets
                                              .map((a) => a['code']!)
                                              .firstWhere((code) => code != _toAsset, orElse: () => 'AKOFA');
                                        }
                                      });
                                      _updateExchangeRate();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _estimatedReceiveAmount.toStringAsFixed(7),
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Available: ${assetBalances[_toAsset] ?? '0'} $_toAsset',
                            style: TextStyle(
                              color: AppTheme.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Exchange rate info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Exchange Rate',
                            style: TextStyle(
                              color: AppTheme.grey,
                            ),
                          ),
                          Text(
                            '1 $_fromAsset = ${_exchangeRate.toStringAsFixed(7)} $_toAsset',
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    
                    if (stellarProvider.isSwapLoading) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                        ),
                      ),
                    ],
                    
                    // Estimated receive amount
                    const SizedBox(height: 16),
                    Text('Estimated Receive: ${_estimatedReceiveAmount.toStringAsFixed(4)} $_toAsset',
                        style: AppTheme.bodyLarge.copyWith(color: AppTheme.primaryGold)),
                    const SizedBox(height: 16),
                    if (_swapError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_swapError!, style: AppTheme.bodyMedium.copyWith(color: Colors.red)),
                      ),
                    if (_swapSuccess != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_swapSuccess!, style: AppTheme.bodyMedium.copyWith(color: Colors.green)),
                      ),
                    ElevatedButton(
                      onPressed: _isSwapping
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              setState(() {
                                _isSwapping = true;
                                _swapError = null;
                                _swapSuccess = null;
                              });
                              final result = await stellarProvider.executeSwap(_fromAsset, _toAsset, double.parse(_amountController.text));
                              setState(() {
                                _isSwapping = false;
                                if (result['success'] == true) {
                                  _swapSuccess = 'Swap successful!';
                                  Future.delayed(const Duration(seconds: 1), () {
                                    Navigator.of(context).pop(true);
                                  });
                                } else {
                                  _swapError = result['message'] ?? 'Swap failed.';
                                }
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                        minimumSize: const Size(double.infinity, 56),
                        textStyle: AppTheme.headingMedium,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSwapping
                          ? const CircularProgressIndicator(color: AppTheme.black)
                          : const Text('Swap'),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancel',
            style: TextStyle(color: AppTheme.grey),
          ),
        ),
      ],
    );
  }
}