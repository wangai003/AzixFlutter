import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../theme/app_theme.dart';
import 'qr_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart' as local_auth;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/akofa_tag_service.dart';
import '../services/secure_wallet_service.dart';
import '../services/polygon_wallet_service.dart';
import 'transaction_auth_dialog.dart';

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
  String _selectedBlockchain = 'polygon'; // Default to polygon
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

  void _loadAvailableAssets() async {
    final walletProvider = Provider.of<EnhancedWalletProvider>(
      context,
      listen: false,
    );

    // Initialize with empty list
    _availableAssets = [];

    // Add Polygon tokens from wallet (dynamic tokens only)
    for (var entry in walletProvider.polygonTokens.entries) {
      final token = entry.value;

      // Only add tokens with positive balance
      if ((token['balance'] as num?) != null && (token['balance'] as num) > 0) {
        _availableAssets.add({
          'code': entry.key,
          'balance': token['balance'].toString(),
          'name': token['name'] ?? entry.key,
          'blockchain': 'polygon',
          'contractAddress': token['contractAddress'],
          'decimals': token['decimals'],
          'isNative': token['isNative'] ?? false,
        });
      }
    }

    // Load Polygon assets if user has Polygon wallet
    final authProvider = Provider.of<local_auth.AuthProvider>(
      context,
      listen: false,
    );
    final user = authProvider.user;

    if (user != null) {
      final hasPolygonWallet = await PolygonWalletService.hasPolygonWallet(
        user.uid,
      );
      if (hasPolygonWallet) {
        final polygonAddress =
            await PolygonWalletService.getPolygonWalletAddress(user.uid);
        if (polygonAddress != null) {
          final polygonBalances =
              await PolygonWalletService.getAllPolygonTokenBalances(
                polygonAddress,
              );

          if (polygonBalances['success'] == true) {
            final tokens = polygonBalances['tokens'] as Map<String, dynamic>;

            for (final entry in tokens.entries) {
              final token = entry.value as Map<String, dynamic>;
              final balance = token['balance'] as double;

              // Only add tokens with positive balance
              if (balance > 0) {
                _availableAssets.add({
                  'code': token['symbol'],
                  'balance': balance.toString(),
                  'name': token['name'],
                  'blockchain': 'polygon',
                  'contractAddress': token['contractAddress'],
                  'decimals': token['decimals'],
                  'isNative': token['isNative'] ?? false,
                });
              }
            }
          }
        }
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
      // Check if input is a valid address for the selected blockchain
      if (_isValidAddressForBlockchain(input, _selectedBlockchain)) {
        setState(() {
          _resolvedAddress = input;
          _resolvedName = null; // No name for raw addresses
          _error = null;
          _isValidInput = true;
        });
      } else {
        // Try to resolve as AKOFA tag for the selected blockchain
        final result = await AkofaTagService.resolveTag(
          input,
          blockchain: _selectedBlockchain,
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

  bool _isValidAddressForBlockchain(String address, String blockchain) {
    return AkofaTagService.isValidAddress(address, blockchain);
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
    return Dialog(
      backgroundColor: AppTheme.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.send, color: AppTheme.primaryGold, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Send Tokens',
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.primaryGold,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
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
                          final blockchain = asset['blockchain'] ?? 'stellar';
                          final blockchainIcon = blockchain == 'polygon'
                              ? '🔺'
                              : '⭐';
                          return DropdownMenuItem<String>(
                            value: asset['code'],
                            child: Text(
                              '$blockchainIcon ${asset['code']} - ${asset['name']}',
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
                                'blockchain': 'stellar',
                              },
                            );

                            setState(() {
                              _selectedAssetCode = value;
                              _selectedAssetBalance = selectedAsset['balance']
                                  .toString();
                              _selectedBlockchain =
                                  selectedAsset['blockchain'] ?? 'stellar';
                            });

                            // Re-resolve input if there's text, since blockchain changed
                            if (_recipientController.text.trim().isNotEmpty) {
                              _resolveInput();
                            }
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

                      // Recipient Input (Tag or Address)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recipient (AKOFA Tag or ${_selectedBlockchain == 'polygon' ? 'Polygon' : 'Stellar'} Address)',
                            style: TextStyle(
                              color: AppTheme.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _recipientController,
                            decoration: InputDecoration(
                              hintText: _selectedBlockchain == 'polygon'
                                  ? 'e.g., john1234 or 0x...'
                                  : 'e.g., john1234 or G...',
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
                                borderSide: BorderSide(
                                  color: AppTheme.primaryGold,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isResolving
                                      ? Icons.hourglass_top
                                      : Icons.search,
                                  color: AppTheme.primaryGold,
                                ),
                                onPressed: _isResolving ? null : _resolveInput,
                              ),
                            ),
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 16,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a recipient tag or address';
                              }
                              return null;
                            },
                            onChanged: (_) {
                              // Auto-resolve after user stops typing
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  if (mounted &&
                                      _recipientController.text.trim() !=
                                          (_resolvedAddress != null
                                              ? _recipientController.text.trim()
                                              : '')) {
                                    _resolveInput();
                                  }
                                },
                              );
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,7}'),
                          ),
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
                              borderSide: BorderSide(
                                color: AppTheme.primaryGold,
                              ),
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
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
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
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: AppTheme.black,
                      disabledBackgroundColor: AppTheme.grey.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showTransactionAuthDialog() async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) {
        return TransactionAuthDialog(
          amount: _amountController.text,
          assetCode: _selectedAssetCode,
          recipient: _recipientController.text,
        );
      },
    );
  }

  void _handleSend() async {
    if (_formKey.currentState!.validate() && _isValidInput) {
      // Show authentication dialog (biometric or password)
      final authResult = await _showTransactionAuthDialog();
      if (authResult == null || authResult['success'] != true) {
        return; // User cancelled or auth failed
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

        // Handle different blockchains
        if (_selectedBlockchain == 'polygon') {
          // Polygon transaction
          if (authResult['method'] == 'biometric') {
            // For Polygon, we need password authentication for now
            // TODO: Implement biometric authentication for Polygon
            setState(() {
              _isLoading = false;
              _error =
                  'Password authentication required for Polygon transactions';
            });
            return;
          }

          // Get password from auth result
          final password = authResult['password'];
          if (password == null) {
            setState(() {
              _isLoading = false;
              _error = 'Password required for Polygon transactions';
            });
            return;
          }

          final authProvider = Provider.of<local_auth.AuthProvider>(
            context,
            listen: false,
          );
          final user = authProvider.user;

          if (user != null) {
            // Determine asset details
            final selectedAsset = _availableAssets.firstWhere(
              (asset) => asset['code'] == _selectedAssetCode,
              orElse: () => {
                'code': _selectedAssetCode,
                'isNative': _selectedAssetCode.toUpperCase() == 'MATIC',
                'contractAddress': '',
              },
            );
            final isNative = selectedAsset['isNative'] == true ||
                _selectedAssetCode.toUpperCase() == 'MATIC';
            final contractAddress =
                (selectedAsset['contractAddress'] ?? '').toString();

            if (!isNative && contractAddress.isEmpty) {
              setState(() {
                _isLoading = false;
                _error = 'Token contract not found for $_selectedAssetCode';
              });
              return;
            }

            // Send Polygon transaction (MATIC vs ERC-20)
            final result = isNative
                ? await PolygonWalletService.sendMaticTransaction(
                    userId: user.uid,
                    password: password,
                    toAddress: destinationAddress,
                    amountMatic: double.parse(amount),
                  )
                : await PolygonWalletService.sendERC20TokenWithAuth(
                    userId: user.uid,
                    password: password,
                    tokenContractAddress: contractAddress,
                    toAddress: destinationAddress,
                    amount: double.parse(amount),
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

                // Surface gas sponsor details for QA visibility (if applicable)
                if (result['maticToppedUp'] == true) {
                  final feeToken = result['feeToken'] as String?;
                  final feeCharged = result['feeCharged'] as double?;
                  final feeTxHash = result['feeTxHash'] as String?;
                  final topUpTxHash = result['topUpTxHash'] as String?;

                  final details = <String>[
                    if (feeCharged != null && feeToken != null)
                      'Fee: ${feeCharged.toStringAsFixed(6)} $feeToken',
                    if (feeTxHash != null && feeTxHash.isNotEmpty)
                      'Fee Tx: ${feeTxHash.substring(0, 8)}...',
                    if (topUpTxHash != null && topUpTxHash.isNotEmpty)
                      'Top-up Tx: ${topUpTxHash.substring(0, 8)}...',
                  ].join(' | ');

                  if (details.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gas sponsored. $details'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              }
            } else {
              setState(() {
                _isLoading = false;
                _error =
                    result['error'] ?? 'Failed to send $_selectedAssetCode';
              });
            }
          } else {
            setState(() {
              _isLoading = false;
              _error = 'User authentication required';
            });
          }
        } else {
          // Stellar transaction (existing logic)
          // Use secure wallet service for signing if biometric auth was used
          if (authResult['method'] == 'biometric') {
            final authProvider = Provider.of<local_auth.AuthProvider>(
              context,
              listen: false,
            );
            final user = authProvider.user;

            if (user != null) {
              final result =
                  await SecureWalletService.signTransactionWithBiometrics(
                    userId: user.uid,
                    recipientAddress: destinationAddress,
                    amount: double.parse(amount),
                    assetCode: _selectedAssetCode,
                    memo: memo ?? '',
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
                  _error =
                      result['error'] ?? 'Failed to send $_selectedAssetCode';
                });
              }
            } else {
              setState(() {
                _isLoading = false;
                _error = 'User authentication required';
              });
            }
          } else {
            // Password authentication - use existing StellarProvider method
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
                _error =
                    result['error'] ?? 'Failed to send $_selectedAssetCode';
              });
            }
          }
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
