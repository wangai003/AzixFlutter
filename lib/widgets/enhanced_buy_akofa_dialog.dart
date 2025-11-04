import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class EnhancedBuyAkofaDialog extends StatefulWidget {
  const EnhancedBuyAkofaDialog({Key? key}) : super(key: key);

  @override
  State<EnhancedBuyAkofaDialog> createState() => _EnhancedBuyAkofaDialogState();
}

class _EnhancedBuyAkofaDialogState extends State<EnhancedBuyAkofaDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  String _selectedPaymentMethod = 'all';

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  void _initializeUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _emailController.text = authProvider.user!.email ?? '';
      _nameController.text = authProvider.user!.displayName ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.black,
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        child: _successMessage != null
            ? _buildSuccessView()
            : _buildPaymentForm(),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Successful!',
            style: AppTheme.headingMedium.copyWith(
              color: Colors.green,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _successMessage!,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.monetization_on,
                    color: AppTheme.primaryGold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buy Akofa Coins',
                        style: AppTheme.headingMedium.copyWith(
                          color: AppTheme.primaryGold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'Exchange Rate: 1 Akofa = \$0.06',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Payment Method Selection
            Text(
              'Choose Payment Method',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentMethodGrid(),
            const SizedBox(height: 24),

            // Amount Input
            Text(
              'Amount (USD)',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter amount in USD',
                hintStyle: TextStyle(color: AppTheme.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGold),
                ),
                filled: true,
                fillColor: AppTheme.darkGrey.withOpacity(0.3),
                prefixIcon: const Icon(
                  Icons.attach_money,
                  color: AppTheme.primaryGold,
                ),
              ),
              style: const TextStyle(color: AppTheme.white, fontSize: 16),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Akofa Preview
            if (_amountController.text.isNotEmpty) _buildAkofaPreview(),

            const SizedBox(height: 24),

            // User Details
            _buildUserDetailsSection(),
            const SizedBox(height: 24),

            // Error Message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Buy Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: AppTheme.grey.withOpacity(0.3),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.black,
                          ),
                        ),
                      )
                    : const Text(
                        'Buy Akofa Coins',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodGrid() {
    // Payment methods removed - Flutterwave integration no longer available
    final paymentMethods = [];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: paymentMethods.length,
      itemBuilder: (context, index) {
        final method = paymentMethods[index];
        final isSelected = _selectedPaymentMethod == method['id'];

        return GestureDetector(
          onTap: () => setState(() => _selectedPaymentMethod = method['id']),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? method['color'].withOpacity(0.2)
                  : AppTheme.darkGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? method['color']
                    : AppTheme.grey.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    method['icon'],
                    color: isSelected ? method['color'] : AppTheme.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          method['name'],
                          style: TextStyle(
                            color: isSelected
                                ? method['color']
                                : AppTheme.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '\$${method['minAmount'].toStringAsFixed(0)} - \$${method['maxAmount'].toStringAsFixed(0)}',
                          style: TextStyle(
                            color: isSelected ? method['color'] : AppTheme.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAkofaPreview() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final akofaCoins = amount / 0.06; // Fixed exchange rate

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'You will receive:',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          Text(
            '${akofaCoins.toStringAsFixed(2)} AKOFA',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Details',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Name
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            labelStyle: TextStyle(color: AppTheme.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryGold),
            ),
            filled: true,
            fillColor: AppTheme.darkGrey.withOpacity(0.3),
            prefixIcon: const Icon(Icons.person, color: AppTheme.grey),
          ),
          style: const TextStyle(color: AppTheme.white),
        ),
        const SizedBox(height: 16),

        // Email
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email Address',
            labelStyle: TextStyle(color: AppTheme.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryGold),
            ),
            filled: true,
            fillColor: AppTheme.darkGrey.withOpacity(0.3),
            prefixIcon: const Icon(Icons.email, color: AppTheme.grey),
          ),
          style: const TextStyle(color: AppTheme.white),
        ),
        const SizedBox(height: 16),

        // Phone
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            labelStyle: TextStyle(color: AppTheme.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryGold),
            ),
            filled: true,
            fillColor: AppTheme.darkGrey.withOpacity(0.3),
            prefixIcon: const Icon(Icons.phone, color: AppTheme.grey),
          ),
          style: const TextStyle(color: AppTheme.white),
        ),
      ],
    );
  }

  Future<void> _processPayment() async {
    // Validate inputs
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Payment processing removed - Flutterwave integration no longer available
      setState(() {
        _error =
            'Payment processing is currently unavailable - Flutterwave integration removed';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Payment failed: $e';
        _isLoading = false;
      });
    }
  }

  bool _validateInputs() {
    if (_amountController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return false;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return false;
    }

    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your full name');
      return false;
    }

    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email address');
      return false;
    }

    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return false;
    }

    // Payment method validation removed - Flutterwave integration no longer available

    setState(() => _error = null);
    return true;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
