# Transaction History Setup Guide

## ⭐ Recommended: Alchemy API (Best Option)

**Alchemy is the best choice for viewing ALL your transactions**, including full history on both testnet and mainnet.

### Why Alchemy?
- ✅ **Full transaction history** from the beginning (not just recent)
- ✅ Works perfectly on Amoy testnet
- ✅ Much faster than other methods
- ✅ Free tier: 300M compute units/month (more than enough)
- ✅ Both native MATIC and ERC-20 tokens

### How to Get Alchemy API Key (5 minutes):

1. **Visit** [https://www.alchemy.com/](https://www.alchemy.com/)
2. **Click "Get started for free"** or "Sign up"
3. **Create account** (free, no credit card required)
4. **Create a new app:**
   - Click "Create new app"
   - Name: "AzixFlutter" (or anything you like)
   - Chain: **Polygon**
   - Network: **Polygon Amoy** (for testnet)
5. **Get your API key:**
   - Click on your app
   - Click "API Key" button
   - Copy the API key

6. **Configure in your app:**
   - Open: `lib/config/api_config.dart`
   - Replace `'YourAlchemyApiKey'` with your actual key:
   ```dart
   static const String alchemyApiKey = 'YOUR_ACTUAL_ALCHEMY_KEY_HERE';
   ```

7. **Restart the app** - You'll now see ALL your transactions! 🎉

---

## Alternative: PolygonScan API (Limited)

⚠️ **Note:** PolygonScan API has issues on testnet and only shows indexed transactions.

### Why You Might Need a PolygonScan API Key

Without an API key:
- ❌ API has severe rate limits (1 call per 5 seconds)
- ❌ On Amoy testnet, transactions may not be visible
- ❌ You may see "0 transactions" even when transactions exist

## How to Get Your Free API Key

### Step 1: Visit PolygonScan
Go to [https://polygonscan.com/apis](https://polygonscan.com/apis)

### Step 2: Create an Account
1. Click "Register" to create a new account
2. Fill in your email and password
3. Verify your email address

### Step 3: Generate API Key
1. Log in to your PolygonScan account
2. Go to "API Keys" section
3. Click "Add" to create a new API key
4. Give it a name (e.g., "AzixFlutter")
5. Copy the generated API key

### Step 4: Configure the API Key

Open the file: `lib/config/api_config.dart`

Replace the placeholder with your actual API key:

```dart
class ApiConfig {
  // Replace 'YourApiKeyToken' with your actual API key
  static const String polygonScanApiKey = 'YOUR_ACTUAL_API_KEY_HERE';
  
  static bool get hasPolygonScanApiKey => 
      polygonScanApiKey != 'YourApiKeyToken' && 
      polygonScanApiKey.isNotEmpty;
}
```

### Step 5: Restart the App

After configuring the API key:
1. Stop the running app
2. Rebuild and restart: `flutter run`
3. Your transactions should now be visible!

## Verification

After configuration, check the console logs when viewing transactions:
- ✅ You should see: `🔑 API Key configured: Yes`
- ✅ Transactions should load properly

If you still see issues:
- Make sure you copied the API key correctly (no extra spaces)
- Verify the API key is active on PolygonScan
- Check if you're on the correct network (Amoy testnet vs Mainnet)

## Notes

- The same API key works for both Mainnet and Amoy Testnet
- Free tier allows up to 5 calls per second
- Your API key is stored locally and never shared
- Do NOT commit your actual API key to version control

## Troubleshooting

### "No transactions found" but transaction exists on PolygonScan
- **Solution**: Configure your API key as described above

### "Invalid API Key" error
- **Solution**: Double-check you copied the full API key without spaces
- Regenerate a new API key on PolygonScan if needed

### Rate limit errors
- **Solution**: Your API key might not be configured
- Free tier: 5 calls/sec
- Without key: 1 call/5 sec

