import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/marketplace_theme.dart';
import '../services/payment_service.dart';

/// Comprehensive payment processing screen
class PaymentScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final String customerId;
  final String vendorId;
  final Function(PaymentResult)? onPaymentComplete;
  
  const PaymentScreen({
    Key? key,
    required this.orderId,
    required this.amount,
    required this.customerId,
    required this.vendorId,
    this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  PaymentMethod _selectedMethod = PaymentMethod.akofa;
  bool _isProcessing = false;
  
  // Form controllers
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _referenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      _selectedMethod = PaymentMethod.values[_tabController.index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildPaymentSummary(),
          _buildPaymentMethods(),
          Expanded(child: _buildPaymentForm()),
          _buildPaymentButton(),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MarketplaceTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.payment,
              color: MarketplaceTheme.primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '₳${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: MarketplaceTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: MarketplaceTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.security,
                  color: MarketplaceTheme.success,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Secure',
                  style: TextStyle(
                    color: MarketplaceTheme.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: MarketplaceTheme.primaryBlue,
        unselectedLabelColor: MarketplaceTheme.gray500,
        indicatorColor: MarketplaceTheme.primaryBlue,
        tabs: [
          _buildMethodTab('AKOFA', Icons.account_balance_wallet, const Color(0xFFFFD700)),
          _buildMethodTab('M-Pesa', Icons.phone_android, Colors.green),
          _buildMethodTab('Card', Icons.credit_card, Colors.blue),
          _buildMethodTab('PayPal', Icons.payment, Colors.indigo),
          _buildMethodTab('Bank', Icons.account_balance, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMethodTab(String title, IconData icon, Color color) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAkofaForm(),
        _buildMpesaForm(),
        _buildCreditCardForm(),
        _buildPaypalForm(),
        _buildBankTransferForm(),
      ],
    );
  }

  Widget _buildAkofaForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormHeader(
            'AKOFA Wallet Payment',
            'Pay with your AKOFA tokens securely on the Stellar network',
            Icons.account_balance_wallet,
            const Color(0xFFFFD700),
          ),
          
          const SizedBox(height: 24),
          
          _buildInfoCard(
            'Transaction Details',
            [
              'Payment will be processed instantly',
              'Transaction fees: 0.00001 XLM (~\$0.001)',
              'Your AKOFA balance will be checked before processing',
              'Transaction is recorded on Stellar blockchain',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMpesaForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormHeader(
            'M-Pesa Payment',
            'Pay with your M-Pesa mobile money account',
            Icons.phone_android,
            Colors.green,
          ),
          
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'M-Pesa Phone Number',
              hintText: '254712345678',
              prefixText: '+',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'How it works',
            [
              'Enter your M-Pesa registered phone number',
              'You\'ll receive an STK push notification',
              'Enter your M-Pesa PIN to complete payment',
              'Confirmation will be sent via SMS',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormHeader(
            'Credit/Debit Card',
            'Pay securely with your credit or debit card',
            Icons.credit_card,
            Colors.blue,
          ),
          
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _cardHolderController,
            decoration: const InputDecoration(
              labelText: 'Card Holder Name',
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _cardNumberController,
            decoration: const InputDecoration(
              labelText: 'Card Number',
              hintText: '1234 5678 9012 3456',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  decoration: const InputDecoration(
                    labelText: 'MM/YY',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ExpiryDateFormatter(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  obscureText: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaypalForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormHeader(
            'PayPal Payment',
            'Pay with your PayPal account',
            Icons.payment,
            Colors.indigo,
          ),
          
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'PayPal Email',
              hintText: 'your.email@example.com',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'PayPal Payment Process',
            [
              'You\'ll be redirected to PayPal to complete payment',
              'Log in to your PayPal account',
              'Confirm the payment amount',
              'Return to the app after successful payment',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankTransferForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormHeader(
            'Bank Transfer',
            'Pay via direct bank transfer',
            Icons.account_balance,
            Colors.grey,
          ),
          
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _bankNameController,
            decoration: const InputDecoration(
              labelText: 'Bank Name',
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _accountNumberController,
            decoration: const InputDecoration(
              labelText: 'Account Number',
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _referenceController,
            decoration: const InputDecoration(
              labelText: 'Reference Number (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Bank Transfer Instructions',
            [
              'Manual verification required (1-3 business days)',
              'Include order ID in transfer description',
              'Upload transfer receipt for faster processing',
              'Order will be processed after payment confirmation',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormHeader(String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: MarketplaceTheme.gray600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<String> points) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MarketplaceTheme.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MarketplaceTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MarketplaceTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      color: MarketplaceTheme.gray600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPaymentButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketplaceTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Pay ₳${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_validatePaymentData()) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final paymentData = _getPaymentData();
      
      final result = await PaymentService.processPayment(
        orderId: widget.orderId,
        amount: widget.amount,
        paymentMethod: _selectedMethod,
        customerId: widget.customerId,
        vendorId: widget.vendorId,
        paymentData: paymentData,
      );
      
      if (result.status == PaymentStatus.completed) {
        _showSuccessDialog(result);
      } else if (result.status == PaymentStatus.pending) {
        _showPendingDialog(result);
      } else {
        _showErrorDialog(result.errorMessage ?? 'Payment failed');
      }
      
      widget.onPaymentComplete?.call(result);
      
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  bool _validatePaymentData() {
    switch (_selectedMethod) {
      case PaymentMethod.mpesa:
        if (_phoneController.text.trim().isEmpty) {
          _showErrorDialog('Please enter your M-Pesa phone number');
          return false;
        }
        break;
      case PaymentMethod.creditCard:
        if (_cardNumberController.text.trim().isEmpty ||
            _expiryController.text.trim().isEmpty ||
            _cvvController.text.trim().isEmpty ||
            _cardHolderController.text.trim().isEmpty) {
          _showErrorDialog('Please fill in all card details');
          return false;
        }
        break;
      case PaymentMethod.paypal:
        if (_emailController.text.trim().isEmpty) {
          _showErrorDialog('Please enter your PayPal email');
          return false;
        }
        break;
      case PaymentMethod.bankTransfer:
        if (_bankNameController.text.trim().isEmpty ||
            _accountNumberController.text.trim().isEmpty) {
          _showErrorDialog('Please fill in bank details');
          return false;
        }
        break;
      default:
        break;
    }
    return true;
  }

  Map<String, dynamic> _getPaymentData() {
    switch (_selectedMethod) {
      case PaymentMethod.mpesa:
        return {'phoneNumber': _phoneController.text.trim()};
      case PaymentMethod.creditCard:
        return {
          'cardNumber': _cardNumberController.text.trim(),
          'expiryDate': _expiryController.text.trim(),
          'cvv': _cvvController.text.trim(),
          'cardHolder': _cardHolderController.text.trim(),
        };
      case PaymentMethod.paypal:
        return {'email': _emailController.text.trim()};
      case PaymentMethod.bankTransfer:
        return {
          'bankName': _bankNameController.text.trim(),
          'accountNumber': _accountNumberController.text.trim(),
          'referenceNumber': _referenceController.text.trim(),
        };
      default:
        return {};
    }
  }

  void _showSuccessDialog(PaymentResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: MarketplaceTheme.success),
            SizedBox(width: 8),
            Text('Payment Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your payment of ₳${widget.amount.toStringAsFixed(2)} has been processed successfully.'),
            const SizedBox(height: 16),
            Text('Transaction ID: ${result.transactionId}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showPendingDialog(PaymentResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.schedule, color: MarketplaceTheme.warning),
            SizedBox(width: 8),
            Text('Payment Pending'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your payment is being processed. You will receive a notification once confirmed.'),
            const SizedBox(height: 16),
            Text('Reference: ${result.transactionId}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: MarketplaceTheme.error),
            SizedBox(width: 8),
            Text('Payment Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Card number formatter
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Expiry date formatter
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length && i < 4; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
