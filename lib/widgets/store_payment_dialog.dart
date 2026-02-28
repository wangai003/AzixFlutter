import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/store_payment_service.dart';
import '../services/akofa_tag_service.dart';
import '../services/secure_wallet_service.dart';
import '../theme/app_theme.dart';
import '../models/asset_config.dart';

/// Dialog for processing store payments with order ID
class StorePaymentDialog extends StatefulWidget {
  /// Optional initial values
  final String? initialOrderId;
  final String? initialRecipientAddress;
  final String? initialAmount;
  final String? initialStoreId;
  final String? initialStoreName;
  final String? initialAssetCode;

  const StorePaymentDialog({
    super.key,
    this.initialOrderId,
    this.initialRecipientAddress,
    this.initialAmount,
    this.initialStoreId,
    this.initialStoreName,
    this.initialAssetCode,
  });

  @override
  State<StorePaymentDialog> createState() => _StorePaymentDialogState();
}

class _StorePaymentDialogState extends State<StorePaymentDialog> {
  final _orderIdController = TextEditingController();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _storeIdController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _memoController = TextEditingController();

  bool _isResolving = false;
  bool _isProcessing = false;
  String? _resolvedAddress;
  String? _resolvedName;
  String? _error;
  String? _successMessage;
  bool _isValidInput = false;
  String _selectedAssetCode = 'AKOFA'; // Default to AKOFA (Polygon ERC-20)
  String _selectedNetwork = 'polygon'; // 'polygon' or 'ethereum'

  @override
  void initState() {
    super.initState();
    // Set initial values if provided
    if (widget.initialOrderId != null) {
      _orderIdController.text = widget.initialOrderId!;
    }
    if (widget.initialRecipientAddress != null) {
      _recipientController.text = widget.initialRecipientAddress!;
      _resolveInput();
    }
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!;
    }
    if (widget.initialStoreId != null) {
      _storeIdController.text = widget.initialStoreId!;
    }
    if (widget.initialStoreName != null) {
      _storeNameController.text = widget.initialStoreName!;
    }
    if (widget.initialAssetCode != null) {
      _selectedAssetCode = widget.initialAssetCode!;
    }
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _storeIdController.dispose();
    _storeNameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _resolveInput() async {
    final input = _recipientController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _resolvedAddress = null;
        _resolvedName = null;
        _error = null;
        _isValidInput = false;
      });
      return;
    }

    setState(() {
      _isResolving = true;
      _error = null;
    });

    try {
      // Check if input is a valid EVM address (works for both Polygon and Ethereum)
      if (_isValidEVMAddress(input)) {
        setState(() {
          _resolvedAddress = input;
          _resolvedName = null;
          _error = null;
          _isValidInput = true;
        });
      } else {
        // Try to resolve as AKOFA tag (supports both blockchains)
        final result = await AkofaTagService.resolveTag(
          input,
          blockchain: _selectedNetwork,
        );

        if (result['success']) {
          setState(() {
            _resolvedAddress = result['address'] ?? result['publicKey'];
            _resolvedName = result['firstName'];
            _error = null;
            _isValidInput = true;
          });
        } else {
          setState(() {
            _resolvedAddress = null;
            _resolvedName = null;
            _error = result['error'] ?? 'Could not resolve address';
            _isValidInput = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _resolvedAddress = null;
        _resolvedName = null;
        _error = 'Failed to resolve input: $e';
        _isValidInput = false;
      });
    } finally {
      setState(() => _isResolving = false);
    }
  }

  bool _isValidEVMAddress(String address) {
    // EVM addresses (Polygon and Ethereum) start with '0x' and are 42 characters long
    return address.startsWith('0x') && address.length == 42;
  }

  bool _validateForm() {
    if (_orderIdController.text.trim().isEmpty) {
      setState(() => _error = 'Order ID is required');
      return false;
    }

    if (_resolvedAddress == null || !_isValidInput) {
      setState(() => _error = 'Please enter a valid recipient address or AKOFA tag');
      return false;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return false;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return false;
    }

    return true;
  }

  Future<void> _processPayment() async {
    if (!_validateForm()) {
      return;
    }

    // Show seed phrase dialog for secure transaction
    final seedPhrase = await _showSeedPhraseDialog();
    if (seedPhrase == null) return; // User cancelled

    setState(() {
      _isProcessing = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final amount = double.parse(_amountController.text.trim());
      final orderId = _orderIdController.text.trim();
      final storeId = _storeIdController.text.trim().isNotEmpty
          ? _storeIdController.text.trim()
          : null;
      final storeName = _storeNameController.text.trim().isNotEmpty
          ? _storeNameController.text.trim()
          : null;
      final memo = _memoController.text.trim().isNotEmpty
          ? _memoController.text.trim()
          : null;

      // Process store payment
      final result = await StorePaymentService.processStorePayment(
        orderId: orderId,
        recipientAddress: _resolvedAddress!,
        amount: amount,
        assetCode: _selectedAssetCode,
        seedPhrase: seedPhrase, // Required for wallet authentication
        network: _selectedNetwork, // Pass selected network
        storeId: storeId,
        storeName: storeName,
        memo: memo,
      );

      if (result.success) {
        setState(() {
          _successMessage = 'Payment successful! Order ID: $orderId\nTransaction: ${result.transactionHash?.substring(0, 16)}...';
        });

        // Clear form after successful payment
        _orderIdController.clear();
        _amountController.clear();
        _memoController.clear();
        _resolvedAddress = null;
        _isValidInput = false;

        // Auto-close after success
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() => _error = result.error ?? 'Payment failed');
      }
    } catch (e) {
      setState(() => _error = 'Error processing payment: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<String?> _showSeedPhraseDialog() async {
    String seedPhrase = '';
    bool obscureSeedPhrase = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.darkGrey,
          title: Text(
            'Enter Seed Phrase',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your seed phrase to authorize this payment',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: obscureSeedPhrase,
                maxLines: obscureSeedPhrase ? 1 : 4,
                onChanged: (value) => seedPhrase = value,
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
                decoration: InputDecoration(
                  hintText: 'Enter your 12-word recovery phrase',
                  hintStyle: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.grey.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: AppTheme.darkGrey.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primaryGold.withOpacity(0.3),
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureSeedPhrase ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.primaryGold,
                    ),
                    onPressed: () =>
                        setState(() => obscureSeedPhrase = !obscureSeedPhrase),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
            ),
            ElevatedButton(
              onPressed: seedPhrase.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(seedPhrase.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
              ),
              child: Text(
                'Confirm',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.shopping_cart, color: AppTheme.primaryGold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Store Payment',
                    style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.primaryGold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              'Pay for your order using your wallet',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),

            const SizedBox(height: 24),

            // Order ID Input (Required)
            Text(
              'Order ID *',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _orderIdController,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: 'Enter your order ID',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppTheme.darkGrey.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
                prefixIcon: Icon(Icons.receipt, color: AppTheme.primaryGold),
              ),
            ),

            const SizedBox(height: 24),

            // Network Selector
            Text(
              'Network *',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedNetwork = 'polygon';
                          // Reset asset to first available for Polygon
                          if (!['AKOFA', 'USDC', 'USDT'].contains(_selectedAssetCode)) {
                            _selectedAssetCode = 'AKOFA';
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedNetwork == 'polygon' 
                              ? Colors.purple.withOpacity(0.2) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _selectedNetwork == 'polygon'
                              ? Border.all(color: Colors.purple, width: 2)
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.hexagon,
                              color: _selectedNetwork == 'polygon' ? Colors.purple : AppTheme.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Polygon',
                              style: AppTheme.bodyMedium.copyWith(
                                color: _selectedNetwork == 'polygon' ? Colors.purple : AppTheme.grey,
                                fontWeight: _selectedNetwork == 'polygon' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedNetwork = 'ethereum';
                          // Reset asset to first available for Ethereum
                          if (!['USDC', 'USDT', 'DAI', 'WETH'].contains(_selectedAssetCode)) {
                            _selectedAssetCode = 'USDC';
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedNetwork == 'ethereum' 
                              ? Colors.blue.withOpacity(0.2) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _selectedNetwork == 'ethereum'
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance,
                              color: _selectedNetwork == 'ethereum' ? Colors.blue : AppTheme.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ethereum',
                              style: AppTheme.bodyMedium.copyWith(
                                color: _selectedNetwork == 'ethereum' ? Colors.blue : AppTheme.grey,
                                fontWeight: _selectedNetwork == 'ethereum' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recipient Input (Store Address or Tag)
            Text(
              'Store Address (AKOFA Tag or ${_selectedNetwork == 'ethereum' ? 'Ethereum' : 'Polygon'} Address) *',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _recipientController,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: 'e.g., store1234 or 0x...',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppTheme.darkGrey.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isResolving ? Icons.hourglass_top : Icons.search,
                    color: AppTheme.primaryGold,
                  ),
                  onPressed: _isResolving ? null : _resolveInput,
                ),
              ),
              onChanged: (_) {
                // Auto-resolve after user stops typing
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    _resolveInput();
                  }
                });
              },
            ),

            // Resolution Result
            if (_resolvedAddress != null && _isValidInput) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _resolvedName != null
                                ? 'Store Tag Resolved'
                                : 'Valid Address',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.green,
                            ),
                          ),
                          if (_resolvedName != null)
                            Text(
                              _resolvedName!,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.white,
                              ),
                            ),
                          Text(
                            _resolvedAddress!.substring(0, 8) +
                                '...' +
                                _resolvedAddress!.substring(
                                  _resolvedAddress!.length - 8,
                                ),
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Asset Selection (varies by network)
            Text(
              'Asset *',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedAssetCode,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.darkGrey.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
              ),
              dropdownColor: AppTheme.darkGrey,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              items: (_selectedNetwork == 'polygon' 
                  ? ['AKOFA', 'USDC', 'USDT']
                  : ['USDC', 'USDT', 'DAI', 'WETH']).map((asset) {
                return DropdownMenuItem(
                  value: asset,
                  child: Text(asset),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedAssetCode = value);
                }
              },
            ),

            const SizedBox(height: 24),

            // Amount Input
            Text(
              'Amount *',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppTheme.darkGrey.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
                prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryGold),
              ),
            ),

            const SizedBox(height: 24),

            // Store ID (Optional)
            Text(
              'Store ID (Optional)',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _storeIdController,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: 'Store identifier',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppTheme.darkGrey.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Store Name (Optional)
            Text(
              'Store Name (Optional)',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _storeNameController,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: 'Store name',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppTheme.darkGrey.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Memo Input (Optional)
            Text(
              'Memo (Optional)',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              maxLength: 28,
              decoration: InputDecoration(
                hintText: 'Add a note...',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.grey.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppTheme.darkGrey.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
              ),
            ),

            // Error Message
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTheme.bodySmall.copyWith(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Success Message
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: AppTheme.bodySmall.copyWith(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isProcessing || !_isValidInput)
                        ? null
                        : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isValidInput
                          ? AppTheme.primaryGold
                          : AppTheme.grey,
                      foregroundColor: AppTheme.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: AppTheme.grey.withOpacity(0.3),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Pay Now',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.black,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Utility function to show store payment dialog
Future<bool?> showStorePaymentDialog({
  required BuildContext context,
  String? initialOrderId,
  String? initialRecipientAddress,
  String? initialAmount,
  String? initialStoreId,
  String? initialStoreName,
  String? initialAssetCode,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => StorePaymentDialog(
      initialOrderId: initialOrderId,
      initialRecipientAddress: initialRecipientAddress,
      initialAmount: initialAmount,
      initialStoreId: initialStoreId,
      initialStoreName: initialStoreName,
      initialAssetCode: initialAssetCode,
    ),
  );
}

