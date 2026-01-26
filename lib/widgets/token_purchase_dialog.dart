import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/crypto_price_service.dart';
import '../services/currency_service.dart';
import '../services/polygon_wallet_service.dart';
import '../theme/app_theme.dart';

/// Multi-Token Purchase Dialog
/// 
/// Allows users to purchase AKOFA, USDC, or USDT tokens
/// with real-time pricing and Coinbase-style price locking.
class TokenPurchaseDialog extends StatefulWidget {
  final Function(TokenPurchaseResult) onProceedToPayment;
  
  const TokenPurchaseDialog({
    super.key,
    required this.onProceedToPayment,
  });

  @override
  State<TokenPurchaseDialog> createState() => _TokenPurchaseDialogState();
}

class _TokenPurchaseDialogState extends State<TokenPurchaseDialog> {
  final CryptoPriceService _priceService = CryptoPriceService();
  final TextEditingController _amountController = TextEditingController();
  
  // Selected token
  String _selectedToken = 'AKOFA';
  
  // Current prices
  Map<String, CryptoPrice> _prices = {};
  bool _isLoadingPrices = true;
  String? _priceError;
  
  // Input mode: 'tokens' or 'kes'
  String _inputMode = 'kes'; // Default to KES input
  
  // Calculated values
  double _tokenAmount = 0;
  double _kesAmount = 0;

  // Display currency (for conversion preview)
  String _displayCurrency = 'KES';
  double _displayAmount = 0.0;
  bool _isConverting = false;

  // Supported display currencies
  static const List<String> _displayCurrencies = ['KES', 'USD', 'NGN', 'ZAR'];
  
  // Price lock
  LockedPrice? _lockedPrice;
  Timer? _priceLockTimer;
  Duration _lockRemainingTime = Duration.zero;
  
  // Price refresh timer
  Timer? _priceRefreshTimer;
  
  // Preset amounts in KES
  final List<double> _presetAmountsKES = [10, 50, 100, 500, 1000, 5000, 10000];
  
  @override
  void initState() {
    super.initState();
    _loadPrices();
    _startPriceRefresh();
    _displayAmount = _kesAmount;
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _priceRefreshTimer?.cancel();
    _priceLockTimer?.cancel();
    super.dispose();
  }
  
  void _startPriceRefresh() {
    _priceRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_lockedPrice == null) { // Don't refresh if price is locked
        _loadPrices();
      }
    });
  }
  
  Future<void> _loadPrices() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingPrices = true;
      _priceError = null;
    });
    
    try {
      final tokens = ['AKOFA', 'USDC', 'USDT'];
      final Map<String, CryptoPrice> newPrices = {};
      
      for (final token in tokens) {
        newPrices[token] = await _priceService.getTokenPriceKES(token);
      }
      
      if (mounted) {
        setState(() {
          _prices = newPrices;
          _isLoadingPrices = false;
          _recalculateAmounts();
        });
        _updateDisplayAmount();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _priceError = 'Failed to load prices: $e';
          _isLoadingPrices = false;
        });
      }
    }
  }
  
  void _recalculateAmounts() {
    final price = _prices[_selectedToken];
    
    // Calculate even if price is null - use fallback rates
    if (_inputMode == 'kes') {
      if (price != null && price.priceKES > 0) {
        _tokenAmount = _kesAmount / price.priceKES;
      } else if (_selectedToken == 'AKOFA') {
        _tokenAmount = _kesAmount / 5.52; // Default: 1 AKOFA = 5.52 KES
      } else {
        _tokenAmount = _kesAmount / 155.0; // Default: 155 KES = 1 USD
      }
    } else {
      if (price != null && price.priceKES > 0) {
        _kesAmount = _tokenAmount * price.priceKES;
      } else if (_selectedToken == 'AKOFA') {
        _kesAmount = _tokenAmount * 5.52; // Default: 1 AKOFA = 5.52 KES
      } else {
        _kesAmount = _tokenAmount * 155.0; // Default: 1 USD = 155 KES
      }
    }
    
    // Clear any locked price when amount changes
    if (_lockedPrice != null) {
      _lockedPrice = null;
      _priceLockTimer?.cancel();
    }

    _updateDisplayAmount();
  }

  Future<void> _updateDisplayAmount() async {
    if (_kesAmount <= 0) {
      if (mounted) setState(() => _displayAmount = 0.0);
      return;
    }
    if (_displayCurrency == 'KES') {
      if (mounted) setState(() => _displayAmount = _kesAmount);
      return;
    }
    try {
      setState(() => _isConverting = true);
      final converted = await CurrencyService.convertCurrency(
        _kesAmount,
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
          _displayAmount = _kesAmount;
        });
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }
  
  void _selectToken(String token) {
    setState(() {
      _selectedToken = token;
      _lockedPrice = null;
      _priceLockTimer?.cancel();
      _recalculateAmounts();
    });
    _updateDisplayAmount();
  }
  
  void _setKESAmount(double amount) {
    setState(() {
      _inputMode = 'kes';
      _kesAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
      _recalculateAmounts();
    });
    _updateDisplayAmount();
  }
  
  void _onAmountChanged(String value) {
    final amount = double.tryParse(value) ?? 0;
    final price = _prices[_selectedToken];
    
    // Always update state - don't skip if price is null
    setState(() {
      if (_inputMode == 'kes') {
        _kesAmount = amount;
        // Calculate token amount based on price or use default rate
        if (price != null && price.priceKES > 0) {
          _tokenAmount = _kesAmount / price.priceKES;
        } else if (_selectedToken == 'AKOFA') {
          // Default AKOFA rate: 1 AKOFA = 5.52 KES
          _tokenAmount = _kesAmount / 5.52;
        } else {
          // Default stablecoin rate: ~155 KES = 1 USD
          _tokenAmount = _kesAmount / 155.0;
        }
      } else {
        _tokenAmount = amount;
        // Calculate KES amount based on price or use default rate
        if (price != null && price.priceKES > 0) {
          _kesAmount = _tokenAmount * price.priceKES;
        } else if (_selectedToken == 'AKOFA') {
          // Default AKOFA rate: 1 AKOFA = 5.52 KES
          _kesAmount = _tokenAmount * 5.52;
        } else {
          // Default stablecoin rate: 1 USD = ~155 KES
          _kesAmount = _tokenAmount * 155.0;
        }
      }
      
      // Clear locked price when amount changes
      if (_lockedPrice != null) {
        _lockedPrice = null;
        _priceLockTimer?.cancel();
      }
    });
    
    _updateDisplayAmount();
    // Debug: Print current state
    debugPrint('📝 Amount changed: KES=$_kesAmount, Token=$_tokenAmount, Button enabled: ${_tokenAmount > 0 && _kesAmount >= 10}');
  }
  
  void _toggleInputMode() {
    setState(() {
      if (_inputMode == 'kes') {
        _inputMode = 'tokens';
        _amountController.text = _tokenAmount > 0 ? _tokenAmount.toStringAsFixed(4) : '';
      } else {
        _inputMode = 'kes';
        _amountController.text = _kesAmount > 0 ? _kesAmount.toStringAsFixed(0) : '';
      }
    });
    _updateDisplayAmount();
  }
  
  Future<void> _lockPrice() async {
    if (_tokenAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      final locked = await _priceService.lockPrice(
        symbol: _selectedToken,
        tokenAmount: _tokenAmount,
      );
      
      setState(() {
        _lockedPrice = locked;
        _lockRemainingTime = locked.remainingTime;
      });
      
      // Start countdown timer
      _priceLockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_lockedPrice == null || _lockedPrice!.isExpired) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _lockedPrice = null;
              _lockRemainingTime = Duration.zero;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Price lock expired. Please lock again to proceed.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _lockRemainingTime = _lockedPrice!.remainingTime;
            });
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Price locked for 5 minutes! ${_tokenAmount.toStringAsFixed(4)} $_selectedToken @ KES ${locked.pricePerTokenKES.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to lock price: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  bool _isCheckingBalance = false;
  
  Future<void> _proceedToPayment() async {
    if (_tokenAmount <= 0 || _kesAmount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum purchase is KES 10'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final price = _prices[_selectedToken];
    if (price == null) return;
    
    // Show loading indicator while checking balance
    setState(() => _isCheckingBalance = true);
    
    try {
      // Check if distribution account has sufficient balance
      final tokenConfig = CryptoPriceService.supportedTokens[_selectedToken.toUpperCase()];
      if (tokenConfig == null) {
        _showError('Unsupported token: $_selectedToken');
        return;
      }
      
      // Distributor private key (same as used in services)
      const distributorPrivateKey = 'af611eb882635606bdad6e91a011e2658d01378a56654d5b554f9f7cb170a863';
      
      final balanceCheck = await PolygonWalletService.checkDistributorTokenBalance(
        tokenContractAddress: tokenConfig.contractAddress,
        distributorPrivateKey: distributorPrivateKey,
        requiredAmount: _tokenAmount,
        tokenDecimals: tokenConfig.decimals,
      );
      
      if (!mounted) return;
      
      if (balanceCheck['success'] != true) {
        _showError(balanceCheck['error'] ?? 'Failed to check token availability');
        return;
      }
      
      if (balanceCheck['hasBalance'] != true) {
        final available = balanceCheck['availableBalance'] ?? 0.0;
        _showInsufficientBalanceDialog(available);
        return;
      }
      
      // Balance is sufficient, proceed with price lock and payment
      if (_lockedPrice == null) {
        await _lockPrice();
        if (_lockedPrice != null) {
          _navigateToPayment();
        }
      } else {
        _navigateToPayment();
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingBalance = false);
      }
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showInsufficientBalanceDialog(double availableBalance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Text(
              'Insufficient Supply',
              style: TextStyle(color: Colors.orange, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The requested amount of $_selectedToken is not currently available.',
              style: TextStyle(color: AppTheme.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Requested:', style: TextStyle(color: AppTheme.grey)),
                      Text(
                        '${_tokenAmount.toStringAsFixed(_selectedToken == 'AKOFA' ? 2 : 6)} $_selectedToken',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Available:', style: TextStyle(color: AppTheme.grey)),
                      Text(
                        '${availableBalance.toStringAsFixed(_selectedToken == 'AKOFA' ? 2 : 6)} $_selectedToken',
                        style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please try a smaller amount or check back later.',
              style: TextStyle(color: AppTheme.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppTheme.primaryGold)),
          ),
        ],
      ),
    );
  }
  
  void _navigateToPayment() {
    final result = TokenPurchaseResult(
      tokenSymbol: _selectedToken,
      tokenAmount: _lockedPrice?.tokenAmount ?? _tokenAmount,
      amountKES: _lockedPrice?.totalKES ?? _kesAmount,
      pricePerTokenKES: _lockedPrice?.pricePerTokenKES ?? _prices[_selectedToken]!.priceKES,
      priceLockId: _lockedPrice?.lockId,
      lockedPrice: _lockedPrice,
    );
    
    Navigator.pop(context);
    widget.onProceedToPayment(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 700),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Buy Crypto',
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
                  'Select token and enter amount',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                ),
                
                const SizedBox(height: 20),
                
                // Token Selection
                Text(
                  'Select Token',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
                const SizedBox(height: 8),
                _buildTokenSelector(),
                
                const SizedBox(height: 20),
                
                // Current Price Display
                if (_isLoadingPrices)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: AppTheme.primaryGold),
                    ),
                  )
                else if (_priceError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _priceError!,
                      style: TextStyle(color: Colors.red),
                    ),
                  )
                else
                  _buildPriceDisplay(),
                
                const SizedBox(height: 16),
                
                // Amount Input
                _buildAmountInput(),
                
                const SizedBox(height: 12),
                
                // Preset Amounts
                _buildPresetAmounts(),
                
                const SizedBox(height: 16),
                
                // Conversion Display
                if (_tokenAmount > 0 && _kesAmount > 0)
                  _buildConversionDisplay(),
                
                const SizedBox(height: 16),
                
                // Price Lock Section
                _buildPriceLockSection(),
                
                const SizedBox(height: 20),
                
                // Proceed Button - enabled when tokenAmount > 0 AND kesAmount >= 10
                ElevatedButton(
                  onPressed: (_tokenAmount > 0 && _kesAmount >= 10 && !_isCheckingBalance) 
                    ? _proceedToPayment 
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: AppTheme.grey.withValues(alpha: 0.3),
                    disabledForegroundColor: AppTheme.grey,
                  ),
                  child: _isCheckingBalance
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Checking availability...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _lockedPrice != null 
                          ? 'Proceed to Payment'
                          : 'Lock Price & Continue',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                ),
                
                const SizedBox(height: 12),
                
                // Info text
                Text(
                  'Price is locked for 5 minutes once you proceed',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.grey,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTokenSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTokenOption('AKOFA', 'AKOFA', Icons.token),
          _buildTokenOption('USDC', 'USDC', Icons.attach_money),
          _buildTokenOption('USDT', 'USDT', Icons.monetization_on),
        ],
      ),
    );
  }
  
  Widget _buildTokenOption(String symbol, String label, IconData icon) {
    final isSelected = _selectedToken == symbol;
    final price = _prices[symbol];
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectToken(symbol),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGold.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected 
              ? Border.all(color: AppTheme.primaryGold, width: 2)
              : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryGold : AppTheme.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryGold : AppTheme.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              if (price != null) ...[
                const SizedBox(height: 2),
                Text(
                  'KES ${price.priceKES.toStringAsFixed(symbol == 'AKOFA' ? 0 : 2)}',
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPriceDisplay() {
    final price = _prices[_selectedToken];
    if (price == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Price',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
              const SizedBox(height: 4),
              Text(
                '1 $_selectedToken = KES ${price.priceKES.toStringAsFixed(2)}',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedToken != 'AKOFA')
                Text(
                  '≈ \$${price.priceUSD.toStringAsFixed(4)}',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
            ],
          ),
          Column(
            children: [
              Icon(
                Icons.refresh,
                color: AppTheme.grey,
                size: 16,
              ),
              Text(
                'Live',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _inputMode == 'kes' ? 'Amount (KES)' : 'Amount ($_selectedToken)',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
            TextButton.icon(
              onPressed: _toggleInputMode,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text(
                _inputMode == 'kes' ? 'Enter tokens' : 'Enter KES',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryGold,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: _onAmountChanged,
          style: const TextStyle(
            color: AppTheme.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: _inputMode == 'kes' ? '0' : '0.00',
            hintStyle: TextStyle(
              color: AppTheme.grey.withOpacity(0.5),
              fontSize: 24,
            ),
            prefixText: _inputMode == 'kes' ? 'KES ' : '',
            prefixStyle: TextStyle(
              color: AppTheme.primaryGold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            suffixText: _inputMode == 'tokens' ? _selectedToken : null,
            suffixStyle: TextStyle(
              color: AppTheme.primaryGold,
              fontSize: 18,
            ),
            filled: true,
            fillColor: AppTheme.black.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPresetAmounts() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presetAmountsKES.map((amount) {
        final isSelected = _kesAmount == amount && _inputMode == 'kes';
        return GestureDetector(
          onTap: () => _setKESAmount(amount),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                ? AppTheme.primaryGold.withOpacity(0.2) 
                : AppTheme.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: isSelected 
                ? Border.all(color: AppTheme.primaryGold)
                : Border.all(color: AppTheme.grey.withOpacity(0.3)),
            ),
            child: Text(
              'KES ${amount.toInt()}',
              style: TextStyle(
                color: isSelected ? AppTheme.primaryGold : AppTheme.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildConversionDisplay() {
    final price = _prices[_selectedToken];
    
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'You Pay',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
              Text(
                'KES ${_kesAmount.toStringAsFixed(2)}',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
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
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  value: _displayCurrency,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.grey.withOpacity(0.3),
                      ),
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
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
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
                      style:
                          AppTheme.bodySmall.copyWith(color: AppTheme.white),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Icon(Icons.arrow_downward, color: AppTheme.primaryGold, size: 20),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'You Receive',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
              Text(
                '${_tokenAmount.toStringAsFixed(_selectedToken == 'AKOFA' ? 2 : 6)} $_selectedToken',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_selectedToken != 'AKOFA' && price != null) ...[
            const SizedBox(height: 4),
            Text(
              '≈ \$${(_tokenAmount * price.priceUSD).toStringAsFixed(2)} USD',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPriceLockSection() {
    if (_lockedPrice == null) {
      return const SizedBox();
    }
    
    final minutes = _lockRemainingTime.inMinutes;
    final seconds = _lockRemainingTime.inSeconds % 60;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Price Locked',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'KES ${_lockedPrice!.pricePerTokenKES.toStringAsFixed(2)} per $_selectedToken',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of token purchase selection
class TokenPurchaseResult {
  final String tokenSymbol;
  final double tokenAmount;
  final double amountKES;
  final double pricePerTokenKES;
  final String? priceLockId;
  final LockedPrice? lockedPrice;
  
  TokenPurchaseResult({
    required this.tokenSymbol,
    required this.tokenAmount,
    required this.amountKES,
    required this.pricePerTokenKES,
    this.priceLockId,
    this.lockedPrice,
  });
}

