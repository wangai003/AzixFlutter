import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../services/pesapal_service.dart';
import '../services/polygon_wallet_service.dart';
import '../services/polygon_mining_service.dart';
import '../services/crypto_price_service.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';

class MpesaPurchaseDialog extends StatefulWidget {
  final EnhancedWalletProvider walletProvider;
  
  // Optional pre-selected token parameters (from multi-token dialog)
  final String? tokenSymbol;
  final double? tokenAmount;
  final double? amountKES;
  final double? pricePerTokenKES;
  final String? priceLockId;

  const MpesaPurchaseDialog({
    super.key,
    required this.walletProvider,
    this.tokenSymbol,
    this.tokenAmount,
    this.amountKES,
    this.pricePerTokenKES,
    this.priceLockId,
  });

  @override
  State<MpesaPurchaseDialog> createState() => _MpesaPurchaseDialogState();
}

class _MpesaPurchaseDialogState extends State<MpesaPurchaseDialog> {
  final _phoneController = TextEditingController();
  late double _selectedAmount;
  late String _selectedToken;
  late double _tokenAmount;
  late double? _pricePerToken;
  bool _isProcessing = false;
  String? _error;
  String _displayCurrency = 'KES';
  double _displayAmount = 0.0;
  bool _isConverting = false;
  static const List<String> _displayCurrencies = ['KES', 'USD', 'NGN', 'ZAR'];

  final List<double> _presetAmounts = [10, 50, 100, 500, 1000, 5000];
  
  // Check if we have pre-selected values from token dialog
  bool get _hasPreselectedValues => widget.tokenSymbol != null && widget.tokenAmount != null && widget.amountKES != null;
  
  @override
  void initState() {
    super.initState();
    // Initialize with pre-selected values if available
    _selectedAmount = widget.amountKES ?? 100.0;
    _selectedToken = widget.tokenSymbol ?? 'AKOFA';
    _tokenAmount = widget.tokenAmount ?? (_selectedAmount / 5.52);
    _pricePerToken = widget.pricePerTokenKES;
    _displayAmount = _selectedAmount;
    _updateDisplayAmount();
  }

  Future<void> _updateDisplayAmount() async {
    if (_displayCurrency == 'KES') {
      if (mounted) setState(() => _displayAmount = _selectedAmount);
      return;
    }
    try {
      setState(() => _isConverting = true);
      final converted = await CurrencyService.convertCurrency(
        _selectedAmount,
        'KES',
        _displayCurrency,
      );
      if (mounted) {
        setState(() => _displayAmount = converted);
      }
    } catch (e) {
      debugPrint('Error converting currency: $e');
      if (mounted) {
        setState(() {
          _displayCurrency = 'KES';
          _displayAmount = _selectedAmount;
        });
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: _hasPreselectedValues ? 450 : 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _hasPreselectedValues ? 'Confirm M-Pesa Payment' : 'Buy $_selectedToken Tokens',
                    style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.primaryGold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

            const SizedBox(height: 8),
            Text(
              _hasPreselectedValues 
                ? 'Enter your M-Pesa phone number to complete payment'
                : 'Purchase $_selectedToken tokens instantly using M-Pesa',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey,
              ),
            ),

            const SizedBox(height: 24),

            // Show amount selection only if no pre-selected values
            if (!_hasPreselectedValues) ...[
            // Amount Selection
            Text(
              'Select Amount (KES)',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Preset Amounts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetAmounts.map((amount) {
                final isSelected = _selectedAmount == amount;
                return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAmount = amount;
                        _tokenAmount = amount / 5.52; // Default AKOFA rate
                      });
                      _updateDisplayAmount();
                    },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryGold
                          : AppTheme.darkGrey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryGold
                            : AppTheme.primaryGold.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'KES ${amount.toInt()}',
                      style: AppTheme.bodyMedium.copyWith(
                        color: isSelected ? AppTheme.black : AppTheme.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Custom Amount
            TextFormField(
              initialValue: _selectedAmount.toStringAsFixed(0),
              style: TextStyle(color: AppTheme.white),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Custom Amount (KES)',
                labelStyle: TextStyle(color: AppTheme.grey),
                prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryGold),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
              ),
              onChanged: (value) {
                final amount = double.tryParse(value);
                if (amount != null && amount >= 10 && amount <= 50000) {
                    setState(() {
                      _selectedAmount = amount;
                      _tokenAmount = amount / 5.52; // Default AKOFA rate
                    });
                    _updateDisplayAmount();
                }
              },
            ),

            const SizedBox(height: 16),
            ],

            // Purchase Summary (always shown)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  if (_hasPreselectedValues && widget.priceLockId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Price Locked',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'You Pay',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                      Text(
                        'KES ${_selectedAmount.toInt()}',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Display Currency',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          value: _displayCurrency,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                            ),
                          ),
                          dropdownColor: AppTheme.black,
                          style: TextStyle(color: AppTheme.white, fontSize: 12),
                          items: _displayCurrencies
                              .map((currency) => DropdownMenuItem(
                                    value: currency,
                                    child: Text(currency),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _displayCurrency = value);
                            _updateDisplayAmount();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Approx. Total',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                      _isConverting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryGold,
                              ),
                            )
                          : Text(
                              '${_displayCurrency} ${_displayAmount.toStringAsFixed(2)}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.white,
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'You Receive',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                      Text(
                        '${_tokenAmount.toStringAsFixed(_selectedToken == 'AKOFA' ? 2 : 6)} $_selectedToken',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rate: 1 AKOFA = 5.52 KES',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.grey.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Phone Number
            TextFormField(
              controller: _phoneController,
              style: TextStyle(color: AppTheme.white),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'M-Pesa Phone Number',
                labelStyle: TextStyle(color: AppTheme.grey),
                hintText: '0712345678',
                hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
                prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
              ),
              validator: _validatePhoneNumber,
            ),

            const SizedBox(height: 16),

            // Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will receive an M-Pesa prompt on your phone to complete the payment.',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
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
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _initiatePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: AppTheme.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Buy Now',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter phone number';
    }

    if (value.length < 9 || value.length > 12) {
      return 'Invalid phone number length';
    }

    return null;
  }

  // ⚠️ TEST MODE - Set to true to bypass M-Pesa and simulate successful payment
  // Set to false for production to use actual M-Pesa API
  static const bool _testMode = false;
  
  Future<void> _initiatePurchase() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() => _error = 'Please enter phone number');
      return;
    }

    if (_selectedAmount < 10) {
      setState(() => _error = 'Minimum purchase amount is KES 10');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // ⚠️ TEST MODE: Simulate successful payment without calling M-Pesa
      if (_testMode) {
        debugPrint('⚠️⚠️⚠️ TEST MODE: Simulating successful M-Pesa payment ⚠️⚠️⚠️');
        debugPrint('💰 Amount: KES $_selectedAmount');
        debugPrint('🪙 Token: $_tokenAmount $_selectedToken');
        
        // Close the dialog
        Navigator.pop(context);
        
        // Simulate a successful payment and directly credit tokens
        await _simulateSuccessfulPayment();
        return;
      }
      
      // Normal M-Pesa flow
      final result = await widget.walletProvider.purchaseAkofaWithMpesa(
        phoneNumber: phoneNumber,
        amountKES: _selectedAmount,
      );

      if (result['success'] == true) {
        Navigator.pop(context);
        _showPaymentPendingDialog(result);
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to initiate purchase';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  /// ⚠️ TEST MODE: Simulate successful payment and credit tokens
  Future<void> _simulateSuccessfulPayment() async {
    // Store values we need before dialog closes
    final tokenAmount = _tokenAmount;
    final selectedToken = _selectedToken;
    final selectedAmount = _selectedAmount;
    final phoneNumber = _phoneController.text.trim();
    final navigatorContext = context;
    
    try {
      // Generate a test transaction ID
      final testTxId = 'TEST_${DateTime.now().millisecondsSinceEpoch}';
      
      debugPrint('🧪 TEST: Creating simulated transaction: $testTxId');
      debugPrint('🧪 TEST: Token amount: $tokenAmount $selectedToken');
      
      // Get user's Polygon address using the same method as mining
      final polygonMiningService = PolygonMiningService();
      final polygonAddress = await polygonMiningService.getUserWalletAddress();
      
      if (polygonAddress == null || polygonAddress.isEmpty) {
        debugPrint('❌ TEST: User has no Polygon wallet');
        _showTestErrorDialog(navigatorContext, 'No Polygon wallet found. Please create a wallet first from the Wallet screen.');
        return;
      }
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('❌ TEST: No user logged in');
        _showTestErrorDialog(navigatorContext, 'No user logged in');
        return;
      }
      
      debugPrint('🧪 TEST: Found Polygon address: $polygonAddress');
      
      // Record a test transaction in Firestore
      await FirebaseFirestore.instance.collection('mpesa_transactions').add({
        'checkoutRequestId': testTxId,
        'merchantRequestId': 'TEST_MERCHANT_$testTxId',
        'userId': userId,
        'phoneNumber': phoneNumber,
        'amountKES': selectedAmount,
        'tokenAmount': tokenAmount,
        'tokenSymbol': selectedToken,
        'status': 'processing',
        'paymentMethod': 'mpesa_test',
        'isTestTransaction': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('🧪 TEST: Transaction recorded, now crediting tokens...');
      
      // Credit tokens using the same method as real payments
      final tokenConfig = CryptoPriceService.supportedTokens[selectedToken.toUpperCase()];
      if (tokenConfig == null) {
        debugPrint('❌ TEST: Unknown token: $selectedToken');
        _showTestErrorDialog(navigatorContext, 'Unknown token: $selectedToken');
        return;
      }
      
      debugPrint('🧪 TEST: Sending $tokenAmount $selectedToken to $polygonAddress');
      
      // Send tokens using PolygonWalletService
      const distributorPrivateKey = 'af611eb882635606bdad6e91a011e2658d01378a56654d5b554f9f7cb170a863';
      
      final result = await PolygonWalletService.sendERC20Token(
        tokenContractAddress: tokenConfig.contractAddress,
        toAddress: polygonAddress,
        amount: tokenAmount,
        distributorPrivateKey: distributorPrivateKey,
      );
      
      if (result['success'] == true) {
        final txHash = result['txHash'] as String?;
        debugPrint('✅ TEST: Tokens sent successfully! TX: $txHash');
        
        // Update transaction status
        final txQuery = await FirebaseFirestore.instance
            .collection('mpesa_transactions')
            .where('checkoutRequestId', isEqualTo: testTxId)
            .limit(1)
            .get();
        
        if (txQuery.docs.isNotEmpty) {
          await txQuery.docs.first.reference.update({
            'status': 'credited',
            'polygonTxHash': txHash,
            'completedAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Show success dialog
        _showTestSuccessDialogStatic(navigatorContext, txHash, tokenAmount, selectedToken);
      } else {
        debugPrint('❌ TEST: Failed to send tokens: ${result['error']}');
        _showTestErrorDialog(navigatorContext, 'Failed to send tokens: ${result['error']}');
      }
    } catch (e) {
      debugPrint('❌ TEST: Error in simulated payment: $e');
      _showTestErrorDialog(navigatorContext, 'Test error: $e');
    }
  }
  
  void _showTestErrorDialog(BuildContext ctx, String message) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Text('Test Error', style: TextStyle(color: Colors.red)),
        content: Text(message, style: TextStyle(color: AppTheme.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppTheme.primaryGold)),
          ),
        ],
      ),
    );
  }
  
  void _showTestSuccessDialogStatic(BuildContext ctx, String? txHash, double tokenAmount, String tokenSymbol) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 56),
            ),
            const SizedBox(height: 20),
            Text(
              '🧪 TEST: Payment Successful!',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text(
                '⚠️ TEST MODE - No real payment made',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tokenSymbol,
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tokenAmount.toStringAsFixed(tokenSymbol == 'AKOFA' ? 2 : 6),
                  style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'credited to your wallet',
              style: TextStyle(color: AppTheme.grey),
            ),
            if (txHash != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text('TX Hash:', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 8)}',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate back to wallet
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Done', style: TextStyle(color: AppTheme.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showTestSuccessDialog(String? txHash) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 56),
            ),
            const SizedBox(height: 20),
            Text(
              '🧪 TEST: Payment Successful!',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text(
                '⚠️ TEST MODE - No real payment made',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _selectedToken,
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _tokenAmount.toStringAsFixed(_selectedToken == 'AKOFA' ? 2 : 6),
                  style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'credited to your wallet',
              style: TextStyle(color: AppTheme.grey),
            ),
            if (txHash != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text('TX Hash:', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 8)}',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate back to wallet
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Done', style: TextStyle(color: AppTheme.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentPendingDialog(Map<String, dynamic> result) {
    final checkoutRequestId = result['checkoutRequestId'] as String?;
    final tokenAmount = (result['tokenAmount'] as num?)?.toDouble() ?? 
                        (result['akofaAmount'] as num?)?.toDouble() ?? 
                        _tokenAmount;
    final tokenSymbol = result['tokenSymbol'] as String? ?? _selectedToken;
    final amountKes = result['amountKES'] as double? ?? _selectedAmount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _MpesaPendingDialog(
        checkoutRequestId: checkoutRequestId,
        tokenAmount: tokenAmount,
        tokenSymbol: tokenSymbol,
        amountKes: amountKes,
        walletProvider: widget.walletProvider,
      ),
    );
  }
}

/// Separate widget for M-Pesa pending dialog with auto-polling support
class _MpesaPendingDialog extends StatefulWidget {
  final String? checkoutRequestId;
  final double tokenAmount;
  final String tokenSymbol;
  final double amountKes;
  final EnhancedWalletProvider walletProvider;

  const _MpesaPendingDialog({
    required this.checkoutRequestId,
    required this.tokenAmount,
    required this.tokenSymbol,
    required this.amountKes,
    required this.walletProvider,
  });

  @override
  State<_MpesaPendingDialog> createState() => _MpesaPendingDialogState();
}

class _MpesaPendingDialogState extends State<_MpesaPendingDialog> {
  Timer? _pollTimer;
  bool _isCheckingStatus = false;
  int _pollCount = 0;
  String _statusMessage = 'Waiting for M-Pesa prompt...';
  static const int _maxPollAttempts = 20; // Stop after ~2 minutes (6s * 20)

  @override
  void initState() {
    super.initState();
    // Start auto-polling after 5 seconds (to give user time to see the prompt)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _startAutoPolling();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startAutoPolling() {
    if (widget.checkoutRequestId == null) return;
    
    debugPrint('🔄 Starting M-Pesa auto-poll...');
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      if (_pollCount >= _maxPollAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _statusMessage = 'Auto-check stopped. Use manual check.';
          });
        }
        return;
      }
      
      _pollCount++;
      await _checkStatus(isAutoCheck: true);
    });
  }

  Future<void> _checkStatus({bool isAutoCheck = false}) async {
    if (_isCheckingStatus || widget.checkoutRequestId == null) return;
    
    setState(() {
      _isCheckingStatus = true;
      if (!isAutoCheck) {
        _statusMessage = 'Checking status...';
      }
    });
    
    try {
      debugPrint('🔍 Checking M-Pesa status (attempt $_pollCount)...');
      final status = await widget.walletProvider.checkPaymentStatus(
        widget.checkoutRequestId!,
      );
      
      debugPrint('📊 M-Pesa status: $status');

      if (!mounted) return;

      if (status['success'] == true && status['status'] == 'completed') {
        _pollTimer?.cancel();
        Navigator.pop(context);
        
        // Show success dialog with transaction details
        final txHash = status['txHash'] as String?;
        final tokenAmount = (status['tokenAmount'] as num?)?.toDouble() ?? 
                            (status['akofaAmount'] as num?)?.toDouble() ?? 
                            widget.tokenAmount;
        final tokenSymbol = status['tokenSymbol'] as String? ?? widget.tokenSymbol;
        
        _showSuccessDialog(
          tokenAmount: tokenAmount,
          txHash: txHash,
          tokenSymbol: tokenSymbol,
        );
      } else if (status['status'] == 'failed' || 
                 status['resultCode'] != null && status['resultCode'] != '0') {
        _pollTimer?.cancel();
        final message = status['resultDesc'] ?? status['message'] ?? 'Payment failed';
        setState(() {
          _statusMessage = message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        // Still pending
        if (!isAutoCheck) {
          setState(() {
            _statusMessage = 'Still pending. Auto-checking...';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment still pending. Please approve the M-Pesa prompt on your phone.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ M-Pesa check error: $e');
      if (!isAutoCheck && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  /// Show success dialog with transaction details (same style as PesaPal)
  void _showSuccessDialog({
    required double tokenAmount,
    String? txHash,
    String? tokenSymbol,
  }) {
    final symbol = tokenSymbol ?? widget.tokenSymbol;
    final decimals = symbol == 'AKOFA' ? 2 : 6;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Successful!',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Token amount with symbol badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          symbol,
                          style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tokenAmount.toStringAsFixed(decimals),
                        style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'credited to your wallet',
                    style: TextStyle(
                      color: AppTheme.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Transaction details with hash
            if (txHash != null && txHash.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: AppTheme.grey, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Transaction Hash',
                          style: TextStyle(
                            color: AppTheme.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      txHash.length > 20 
                        ? '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 8)}'
                        : txHash,
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tokens sent via Polygon network',
                style: TextStyle(
                  color: AppTheme.primaryGold.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close success dialog
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: AppTheme.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
            backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
            title: Text(
              'Payment Initiated',
              style: TextStyle(color: AppTheme.primaryGold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
          // Animated phone icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Icon(
                  Icons.phone_android,
                  color: AppTheme.primaryGold,
                  size: 48,
                ),
              );
            },
                ),
                const SizedBox(height: 16),
                Text(
                  'Check your phone for the M-Pesa payment prompt.',
                  style: TextStyle(color: AppTheme.white),
                  textAlign: TextAlign.center,
                ),
          const SizedBox(height: 12),
          // Amount info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'KES ${widget.amountKes.toInt()}',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '→ ${widget.tokenAmount.toStringAsFixed(widget.tokenSymbol == 'AKOFA' ? 2 : 6)} ${widget.tokenSymbol}',
                  style: TextStyle(color: AppTheme.primaryGold),
                ),
              ],
            ),
          ),
                  const SizedBox(height: 16),
          // Auto-poll status indicator
          if (widget.checkoutRequestId != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isCheckingStatus)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryGold,
                    ),
                  )
                else
                  Icon(
                    Icons.autorenew,
                    color: AppTheme.primaryGold,
                    size: 14,
                  ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _isCheckingStatus 
                        ? 'Checking...'
                        : 'Auto-detecting payment',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryGold.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
                  ),
                ],
              ],
            ),
            actions: [
        // Cancel button (easy access)
                TextButton(
          onPressed: () {
            _pollTimer?.cancel();
            Navigator.pop(context);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.red),
          ),
        ),
        // Manual check button
        if (widget.checkoutRequestId != null)
          TextButton(
            onPressed: _isCheckingStatus ? null : () => _checkStatus(isAutoCheck: false),
            child: _isCheckingStatus
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryGold,
                          ),
                        )
                      : Text(
                    'Check Now',
                  style: TextStyle(color: AppTheme.primaryGold),
                ),
              ),
            ],
    );
  }
}