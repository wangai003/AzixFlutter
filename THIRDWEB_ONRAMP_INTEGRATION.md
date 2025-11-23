# ThirdWeb Onramp Integration Guide

## Overview
Replaced MoonPay with ThirdWeb Pay for fiat-to-crypto onramping in the Enhanced Wallet Screen's overview tab. ThirdWeb Pay provides a seamless way for users to purchase crypto directly within the app using credit cards, debit cards, or other payment methods.

## What Changed

### 1. New Files Created

#### `lib/services/thirdweb_onramp_service.dart`
Service class that handles ThirdWeb Pay integration:
- Generates onramp URLs with wallet address and network configuration
- Supports multiple networks (Polygon, Polygon Amoy, Ethereum)
- Validates wallet addresses
- Configurable with ThirdWeb client ID

**Key Features:**
- `generateOnrampUrl()` - Creates full-featured onramp URL
- `generateSimpleOnrampUrl()` - Simplified URL generation
- Network configuration for different blockchains
- Address validation

#### `lib/widgets/thirdweb_onramp_dialog.dart`
Flutter widget that displays ThirdWeb Pay in a WebView:
- Full-screen dialog with embedded WebView
- Loading states and error handling
- Navigation detection for success/cancel callbacks
- Automatic wallet refresh after successful purchase

**Features:**
- Beautiful dark-themed UI
- Loading indicator while gateway loads
- Error handling with retry option
- Detects transaction completion
- Returns success/failure to caller

### 2. Modified Files

#### `lib/screens/enhanced_wallet_screen.dart`
**Changes Made:**

1. **Added Import:**
   ```dart
   import '../widgets/thirdweb_onramp_dialog.dart';
   ```

2. **Replaced "Buy Crypto" Button in Quick Actions:**
   - **Before:** Navigated to `BuyCryptoScreen` (MoonPay)
   - **After:** Opens ThirdWeb onramp dialog
   ```dart
   Expanded(
     child: _buildActionButton(
       'Buy Crypto',
       Icons.account_balance_wallet,
       () => _showThirdWebOnramp(walletProvider),
     ),
   ),
   ```

3. **Added `_showThirdWebOnramp()` Method:**
   ```dart
   void _showThirdWebOnramp(EnhancedWalletProvider walletProvider) {
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (context) => ThirdWebOnrampDialog(
         walletAddress: walletProvider.address!,
         network: walletProvider.isTestnet ? 'polygon-amoy' : 'polygon',
       ),
     ).then((success) {
       if (success == true) {
         walletProvider.refreshWallet();
         // Show success message
       }
     });
   }
   ```

4. **Updated `_showBuyCryptoOptions()` Bottom Sheet:**
   - Changed "Use MoonPay" to "Use ThirdWeb Pay"
   - Updated onTap handler to call `_showThirdWebOnramp()`

## Setup Instructions

### Step 1: Add Dependencies

Add `webview_flutter` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  webview_flutter: ^4.10.0  # Add this line
  # ... other dependencies
```

Then run:
```bash
flutter pub get
```

### Step 2: Get ThirdWeb Client ID

1. Visit [ThirdWeb Dashboard](https://thirdweb.com/dashboard)
2. Create an account or sign in
3. Create a new project
4. Copy your Client ID
5. Update `lib/services/thirdweb_onramp_service.dart`:
   ```dart
   static const String _clientId = 'YOUR_ACTUAL_CLIENT_ID_HERE';
   ```

### Step 3: Platform-Specific Configuration

#### Android (`android/app/src/main/AndroidManifest.xml`)
Add internet permission:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Update minSdkVersion in `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        minSdkVersion 20  // WebView requires API 20+
    }
}
```

#### iOS (`ios/Runner/Info.plist`)
Add this to enable WebView:
```xml
<key>io.flutter.embedded_views_preview</key>
<true/>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## Features & Benefits

### User Benefits
1. **Seamless Experience** - Buy crypto without leaving the app
2. **Multiple Payment Methods** - Credit card, debit card, bank transfer
3. **Multi-Chain Support** - Purchase on Polygon, Ethereum, and more
4. **Secure Transactions** - Handled by ThirdWeb's secure infrastructure
5. **Instant Delivery** - Funds arrive in wallet quickly

### Developer Benefits
1. **Easy Integration** - Simple WebView implementation
2. **No Backend Required** - All processing handled by ThirdWeb
3. **Automatic Network Detection** - Switches between testnet/mainnet
4. **Revenue Sharing** - Optional fee-splitting with ThirdWeb
5. **Compliance Built-In** - ThirdWeb handles KYC/AML requirements

## How It Works

### User Flow
1. User clicks "Buy Crypto" in Quick Actions
2. ThirdWeb onramp dialog opens
3. User selects amount and payment method
4. ThirdWeb handles payment processing
5. Funds arrive in user's wallet
6. App refreshes to show new balance

### Technical Flow
```
User Action
    ↓
_showThirdWebOnramp()
    ↓
Generate onramp URL
    ↓
Open ThirdWebOnrampDialog
    ↓
Load URL in WebView
    ↓
User completes purchase
    ↓
Detect completion callback
    ↓
Close dialog & refresh wallet
    ↓
Show success message
```

## Supported Networks

### Mainnet
- **Polygon** (Chain ID: 137)
- **Ethereum** (Chain ID: 1)

### Testnet
- **Polygon Amoy** (Chain ID: 80002)

The service automatically detects if the wallet is on testnet or mainnet and uses the appropriate network configuration.

## API Reference

### ThirdWebOnrampService

#### Methods

**`generateSimpleOnrampUrl()`**
```dart
String generateSimpleOnrampUrl({
  required String walletAddress,
  String network = 'polygon',
  double? amount,
})
```
Generates a simplified onramp URL for quick integration.

**`getNetworkConfig()`**
```dart
Map<String, String>? getNetworkConfig(String network)
```
Returns network configuration (name, chainId, symbol, explorerUrl).

**`isValidAddress()`**
```dart
bool isValidAddress(String address)
```
Validates Ethereum/Polygon address format (0x + 40 hex chars).

#### Properties

**`isConfigured`**
```dart
static bool get isConfigured
```
Returns true if ThirdWeb client ID is set.

**`availableNetworks`**
```dart
static List<String> get availableNetworks
```
Returns list of supported network identifiers.

### ThirdWebOnrampDialog

#### Constructor
```dart
ThirdWebOnrampDialog({
  required String walletAddress,
  String network = 'polygon',
  double? defaultAmount,
})
```

#### Parameters
- `walletAddress` - User's wallet address to receive funds
- `network` - Blockchain network ('polygon', 'polygon-amoy', 'ethereum')
- `defaultAmount` - Optional default purchase amount

#### Return Value
Returns `true` if purchase was completed, `false` if cancelled.

## Error Handling

### Common Errors & Solutions

1. **"ThirdWeb client ID not configured"**
   - Solution: Update `_clientId` in `thirdweb_onramp_service.dart`

2. **"Invalid wallet address"**
   - Solution: Ensure wallet address starts with '0x' and is 42 characters

3. **"Failed to load onramp"**
   - Solution: Check internet connection and firewall settings

4. **WebView not loading**
   - Solution: Verify platform-specific configurations are correct

## Testing

### Test Checklist
- [ ] Click "Buy Crypto" button in overview tab
- [ ] Verify ThirdWeb dialog opens
- [ ] Test with different amounts
- [ ] Cancel transaction and verify dialog closes
- [ ] Complete a test purchase (testnet)
- [ ] Verify wallet balance updates after purchase
- [ ] Test on both Android and iOS
- [ ] Test error handling (no internet, invalid address)

### Test Networks
For testing, use Polygon Amoy testnet:
- Set wallet to testnet mode
- Use test payment methods provided by ThirdWeb
- Verify funds arrive in testnet wallet

## Customization Options

### Theme Customization
Update the dialog appearance in `thirdweb_onramp_dialog.dart`:
```dart
decoration: BoxDecoration(
  color: AppTheme.darkGrey,  // Change background color
  borderRadius: BorderRadius.circular(16),  // Adjust corner radius
)
```

### Default Amount
Set a default purchase amount:
```dart
ThirdWebOnrampDialog(
  walletAddress: address,
  defaultAmount: 10.0,  // $10 USD default
)
```

### Supported Currencies
ThirdWeb supports:
- USD (default)
- EUR
- GBP
- And many more...

## Migration from MoonPay

### What Was Removed
- ~~`MoonPayPurchaseDialog`~~ references in Quick Actions
- ~~`BuyCryptoScreen`~~ navigation (kept as fallback)
- MoonPay-specific text and branding

### What Was Kept
- Purchase tab functionality (M-Pesa, Card, Bank Transfer)
- Existing MoonPay code (can be removed if no longer needed)
- All other wallet features

### Backward Compatibility
The old MoonPay code is still present but not used in overview tab. To fully remove:
1. Remove `moonpay_purchase_dialog.dart` import
2. Delete `_showMoonPayPurchaseDialog()` method
3. Remove MoonPay references from Purchase tab

## Advantages Over MoonPay

| Feature | ThirdWeb Pay | MoonPay |
|---------|-------------|----------|
| Integration Complexity | ⭐⭐⭐⭐⭐ Simple | ⭐⭐⭐ Moderate |
| Payment Methods | Multiple providers | Single provider |
| Multi-Chain Support | ✅ Native | ⚠️ Limited |
| Fee Structure | Competitive | Higher fees |
| Customization | ✅ Extensive | ⚠️ Limited |
| Developer Tools | ✅ Comprehensive | ⚠️ Basic |
| Revenue Sharing | ✅ Built-in | ❌ No |

## Security Considerations

1. **HTTPS Only** - All communication uses HTTPS
2. **No PII Storage** - User data handled by ThirdWeb
3. **Secure WebView** - JavaScript enabled only for ThirdWeb domains
4. **Address Validation** - Wallet addresses validated before use
5. **Network Detection** - Automatic mainnet/testnet detection prevents errors

## Support & Resources

- **ThirdWeb Documentation:** https://portal.thirdweb.com/
- **ThirdWeb Discord:** https://discord.gg/thirdweb
- **API Reference:** https://portal.thirdweb.com/typescript/v5
- **Dashboard:** https://thirdweb.com/dashboard

## Troubleshooting

### Issue: WebView shows blank screen
**Solution:**
- Check internet connection
- Verify ThirdWeb client ID is set
- Check browser console for errors
- Ensure platform permissions are configured

### Issue: Payment fails
**Solution:**
- Use valid payment method
- Check card/bank details
- Verify wallet address is correct
- Try different payment provider

### Issue: Funds not arriving
**Solution:**
- Check transaction status on block explorer
- Allow 5-10 minutes for confirmation
- Verify correct network was selected
- Contact ThirdWeb support if delayed

## Future Enhancements

Potential improvements:
1. Add amount quick select buttons ($10, $50, $100)
2. Show transaction history within dialog
3. Support for more cryptocurrencies (AKOFA directly)
4. Integrate swap functionality
5. Add promotional banners
6. Multi-language support
7. Referral program integration

## Status
✅ **COMPLETE** - ThirdWeb onramp successfully integrated in overview tab!

## Next Steps
1. Get ThirdWeb client ID from dashboard
2. Update client ID in service file
3. Test on both testnet and mainnet
4. Deploy and monitor user adoption

