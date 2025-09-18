import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../theme/app_theme.dart';
import '../services/akofa_tag_service.dart';

class SendAkofaDialog extends StatefulWidget {
  final EnhancedWalletProvider walletProvider;
  final bool useBiometrics;

  const SendAkofaDialog({
    super.key,
    required this.walletProvider,
    this.useBiometrics = false,
  });

  @override
  State<SendAkofaDialog> createState() => _SendAkofaDialogState();
}

class _SendAkofaDialogState extends State<SendAkofaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _isResolvingTag = false;
  String? _resolvedAddress;
  String? _resolvedTagInfo;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Send AKOFA Tokens',
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

              const SizedBox(height: 24),

              // Balance Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Balance',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                    ),
                    Text(
                      '${widget.walletProvider.akofaBalance} AKOFA',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Recipient Address or Akofa Tag
              TextFormField(
                controller: _addressController,
                style: TextStyle(color: AppTheme.white),
                decoration: InputDecoration(
                  labelText: 'Recipient Address or Akofa Tag',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  hintText: 'G... (Stellar address) or john1234 (Akofa tag)',
                  hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.account_circle,
                    color: AppTheme.primaryGold,
                  ),
                  suffixIcon: _isResolvingTag
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        )
                      : null,
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
                validator: _validateAddress,
                maxLines: null,
                onChanged: _onAddressChanged,
              ),

              // Show resolved tag info
              if (_resolvedTagInfo != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resolvedTagInfo!,
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                style: TextStyle(color: AppTheme.white),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount (AKOFA)',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  hintText: '0.00',
                  hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.token, color: AppTheme.primaryGold),
                  suffixText: 'AKOFA',
                  suffixStyle: TextStyle(color: AppTheme.primaryGold),
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
                validator: _validateAmount,
              ),

              const SizedBox(height: 16),

              // Memo (Optional)
              TextFormField(
                controller: _memoController,
                style: TextStyle(color: AppTheme.white),
                maxLength: 28,
                decoration: InputDecoration(
                  labelText: 'Memo (Optional)',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  hintText: 'Add a note...',
                  hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.message, color: AppTheme.primaryGold),
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
              ),

              const SizedBox(height: 16),

              // Fee Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Network fee: ~0.00001 XLM',
                        style: AppTheme.bodySmall.copyWith(color: Colors.blue),
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
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 16),
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

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
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
                      onPressed: _isLoading ? null : _sendTokens,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Send Tokens',
                              style: TextStyle(fontWeight: FontWeight.w600),
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

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter recipient address or Akofa tag';
    }

    final trimmedValue = value.trim();

    // Check if it's a Stellar address
    if (trimmedValue.startsWith('G') && trimmedValue.length == 56) {
      return null; // Valid Stellar address
    }

    // Check if it's an Akofa tag
    if (AkofaTagService.isValidTagFormat(trimmedValue)) {
      return null; // Valid tag format
    }

    return 'Please enter a valid Stellar address (G...) or Akofa tag (name + 4 digits)';
  }

  Future<void> _onAddressChanged(String value) async {
    final trimmedValue = value.trim();

    // Clear previous resolution
    setState(() {
      _resolvedAddress = null;
      _resolvedTagInfo = null;
    });

    // If it's a potential tag, try to resolve it
    if (AkofaTagService.isValidTagFormat(trimmedValue) &&
        trimmedValue.length >= 5) {
      setState(() {
        _isResolvingTag = true;
      });

      try {
        final result = await AkofaTagService.resolveTag(trimmedValue);
        if (result['success']) {
          setState(() {
            _resolvedAddress = result['publicKey'];
            _resolvedTagInfo =
                'Tag resolved to: ${result['firstName']}\'s wallet';
            _isResolvingTag = false;
          });
        } else {
          setState(() {
            _resolvedTagInfo = 'Tag not found or inactive';
            _isResolvingTag = false;
          });
        }
      } catch (e) {
        setState(() {
          _resolvedTagInfo = 'Error resolving tag';
          _isResolvingTag = false;
        });
      }
    } else {
      setState(() {
        _isResolvingTag = false;
      });
    }
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter amount';
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid number';
    }

    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }

    final balance = double.tryParse(widget.walletProvider.akofaBalance) ?? 0;
    if (amount > balance) {
      return 'Insufficient balance';
    }

    return null;
  }

  Future<void> _sendTokens() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Determine the recipient address (use resolved address if tag was used)
      final inputAddress = _addressController.text.trim();
      final recipientAddress = _resolvedAddress ?? inputAddress;

      final result = widget.useBiometrics
          ? await widget.walletProvider.sendAkofaWithBiometrics(
              recipientAddress: recipientAddress,
              amount: double.parse(_amountController.text),
              memo: _memoController.text.trim().isEmpty
                  ? null
                  : _memoController.text.trim(),
            )
          : await widget.walletProvider.sendAkofaTokens(
              recipientAddress: recipientAddress,
              amount: double.parse(_amountController.text),
              memo: _memoController.text.trim().isEmpty
                  ? null
                  : _memoController.text.trim(),
            );

      if (result['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.useBiometrics
                  ? 'AKOFA tokens sent securely with biometric authentication!'
                  : 'AKOFA tokens sent successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to send tokens';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
