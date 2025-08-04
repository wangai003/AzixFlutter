import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../theme/app_theme.dart';
import 'qr_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';

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
  bool _checkingTag = false;
  String? _resolvedAddress;
  bool _promptCreateTag = false;

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

  Future<String?> _resolveAkofaTag(String input) async {
    if (!input.startsWith('₳')) return input;
    final tag = input.substring(1).trim().toLowerCase();
    debugPrint('Resolving Akofa tag: $tag');
    setState(() { _checkingTag = true; });
    final query = await FirebaseFirestore.instance
        .collection('USER')
        .where('akofaTag', isEqualTo: tag)
        .limit(1)
        .get();
    debugPrint('USER query result count: ${query.docs.length}');
    setState(() { _checkingTag = false; });
    if (query.docs.isNotEmpty) {
      final userId = query.docs.first.id;
      debugPrint('Found userId: $userId for tag: $tag');
      final walletDoc = await FirebaseFirestore.instance.collection('wallets').doc(userId).get();
      debugPrint('Wallet doc exists: ${walletDoc.exists}');
      if (walletDoc.exists) {
        final publicKey = walletDoc.data()?['publicKey'];
        debugPrint('Wallet publicKey: $publicKey');
        if (publicKey != null && publicKey is String && publicKey.isNotEmpty) {
          return publicKey;
        } else {
          setState(() { _error = 'Recipient has no wallet public key.'; });
          debugPrint('Recipient has no wallet public key.');
          return null;
        }
      } else {
        setState(() { _error = 'Recipient has not set up a wallet.'; });
        debugPrint('Recipient has not set up a wallet.');
        return null;
      }
    } else {
      setState(() { _error = 'Akofa Tag not found.'; });
      debugPrint('Akofa Tag not found: $tag');
      return null;
    }
  }

  Future<bool> _userHasAkofaTag() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.user?.uid;
    if (uid == null) return false;
    final doc = await FirebaseFirestore.instance.collection('USER').doc(uid).get();
    final data = doc.data();
    return data != null && (data['akofaTag'] != null && data['akofaTag'].toString().isNotEmpty);
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
              _selectedAssetCode == 'AKOFA'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recipient Akofa Tag', style: TextStyle(color: AppTheme.grey, fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('₳', style: TextStyle(fontSize: 22, color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _addressController,
                                  decoration: InputDecoration(
                                    hintText: 'username',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                    suffixIcon: _checkingTag
                                        ? const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                          )
                                        : null,
                                  ),
                                  style: const TextStyle(color: AppTheme.white, fontSize: 18),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an Akofa Tag';
                                    }
                                    if (value.contains(' ')) {
                                      return 'No spaces allowed in Akofa Tag';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Recipient Address or ₳Tag',
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
                        suffixIcon: _checkingTag
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                      ),
                      style: const TextStyle(color: AppTheme.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a recipient address or ₳Tag';
                        }
                        if (value.startsWith('₳')) {
                          if (value.length < 2) {
                            return 'Enter a valid Akofa Tag (e.g. ₳username)';
                          }
                          return null;
                        }
                        // Basic Stellar address validation
                        if (!value.startsWith('G') || value.length != 56) {
                          return 'Please enter a valid Stellar address or ₳Tag';
                        }
                        return null;
                      },
                    ),
              if (_promptCreateTag)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    'You must create an Akofa Tag in your profile before sending Akofa Coin. Go to your profile to set one.',
                    style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                  ),
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
        _promptCreateTag = false;
      });
      try {
        // Check if user has Akofa Tag if sending AKOFA
        if (_selectedAssetCode == 'AKOFA') {
          final hasTag = await _userHasAkofaTag();
          if (!hasTag) {
            setState(() {
              _isLoading = false;
              _promptCreateTag = true;
            });
            return;
          }
        }
        String? destinationAddress;
        if (_selectedAssetCode == 'AKOFA') {
          // Always prefix with ₳ for Akofa, but remove if user entered it
          String tagInput = _addressController.text.trim();
          if (tagInput.startsWith('₳')) {
            tagInput = tagInput.substring(1);
          }
          final fullTag = '₳$tagInput';
          destinationAddress = await _resolveAkofaTag(fullTag);
          if (destinationAddress == null) {
            setState(() {
              _isLoading = false;
              _error = 'Akofa Tag not found.';
            });
            return;
          }
        } else {
          final destinationInput = _addressController.text.trim();
          if (destinationInput.startsWith('₳')) {
            destinationAddress = await _resolveAkofaTag(destinationInput);
            if (destinationAddress == null) {
              setState(() {
                _isLoading = false;
                _error = 'Akofa Tag not found.';
              });
              return;
            }
          } else {
            destinationAddress = destinationInput;
          }
        }
        final amount = _amountController.text;
        final memo = _memoController.text.isNotEmpty ? _memoController.text : null;
        final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
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