# Quick Start - Biconomy MEE Sponsorship

## 🚀 Get Started in 5 Minutes

### Step 1: Install Dependencies (30 seconds)

```bash
cd backend
npm install
```

### Step 2: Update Existing .env File (2 minutes)

**Edit** the existing `.env` file in the backend folder:

```bash
# Update this line with your API key
BICONOMY_API_KEY=your_api_key_from_biconomy_dashboard

# These should already be set - verify they're correct
SERVER_PRIVATE_KEY=your_backend_wallet_private_key_here
RPC_URL=https://rpc-amoy.polygon.technology/
CHAIN_ID=80002
PORT=3000
NODE_ENV=development
```

**Get your API key:** https://dashboard.biconomy.io/

**Note:** The `.env` file already exists - just edit it, don't create a new one!

### Step 3: Start Backend (10 seconds)

```bash
npm run dev
```

You should see:
```
✅ Server ready to accept requests
💫 Gas Sponsorship:
   ✨ Biconomy MEE Sponsorship
   💰 Users pay: $0.00
```

### Step 4: Get Smart Account Address (1 minute)

```bash
curl http://localhost:3000/api/sponsorship/smart-account
```

Response:
```json
{
  "success": true,
  "address": "0x..."
}
```

### Step 5: Fund Smart Account (1 minute)

Send tokens (AKOFA, USDC, etc.) to the smart account address from Step 4.

### Step 6: Test (30 seconds)

From your Flutter app:

```dart
final result = await BiconomyBackendService.sendGaslessTransaction(
  tokenAddress: '0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F',
  toAddress: recipientAddress,
  amount: 10.0,
  userAddress: currentUserAddress,
);

if (result['success']) {
  print('✅ Transaction sent!');
  print('User paid: ${result['transaction']['userPaidUSD']}'); // $0.00
}
```

## ✅ Done!

Your gasless transactions are now working with Biconomy MEE Sponsorship.

**Users pay:** $0.00  
**Gas paid by:** Biconomy (via your apiKey)

## Common Issues

### ❌ "Module not found: @biconomy/abstractjs"
**Fix:** Run `npm install` in backend folder

### ❌ "Failed to initialize MEE client"
**Fix:** Check your `BICONOMY_API_KEY` in `.env`

### ❌ "Insufficient token balance"
**Fix:** Send tokens to the smart account address

### ❌ Flutter app error: "useFusion is not a named parameter"
**Fix:** Remove `useFusion` parameter from Flutter code:

```dart
// Old (remove useFusion):
await BiconomyBackendService.sendGaslessTransaction(
  ...,
  useFusion: true, // ❌ Remove this line
);

// New:
await BiconomyBackendService.sendGaslessTransaction(
  ...,
); // ✅ No useFusion parameter
```

## Next Steps

- Read `SPONSORSHIP_SETUP.md` for detailed configuration
- Read `CHANGES_SUMMARY.md` to understand what changed
- Check Biconomy Dashboard for transaction logs
- Adjust rate limits in `middleware/userRateLimiter.js`

## API Endpoints

Test these endpoints:

```bash
# Health check
curl http://localhost:3000/health

# Sponsorship health
curl http://localhost:3000/api/sponsorship/health

# Get smart account
curl http://localhost:3000/api/sponsorship/smart-account

# Check transaction status
curl http://localhost:3000/api/gasless/transaction-status/0x...
```

## Support

- [Biconomy Docs](https://docs.biconomy.io/)
- [Discord](https://discord.gg/biconomy)
- [Dashboard](https://dashboard.biconomy.io/)

---

**You're ready to go!** 🎉

Users can now send tokens without paying gas fees.
