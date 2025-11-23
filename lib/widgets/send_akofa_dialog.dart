import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/akofa_tag_service.dart';
import '../services/secure_wallet_service.dart';
import '../theme/app_theme.dart';

class SendAkofaDialog extends StatefulWidget {
  final String? initialTag;

  const SendAkofaDialog({super.key, this.initialTag});

  @override
  State<SendAkofaDialog> createState() => _SendAkofaDialogState();
}

class _SendAkofaDialogState extends State<SendAkofaDialog> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  bool _isResolving = false;
  bool _isSending = false;
  String? _resolvedAddress;
  String? _resolvedName;
  String? _error;
  String? _successMessage;
  bool _isValidInput = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTag != null) {
      _recipientController.text = widget.initialTag!;
      _resolveInput();
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
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
      // Check if input is a valid Polygon address
      if (_isValidPolygonAddress(input)) {
        setState(() {
          _resolvedAddress = input;
          _resolvedName = null; // No name for raw addresses
          _error = null;
          _isValidInput = true;
        });
      } else {
        // Try to resolve as AKOFA tag
        final result = await AkofaTagService.resolveTag(
          input,
          blockchain: 'polygon',
        );

        if (result['success']) {
          setState(() {
            _resolvedAddress = result['address'];
            _resolvedName = result['firstName'];
            _error = null;
            _isValidInput = true;
          });
        } else {
          setState(() {
            _resolvedAddress = null;
            _resolvedName = null;
            _error = result['error'];
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

  bool _isValidPolygonAddress(String address) {
    // Basic Polygon address validation: starts with '0x' and is 42 characters long
    return address.startsWith('0x') && address.length == 42;
  }

  Future<void> _sendAkofa() async {
    if (_resolvedAddress == null || !_isValidInput) {
      setState(
        () => _error = 'Please enter a valid AKOFA tag or wallet address',
      );
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    // Show password dialog for secure transaction
    final password = await _showPasswordDialog();
    if (password == null) return; // User cancelled

    setState(() {
      _isSending = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final result = await SecureWalletService.signTransactionWithPassword(
        userId: user.uid,
        password: password,
        recipientAddress: _resolvedAddress!,
        amount: amount,
        assetCode: 'AKOFA',
        memo: _memoController.text.trim().isNotEmpty
            ? _memoController.text.trim()
            : 'AKOFA Transfer',
      );

      if (result['success']) {
        setState(() {
          _successMessage =
              'Successfully sent $amount AKOFA to ${_resolvedName ?? _recipientController.text}';
        });

        // Clear form after successful send
        _amountController.clear();
        _memoController.clear();

        // Auto-close after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() => _error = result['error'] ?? 'Failed to send AKOFA');
      }
    } catch (e) {
      setState(() => _error = 'Error sending AKOFA: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<String?> _showPasswordDialog() async {
    String password = '';
    bool obscurePassword = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.darkGrey,
          title: Text(
            'Enter Password',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confirm your password to send AKOFA',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: obscurePassword,
                onChanged: (value) => password = value,
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
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
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.primaryGold,
                    ),
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
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
              onPressed: () => Navigator.of(context).pop(password),
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
                Icon(Icons.send, color: AppTheme.primaryGold, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Send AKOFA',
                  style: AppTheme.headingMedium.copyWith(
                    color: AppTheme.primaryGold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recipient Input (Tag or Address)
            Text(
              'Recipient (AKOFA Tag or Wallet Address)',
              style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _recipientController,
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                hintText: 'e.g., john1234 or G...',
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
                  if (mounted &&
                      _recipientController.text.trim() !=
                          (_resolvedAddress != null
                              ? _recipientController.text.trim()
                              : '')) {
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
                                ? 'Tag Resolved'
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

            // Amount Input
            Text(
              'Amount (AKOFA)',
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
                    onPressed: _isSending
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
                    onPressed: (_isSending || !_isValidInput)
                        ? null
                        : _sendAkofa,
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
                    child: _isSending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Send AKOFA',
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

/// Utility function to show send AKOFA dialog
Future<bool?> showSendAkofaDialog({
  required BuildContext context,
  String? initialTag,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => SendAkofaDialog(initialTag: initialTag),
  );
}
