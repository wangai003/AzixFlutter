// WARNING: Never commit this file to version control or use in production!
// This is for testnet/demo only.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Secrets {
  static String get akofaIssuerSecret => dotenv.env['AKOFA_ISSUER_SECRET'] ?? '';
  static String get usdcIssuerSecret => dotenv.env['USDC_ISSUER_SECRET'] ?? '';
  static String get btcIssuerSecret => dotenv.env['BTC_ISSUER_SECRET'] ?? '';
  static String get ethIssuerSecret => dotenv.env['ETH_ISSUER_SECRET'] ?? '';

  static Map<String, String> get assetIssuerSecrets => {
    'AKOFA': akofaIssuerSecret,
    'USDC': usdcIssuerSecret,
    'BTC': btcIssuerSecret,
    'ETH': ethIssuerSecret,
    // Add more as needed
  };
} 