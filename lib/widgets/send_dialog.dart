import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import 'qr_scanner.dart';
import 'package:flutter/foundation.dart';

class SendDialog extends StatefulWidget {
  final String assetCode;
  final String balance;

  const SendDialog({
    Key? key,
    required this.assetCode,
    required this.balance,
  }) : super(key: key);

  @override
  State<SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<SendDialog> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _showAdvanced = false;
  final _qrKey = GlobalKey(debugLabel: 'QR');
  bool _isScanning = false;
  
  // For asset selection
  String _selectedAssetCode = '';
  String _selectedAssetBalance = '0';
  List<Map<String, dynamic>> _availableAssets = [];

  @override
  void initState() {
    super.initState();
    _selectedAssetCode = widget.assetCode;
    _selectedAssetBalance = widget.balance;
    
    // Load available assets when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableAssets();
    });
  }

  void _loadAvailableAssets() {
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    // Start with XLM and AKOFA if available
    _availableAssets = [];
    
    // Add XLM
    _availableAssets.add({
      'code': 'XLM',
      'balance': stellarProvider.balance,
      'name': 'Stellar Lumens',
    });
    
    // Add AKOFA if trustline exists
    if (stellarProvider.hasAkofaTrustline) {
      _availableAssets.add({
        'code': 'AKOFA',
        'balance': stellarProvider.akofaBalance,
        'name': 'Akofa Coin',
      });
    }
    
    // Add other assets from wallet
    for (var asset in stellarProvider.walletAssets) {
      // Skip XLM and AKOFA as they're already added
      if (asset['code'] == 'XLM' || asset['code'] == 'AKOFA') continue;
      
      // Only add assets with positive balance
      if (double.parse(asset['balance'].toString()) > 0) {
        _availableAssets.add({
          'code': asset['code'],
          'balance': asset['balance'],
          'name': asset['name'] ?? asset['code'],
        });
      }
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.black,
      title: Text(
        'Send Tokens',
        style: AppTheme.headingSmall.copyWith(
          color: AppTheme.primaryGold,
        ),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Asset Selection Dropdown
              DropdownButtonFormField<String>(
                value: _selectedAssetCode,
                decoration: InputDecoration(
                  labelText: 'Select Asset',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                dropdownColor: AppTheme.black,
                style: const TextStyle(color: AppTheme.white),
                items: _availableAssets.map((asset) {
                  return DropdownMenuItem<String>(
                    value: asset['code'],
                    child: Text(
                      '${asset['code']} - ${asset['name']}',
                      style: const TextStyle(color: AppTheme.white),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    final selectedAsset = _availableAssets.firstWhere(
                      (asset) => asset['code'] == value,
                      orElse: () => {'code': value, 'balance': '0', 'name': value},
                    );
                    
                    setState(() {
                      _selectedAssetCode = value;
                      _selectedAssetBalance = selectedAsset['balance'].toString();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              
              Text(
                'Available Balance: $_selectedAssetBalance $_selectedAssetCode',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              // Recipient Address
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Recipient Address',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.paste, color: AppTheme.grey),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data != null && data.text != null) {
                            setState(() {
                              _addressController.text = data.text!;
                            });
                          }
                        },
                      ),
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryGold),
                          tooltip: 'Scan QR',
                          onPressed: _isScanning ? null : () async {
                            setState(() { _isScanning = true; });
                            await showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              backgroundColor: AppTheme.black,
                              builder: (context) {
                                return SizedBox(
                                  height: 350,
                                  child: QrScannerWidget(
                                    qrKey: _qrKey,
                                    onScan: (code) {
                                      if (code.startsWith('G') && code.length == 56) {
                                        setState(() {
                                          _addressController.text = code;
                                          _isScanning = false;
                                        });
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                            setState(() { _isScanning = false; });
                          },
                        ),
                    ],
                  ),
                ),
                style: const TextStyle(color: AppTheme.white),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a recipient address';
                  }
                  // Basic Stellar address validation
                  if (!value.startsWith('G') || value.length != 56) {
                    return 'Please enter a valid Stellar address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Amount
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                  suffixText: _selectedAssetCode,
                ),
                style: const TextStyle(color: AppTheme.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount > double.parse(_selectedAssetBalance)) {
                    return 'Insufficient balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Advanced options toggle
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAdvanced = !_showAdvanced;
                  });
                },
                icon: Icon(
                  _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.grey,
                ),
                label: Text(
                  _showAdvanced ? 'Hide Advanced Options' : 'Show Advanced Options',
                  style: TextStyle(color: AppTheme.grey),
                ),
              ),
              
              // Memo field (only shown when advanced options are enabled)
              if (_showAdvanced) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _memoController,
                  decoration: InputDecoration(
                    labelText: 'Memo (Optional)',
                    labelStyle: TextStyle(color: AppTheme.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    helperText: 'Add a note to this transaction',
                    helperStyle: TextStyle(color: AppTheme.grey.withOpacity(0.7)),
                  ),
                  style: const TextStyle(color: AppTheme.white),
                  maxLength: 28, // Stellar memo text limit
                ),
              ],
              
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                  ),
                ),
              ],
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
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSend,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGold,
            foregroundColor: AppTheme.black,
            disabledBackgroundColor: AppTheme.grey.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }

  void _handleSend() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
        final destinationAddress = _addressController.text;
        final amount = _amountController.text;
        final memo = _memoController.text.isNotEmpty ? _memoController.text : null;

        // Use the generic sendAsset method for all asset types
        final result = await stellarProvider.sendAsset(
          _selectedAssetCode, 
          destinationAddress, 
          amount, 
          memo: memo
        );

        if (result['success'] == true) {
          if (mounted) {
            Navigator.of(context).pop(true); // Return success
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$_selectedAssetCode sent successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() {
            _isLoading = false;
            _error = result['error'] ?? 'Failed to send $_selectedAssetCode';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }
}