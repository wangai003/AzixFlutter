import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import 'qr_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart' as local_auth;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/akofa_tag_service.dart';

class SendDialog extends StatefulWidget {
  final String assetCode;
  final String balance;

  const SendDialog({Key? key, required this.assetCode, required this.balance})
    : super(key: key);

  @override
  State<SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<SendDialog> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _showAdvanced = false;
  final _qrKey = GlobalKey(debugLabel: 'QR');
  bool _isScanning = false;
  bool _isResolving = false;
  String? _resolvedAddress;
  String? _resolvedName;
  bool _isValidInput = false;

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
    final stellarProvider = Provider.of<StellarProvider>(
      context,
      listen: false,
    );

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
      // Check if input is a valid Stellar address
      if (_isValidStellarAddress(input)) {
        setState(() {
          _resolvedAddress = input;
          _resolvedName = null; // No name for raw addresses
          _error = null;
          _isValidInput = true;
        });
      } else {
        // Try to resolve as AKOFA tag
        final result = await AkofaTagService.resolveTag(input);

        if (result['success']) {
          setState(() {
            _resolvedAddress = result['publicKey'];
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

  bool _isValidStellarAddress(String address) {
    // Basic Stellar address validation: starts with 'G' and is 56 characters long
    return address.startsWith('G') && address.length == 56;
  }

  @override
  void dispose() {
    _recipientController.dispose();
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
        style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
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
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
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
                      orElse: () => {
                        'code': value,
                        'balance': '0',
                        'name': value,
                      },
                    );

                    setState(() {
                      _selectedAssetCode = value;
                      _selectedAssetBalance = selectedAsset['balance']
                          .toString();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Available Balance: $_selectedAssetBalance $_selectedAssetCode',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
              const SizedBox(height: 24),

              // Recipient Input (Tag or Address)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recipient (AKOFA Tag or Wallet Address)',
                    style: TextStyle(color: AppTheme.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _recipientController,
                    decoration: InputDecoration(
                      hintText: 'e.g., john1234 or G...',
                      hintStyle: TextStyle(
                        color: AppTheme.grey.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.grey.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.grey.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
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
                    style: const TextStyle(color: AppTheme.white, fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a recipient tag or address';
                      }
                      return null;
                    },
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _resolvedName != null
                                      ? 'Tag Resolved'
                                      : 'Valid Address',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_resolvedName != null)
                                  Text(
                                    _resolvedName!,
                                    style: const TextStyle(
                                      color: AppTheme.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                Text(
                                  _resolvedAddress!.substring(0, 8) +
                                      '...' +
                                      _resolvedAddress!.substring(
                                        _resolvedAddress!.length - 8,
                                      ),
                                  style: TextStyle(
                                    color: AppTheme.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                  suffixText: _selectedAssetCode,
                ),
                style: const TextStyle(color: AppTheme.white),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                  _showAdvanced
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.grey,
                ),
                label: Text(
                  _showAdvanced
                      ? 'Hide Advanced Options'
                      : 'Show Advanced Options',
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
                      borderSide: BorderSide(
                        color: AppTheme.grey.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.grey.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    helperText: 'Add a note to this transaction',
                    helperStyle: TextStyle(
                      color: AppTheme.grey.withOpacity(0.7),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.white),
                  maxLength: 28, // Stellar memo text limit
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],

              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryGold,
                    ),
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
          child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
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

  Future<String?> _showTransactionPasswordDialog() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.black,
          title: Text(
            'Confirm Transaction',
            style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your password to sign and send $_amountController.text $_selectedAssetCode to ${_recipientController.text}',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: AppTheme.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.grey.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                style: const TextStyle(color: AppTheme.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel', style: TextStyle(color: AppTheme.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirm & Send'),
            ),
          ],
        );
      },
    );
  }

  void _handleSend() async {
    if (_formKey.currentState!.validate() && _isValidInput) {
      // Show password confirmation dialog
      final password = await _showTransactionPasswordDialog();
      if (password == null || password.isEmpty) {
        return; // User cancelled
      }

      // Verify password with Firebase Auth
      final authProvider = Provider.of<local_auth.AuthProvider>(
        context,
        listen: false,
      );
      final currentUser = authProvider.user;
      if (currentUser == null || currentUser.email == null) {
        setState(() {
          _error = 'Authentication required. Please log in again.';
        });
        return;
      }

      try {
        // Re-authenticate user with password
        final credential = EmailAuthProvider.credential(
          email: currentUser.email!,
          password: password,
        );
        await currentUser.reauthenticateWithCredential(credential);
      } catch (e) {
        setState(() {
          _error = 'Invalid password. Please try again.';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        String destinationAddress =
            _resolvedAddress ?? _recipientController.text.trim();
        final amount = _amountController.text;
        final memo = _memoController.text.isNotEmpty
            ? _memoController.text
            : null;
        final stellarProvider = Provider.of<StellarProvider>(
          context,
          listen: false,
        );
        final result = await stellarProvider.sendAsset(
          _selectedAssetCode,
          destinationAddress,
          amount,
          memo: memo,
        );
        if (result['success'] == true) {
          if (mounted) {
            Navigator.of(context).pop(true);
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
