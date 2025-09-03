class FlutterwaveConfig {
  // Replace these with your actual Flutterwave sandbox credentials
  static const String clientId = '27060896-057c-4e7a-81cd-7e698488542d';
  static const String clientSecret = '93NnFs1K80dNU23dyiaQVsYT1Vespsbe';
  static const String encryptionKey = 'pIFZvRe91/QmfLcxHgfeMHBfE2jIo9gXrwdSGH2RVDM=';
  
  // Environment configuration
  static const bool isTestMode = true; // Set to false for production
  
  // Default country for mobile money payments
  static const String defaultCountry = 'KE'; // Kenya for M-Pesa
  
  // Default currency
  static const String defaultCurrency = 'USD';
  
  // Company information
  static const String companyName = 'AZIX';
  static const String companyLogo = 'https://your-logo-url.com/logo.png';
  
  // Payment limits
  static const Map<String, Map<String, double>> paymentLimits = {
    'mpesa': {'min': 1.0, 'max': 1000.0},
    'card': {'min': 1.0, 'max': 5000.0},
    'bank': {'min': 10.0, 'max': 10000.0},
    'ussd': {'min': 1.0, 'max': 500.0},
    'qr': {'min': 1.0, 'max': 1000.0},
  };
  
  // Akofa coin exchange rate
  static const double akofaRate = 0.06; // 1 Akofa = $0.06
  
  // Transaction fee percentage (if applicable)
  static const double transactionFee = 0.0; // 0% fee
  
  // Minimum transaction amount
  static const double minTransactionAmount = 1.0;
  
  // Maximum transaction amount
  static const double maxTransactionAmount = 10000.0;
}
