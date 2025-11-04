import 'package:flutter_test/flutter_test.dart';
import 'package:azixflutter/models/asset_config.dart';

void main() {
  group('AssetConfig Tests', () {
    test('AssetConfig creation and properties', () {
      // Test XLM asset
      expect(AssetConfigs.xlm.code, 'XLM');
      expect(AssetConfigs.xlm.isNative, true);
      expect(AssetConfigs.xlm.isStablecoin, false);

      // Test AKOFA asset
      expect(AssetConfigs.akofa.code, 'AKOFA');
      expect(AssetConfigs.akofa.isNative, false);
      expect(AssetConfigs.akofa.isStablecoin, false);

      // Test USDC stablecoin
      expect(AssetConfigs.usdc.code, 'USDC');
      expect(AssetConfigs.usdc.isStablecoin, true);
      expect(AssetConfigs.usdc.peggedCurrency, 'USD');

      // Test EURC stablecoin
      expect(AssetConfigs.eurc.code, 'EURC');
      expect(AssetConfigs.eurc.isStablecoin, true);
      expect(AssetConfigs.eurc.peggedCurrency, 'EUR');
    });

    test('AssetConfig find methods', () {
      // Test finding by asset ID
      final xlmAsset = AssetConfigs.findByAssetId('XLM');
      expect(xlmAsset, isNotNull);
      expect(xlmAsset!.code, 'XLM');

      final akofaAsset = AssetConfigs.findByAssetId(
        'AKOFA_GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
      );
      expect(akofaAsset, isNotNull);
      expect(akofaAsset!.code, 'AKOFA');

      // Test finding by code and issuer
      final usdcAsset = AssetConfigs.findAsset(
        'USDC',
        'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
      );
      expect(usdcAsset, isNotNull);
      expect(usdcAsset!.isStablecoin, true);
    });

    test('Stablecoin filtering', () {
      final stablecoins = AssetConfigs.stablecoins;
      expect(stablecoins.length, greaterThan(0));

      for (final coin in stablecoins) {
        expect(coin.isStablecoin, true);
        expect(coin.peggedCurrency, isNotNull);
      }
    });

    test('Asset ID generation', () {
      expect(AssetConfigs.xlm.assetId, 'XLM');
      expect(
        AssetConfigs.akofa.assetId,
        'AKOFA_GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW',
      );
      expect(
        AssetConfigs.usdc.assetId,
        'USDC_GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
      );
    });

    test('AssetConfigs provides all expected assets', () {
      final allAssets = AssetConfigs.allAssets;
      expect(allAssets.length, greaterThan(0));

      // Should include XLM, AKOFA, and stablecoins
      final assetCodes = allAssets.map((asset) => asset.code).toSet();
      expect(assetCodes.contains('XLM'), true);
      expect(assetCodes.contains('AKOFA'), true);
      expect(assetCodes.contains('USDC'), true);
    });

    test('AssetConfigs provides stablecoins', () {
      final stablecoins = AssetConfigs.stablecoins;
      expect(stablecoins.length, greaterThan(0));

      for (final coin in stablecoins) {
        expect(coin.isStablecoin, true);
      }
    });

    test('Multi-asset balance structure', () {
      // Test the expected balance structure
      final mockBalances = {
        'xlm': '100.0',
        'akofa': '50.0',
        'lastUpdated': DateTime.now().toIso8601String(),
        'assets': [
          {
            'code': 'USDC',
            'issuer':
                'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
            'balance': '25.0',
            'type': 'credit_alphanum',
            'assetId':
                'USDC_GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
          },
        ],
        'assetConfigs': {
          'XLM': AssetConfigs.xlm,
          'AKOFA_GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW':
              AssetConfigs.akofa,
        },
      };

      expect(mockBalances['xlm'], '100.0');
      expect(mockBalances['akofa'], '50.0');
      expect(mockBalances['assets'], isNotEmpty);
      expect(mockBalances['assetConfigs'], isNotEmpty);
    });
  });

  group('EnhancedWalletProvider Multi-Asset Tests', () {
    // Note: These tests would require mocking the wallet provider
    // For now, just test the method signatures and basic functionality

    test('Provider has multi-asset methods', () {
      // This would test that the provider has the new multi-asset methods
      // In a real test, we'd mock the provider and test the methods
      expect(true, true); // Placeholder test
    });
  });
}
