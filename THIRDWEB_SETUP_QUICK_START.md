# ThirdWeb Onramp - Quick Start Guide

## ✅ What's Been Done

MoonPay has been replaced with ThirdWeb Pay in the Enhanced Wallet overview tab:

✅ Created `ThirdWebOnrampService` - handles URL generation and configuration  
✅ Created `ThirdWebOnrampDialog` - beautiful WebView dialog for purchases  
✅ Updated "Buy Crypto" button in Quick Actions to use ThirdWeb  
✅ Updated gas fee top-up dialog to use ThirdWeb  
✅ Added automatic network detection (testnet/mainnet)  
✅ No compilation errors  

## 🚀 Quick Setup (5 Minutes)

### Step 1: Get Your ThirdWeb Client ID

1. Visit **https://thirdweb.com/dashboard**
2. Sign in or create an account (free)
3. Click "Create Project" or "New Project"
4. Copy your **Client ID** (starts with your project name)

### Step 2: Update the Client ID

Open `lib/services/thirdweb_onramp_service.dart` and update line 7:

**Before:**
```dart
static const String _clientId = 'YOUR_THIRDWEB_CLIENT_ID';
```

**After:**
```dart
static const String _clientId = 'abc123def456...'; // Your actual client ID
```

### Step 3: Test It!

1. Run your app: `flutter run`
2. Navigate to Enhanced Wallet
3. Click "Buy Crypto" in Quick Actions
4. You should see ThirdWeb Pay dialog open!

## 📱 Dependencies

Good news! The required `webview_flutter` package is already in your `pubspec.yaml`:

```yaml
webview_flutter: ^4.7.0  ✅ Already installed
webview_flutter_web: ^0.2.2  ✅ Already installed
```

No need to add anything!

## 🎨 What Users See

### Before (MoonPay)
```
┌─────────────────────┐
│ Quick Actions       │
├─────────────────────┤
│ [Send] [Receive]    │
│ [Buy Crypto - Old]  │  ← Went to MoonPay
└─────────────────────┘
```

### After (ThirdWeb)
```
┌─────────────────────┐
│ Quick Actions       │
├─────────────────────┤
│ [Send] [Receive]    │
│ [Buy Crypto - New]  │  ← Opens ThirdWeb
└─────────────────────┘

Opens beautiful dialog:
┌────────────────────────────┐
│ 💳 Buy Crypto              │
│ Powered by ThirdWeb        │
├────────────────────────────┤
│                            │
│  [ThirdWeb Pay Interface]  │
│  - Enter amount            │
│  - Select payment method   │
│  - Complete purchase       │
│                            │
└────────────────────────────┘
```

## 🌐 Network Support

| Network | Chain ID | Status |
|---------|----------|--------|
| Polygon Mainnet | 137 | ✅ Supported |
| Polygon Amoy Testnet | 80002 | ✅ Supported |
| Ethereum Mainnet | 1 | ✅ Supported |

The app automatically detects which network your wallet is on!

## 🔧 Configuration Options

### Change Default Amount

Edit `enhanced_wallet_screen.dart` line ~1607:

```dart
ThirdWebOnrampDialog(
  walletAddress: walletProvider.address!,
  network: walletProvider.isTestnet ? 'polygon-amoy' : 'polygon',
  defaultAmount: 20.0,  // ← Add this line (default $20)
)
```

### Add More Networks

Edit `lib/services/thirdweb_onramp_service.dart`:

```dart
static const Map<String, Map<String, String>> supportedNetworks = {
  'polygon': { ... },
  'ethereum': { ... },
  'binance': {  // Add new network
    'name': 'BNB Smart Chain',
    'chainId': '56',
    'symbol': 'BNB',
    'explorerUrl': 'https://bscscan.com',
  },
};
```

## 🎯 Features Available to Users

1. **Multiple Payment Methods:**
   - Credit/Debit Cards (Visa, Mastercard, etc.)
   - Bank Transfers
   - Apple Pay / Google Pay
   - Crypto-to-Crypto swaps

2. **Supported Regions:**
   - 160+ countries worldwide
   - Automatic currency conversion
   - Local payment methods

3. **Purchase Amounts:**
   - Minimum: Usually $20 USD
   - Maximum: Varies by payment method
   - Instant delivery to wallet

## 🔒 Security Features

✅ All transactions secured by ThirdWeb  
✅ KYC/AML compliance built-in  
✅ No sensitive data stored in your app  
✅ HTTPS-only communication  
✅ Wallet address validation  

## 💡 Pro Tips

### For Development (Testnet):
```dart
// Your wallet will automatically use Amoy testnet if set to testnet mode
// ThirdWeb provides test mode for development
```

### For Production (Mainnet):
```dart
// Switch wallet to mainnet before deploying
// Real payments will be processed
// Users will receive actual MATIC/ETH
```

### Testing Without Real Money:
1. Use Polygon Amoy testnet
2. Get test MATIC from faucet
3. ThirdWeb's test mode works on testnet
4. No real money needed for testing!

## 📊 Monitoring & Analytics

ThirdWeb Dashboard provides:
- Transaction volume
- Success rates
- Popular payment methods
- Revenue analytics
- User demographics

Access at: **https://thirdweb.com/dashboard**

## 🆘 Common Issues & Fixes

### Issue: "ThirdWeb client ID not configured"
**Fix:** Update `_clientId` in `thirdweb_onramp_service.dart`

### Issue: Dialog shows blank screen
**Fix:** 
1. Check internet connection
2. Verify client ID is correct
3. Ensure `webview_flutter` is installed

### Issue: "Invalid wallet address"
**Fix:** 
- Wallet must be created first
- Address must start with `0x`
- Address must be 42 characters long

### Issue: Payment fails
**Fix:**
- Use valid payment method
- Check card details
- Try different payment provider in ThirdWeb
- Check transaction limits

## 📈 Advantages Over MoonPay

| Feature | ThirdWeb | MoonPay |
|---------|----------|---------|
| Setup Time | 5 min | 30+ min |
| Integration | WebView | Complex SDK |
| Payment Options | Multiple | Single |
| Multi-Chain | Native | Limited |
| Fees | Lower | Higher |
| Customization | High | Low |
| Revenue Share | Yes | No |

## 🎉 Success Checklist

- [ ] Got ThirdWeb client ID
- [ ] Updated client ID in code
- [ ] Tested on testnet
- [ ] Tested on mainnet
- [ ] Verified wallet refresh after purchase
- [ ] Tested error handling
- [ ] Deployed to users

## 🚀 Next Steps After Setup

1. **Customize Branding**
   - Update dialog colors/theme
   - Add your logo
   - Customize success messages

2. **Add Quick Amount Buttons**
   ```dart
   // Add buttons for $10, $50, $100, etc.
   Row(
     children: [
       QuickAmountButton(amount: 10),
       QuickAmountButton(amount: 50),
       QuickAmountButton(amount: 100),
     ],
   )
   ```

3. **Track Conversions**
   - Monitor how many users buy crypto
   - Track average purchase amounts
   - Analyze user behavior

4. **Promote the Feature**
   - Add tutorial/walkthrough
   - Show in onboarding
   - Add tooltip on first visit

## 📞 Support

- **ThirdWeb Docs:** https://portal.thirdweb.com/
- **ThirdWeb Discord:** https://discord.gg/thirdweb
- **Email Support:** support@thirdweb.com

## 🎓 Video Tutorial

Want to see it in action? Check ThirdWeb's official video guides:
- https://www.youtube.com/c/thirdweb

---

## Ready to Go! 🚀

Your app now has world-class onramp functionality powered by ThirdWeb!

Just add your client ID and you're ready to let users buy crypto! 💳✨

