import 'lib/services/stellar_service.dart';

void main() {
  print('🔍 Testing Stellar Configuration...');

  final result = StellarService.testStellarConfiguration();

  print('\n📊 Stellar Configuration Test Results:');
  for (final msg in result['messages']) {
    print(msg);
  }

  print('\n📈 Summary:');
  print('  Issuer Secret Valid: ${result['issuerSecretValid']}');
  print('  Issuer Account Valid: ${result['issuerAccountValid']}');
  print('  Asset Code Valid: ${result['akofaAssetCodeValid']}');
  print('  Overall Valid: ${result['overallValid']}');

  if (!result['overallValid']) {
    print('\n⚠️  Configuration issues detected. Please check the Stellar constants.');
  } else {
    print('\n✅ Stellar configuration is valid!');
  }
}
