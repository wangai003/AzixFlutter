# Gasless Transactions - Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Step 1: Get Your Biconomy API Key (2 minutes)

1. Visit https://dashboard.biconomy.io
2. Sign up / Login
3. Click "Register New DApp"
4. Fill in:
   - Name: `AzixFlutter`
   - Network: `Polygon Amoy Testnet (80002)`
5. Copy your API Key

### Step 2: Configure Your App (1 minute)

Open `lib/services/biconomy_service.dart` and update line 7:

```dart
static const String _biconomyApiKey = 'PASTE_YOUR_API_KEY_HERE';
```

### Step 3: Register Your Token (2 minutes)

1. In Biconomy Dashboard, go to "Meta Transaction"
2. Click "Add Contract"
3. Enter:
   - Contract Address: Your AKOFA token address
   - Contract Type: ERC-20
   - Select function: `transfer(address,uint256)`
4. Click "Add"

### Step 4: Fund Your Gas Tank (1 minute)

1. Go to "Gas Tank" in dashboard
2. Copy your gas tank address
3. Get testnet MATIC from: https://faucet.polygon.technology/
4. Send 5 MATIC to your gas tank address

### Step 5: Test It! ✨

1. Run your app
2. Create/use a wallet with 0 MATIC
3. Receive some AKOFA tokens
4. Try to send AKOFA
5. You'll see: **"Send for FREE"** button
6. Click it - transaction completes without MATIC! 🎉

## 🧪 Quick Test Script

```dart
// Test gasless transaction
final result = await walletProvider.sendAsset(
  recipientAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  asset: akofaAsset,
  amount: 10.0,
  password: 'your_password',
  forceGasless: true, // Force gasless
);

if (result['success']) {
  print('✅ Gasless transaction successful!');
  print('Transaction: ${result['txHash']}');
}
```

## 📊 Verify It Works

### In Your App:
- Look for blue "⚡ Use Gasless Transaction" dialog
- Transaction should show "FREE ✨" indicator
- Success message: "sent for FREE ✨"

### In Biconomy Dashboard:
- Go to "Analytics"
- You should see your transaction
- Gas tank balance should decrease

## ⚠️ Important Notes

### Gasless Works For:
✅ ERC-20 tokens (AKOFA, USDC, etc.)
✅ When user has 0 or low MATIC
✅ Token transfers only

### Gasless Does NOT Work For:
❌ Native MATIC transfers (need gas to move MATIC)
❌ Contract interactions (except registered functions)
❌ NFT mints (unless specifically registered)

## 🔍 Troubleshooting

### "Biconomy API key invalid"
→ Check you copied the full API key (starts with `pk_`)

### "Token not whitelisted"
→ Make sure you registered the token in Biconomy dashboard

### "Gas tank empty"
→ Add more MATIC to your gas tank

### Transaction fails silently
→ Check Biconomy dashboard logs for details

## 💰 Cost Estimates

**Per transaction cost**: ~$0.001-0.002
**1000 transactions**: ~$1-2
**Recommended gas tank**: Start with 10 MATIC

## 📚 Full Documentation

For detailed setup, security, and production deployment:
- **Setup Guide**: `BICONOMY_SETUP_GUIDE.md`
- **Implementation Details**: `GASLESS_IMPLEMENTATION.md`
- **Biconomy Docs**: https://docs.biconomy.io

## 🎯 Production Checklist

Before going live:

- [ ] Replace API key with production key
- [ ] Switch from Amoy to Polygon Mainnet
- [ ] Update `_chainId` to 137
- [ ] Register contracts on mainnet
- [ ] Fund mainnet gas tank
- [ ] Set transaction limits
- [ ] Enable monitoring/alerts
- [ ] Test with real users

## 🆘 Need Help?

- **Biconomy Discord**: https://discord.gg/biconomy
- **Documentation**: https://docs.biconomy.io
- **Support**: https://t.me/biconomy

---

**That's it!** Your users can now send tokens without MATIC. 🎉

Questions? Check the full documentation or reach out to support.

