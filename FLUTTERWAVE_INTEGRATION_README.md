# Flutterwave Integration for Akofa Onramp System

## Overview

This document describes the implementation of a custom Akofa onramp system using Flutterwave for payment processing. The system allows users to purchase Akofa coins using various payment methods including M-Pesa, credit/debit cards, bank transfers, USSD, and QR codes.

## Features

- **Multiple Payment Methods**: Support for M-Pesa, cards, bank transfers, USSD, and QR payments
- **Real-time Exchange Rate**: 1 Akofa = $0.06 USD
- **Secure Payment Processing**: Integration with Flutterwave's secure payment infrastructure
- **Transaction Recording**: All purchases are recorded as "Buy Akofa" transactions
- **User Wallet Integration**: Purchased coins are automatically credited to user's Stellar wallet
- **Responsive UI**: Modern, user-friendly interface for both mobile and desktop

## Architecture

### Components

1. **FlutterwaveService** (`lib/services/flutterwave_service.dart`)
   - Handles payment processing and verification
   - Manages transaction recording
   - Provides payment method validation

2. **EnhancedBuyAkofaDialog** (`lib/widgets/enhanced_buy_akofa_dialog.dart`)
   - User interface for payment selection and processing
   - Payment method selection grid
   - Amount input with real-time Akofa preview
   - User details collection

3. **FlutterwaveConfig** (`lib/config/flutterwave_config.dart`)
   - Configuration for API keys and settings
   - Payment limits and exchange rates
   - Environment settings

4. **Transaction Model** (`lib/models/transaction.dart`)
   - Enhanced to support "Buy Akofa" transaction type
   - Metadata storage for payment details
   - Firestore integration

## Setup Instructions

### 1. Install Dependencies

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  flutterwave_standard: ^1.0.7
```

### 2. Configure Flutterwave API Keys

Update `lib/config/flutterwave_config.dart` with your actual Flutterwave credentials:

```dart
class FlutterwaveConfig {
  // Replace with your actual Flutterwave API keys
  static const String publicKey = 'FLWPUBK_TEST-your-actual-public-key';
  static const String secretKey = 'FLWSECK_TEST-your-actual-secret-key';
  
  // Set to false for production
  static const bool isTestMode = true;
}
```

### 3. Environment Configuration

- **Test Mode**: Use Flutterwave test keys for development
- **Production Mode**: Use live keys and set `isTestMode = false`

### 4. Payment Method Configuration

Configure payment limits for each method in `FlutterwaveConfig`:

```dart
static const Map<String, Map<String, double>> paymentLimits = {
  'mpesa': {'min': 1.0, 'max': 1000.0},
  'card': {'min': 1.0, 'max': 5000.0},
  'bank': {'min': 10.0, 'max': 10000.0},
  'ussd': {'min': 1.0, 'max': 500.0},
  'qr': {'min': 1.0, 'max': 1000.0},
};
```

## Usage

### 1. User Flow

1. User clicks "Buy Akofa" button in wallet
2. Payment method selection dialog appears
3. User selects payment method and enters amount
4. User provides payment details (name, email, phone)
5. Payment is processed through Flutterwave
6. On success, Akofa coins are credited to user's wallet
7. Transaction is recorded in Firestore

### 2. Integration Points

#### Wallet Screen
The "Buy Akofa" button is integrated into the wallet screen through the `QuickActionsRow` widget.

#### Payment Processing
```dart
final result = await FlutterwaveService.initiatePayment(
  context: context,
  amountInUSD: amount,
  paymentMethod: selectedMethod,
  phoneNumber: phoneNumber,
  email: email,
  name: name,
);
```

#### Transaction Recording
All successful purchases are recorded with:
- Transaction type: "Buy Akofa"
- Payment method details
- USD amount and Akofa coins received
- Flutterwave reference number

## Payment Methods

### M-Pesa
- **Country**: Kenya
- **Limits**: $1 - $1,000
- **Description**: Mobile money payment via M-Pesa

### Credit/Debit Cards
- **Limits**: $1 - $5,000
- **Description**: Visa, Mastercard, and other major cards

### Bank Transfer
- **Limits**: $10 - $10,000
- **Description**: Direct bank transfer

### USSD
- **Limits**: $1 - $500
- **Description**: USSD banking payment

### QR Code
- **Limits**: $1 - $1,000
- **Description**: Scan QR code to pay

## Security Features

1. **Payment Verification**: All payments are verified before crediting coins
2. **Transaction Recording**: Complete audit trail of all purchases
3. **User Authentication**: Only authenticated users can make purchases
4. **Amount Validation**: Payment limits enforced for each method
5. **Secure Storage**: Sensitive data handled securely

## Error Handling

The system handles various error scenarios:
- Invalid payment amounts
- Payment method restrictions
- Network failures
- User authentication issues
- Payment verification failures

## Testing

### Test Mode
- Use Flutterwave test keys
- Simulated payment processing
- Test transaction recording
- UI/UX validation

### Production Mode
- Live Flutterwave integration
- Real payment processing
- Production transaction recording
- Performance monitoring

## Monitoring and Analytics

### Transaction Tracking
- All purchases logged in Firestore
- User transaction history
- Payment method analytics
- Success/failure rates

### Performance Metrics
- Payment processing time
- Success rates by payment method
- User conversion rates
- Error frequency

## Troubleshooting

### Common Issues

1. **Payment Failed**
   - Check Flutterwave API keys
   - Verify payment method configuration
   - Check network connectivity

2. **Coins Not Credited**
   - Verify payment verification
   - Check Stellar wallet integration
   - Review transaction logs

3. **UI Not Loading**
   - Check Flutterwave package installation
   - Verify widget imports
   - Check for build errors

### Debug Mode

Enable debug logging in the Flutterwave service for detailed error information.

## Future Enhancements

1. **Additional Payment Methods**
   - Apple Pay
   - Google Pay
   - PayPal integration

2. **Advanced Features**
   - Recurring purchases
   - Bulk purchase discounts
   - Referral rewards

3. **Analytics Dashboard**
   - Real-time transaction monitoring
   - Payment method performance
   - User behavior analytics

## Support

For technical support or questions about the Flutterwave integration:

1. Check Flutterwave documentation
2. Review error logs
3. Test with Flutterwave test environment
4. Contact development team

## License

This integration is part of the AZIX Flutter application and follows the project's licensing terms.
