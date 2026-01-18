# Biconomy MEE Sponsorship Setup ✅

## What Changed

Your backend now uses **ONLY** the official Biconomy MEE Sponsorship method as documented at:
https://docs.biconomy.io/new/getting-started/sponsor-gas-for-users

### Previous Approach ❌
- Mixed multiple incompatible methods (old SDK + non-existent MEE client)
- Attempted to use `createMeeClient()` without proper package
- Had "Fusion" and "Faucet" modes that weren't properly implemented

### Current Approach ✅
- **Single method**: Biconomy MEE Sponsorship
- **User pays**: $0.00 (100% sponsored by Biconomy)
- **Implementation**: Follows official documentation exactly
- **Package**: Uses `@biconomy/abstractjs` (correct MEE SDK)

## How It Works

```
User Request → Backend → Biconomy MEE Client → Smart Account
                              ↓
                    Get Quote (sponsorship: true)
                              ↓
                    Execute Transaction
                              ↓
                    Gas paid by Biconomy
                              ↓
                    User pays: $0.00
```

## Setup Instructions

### 1. Install Dependencies

```bash
cd backend
npm install
```

This will install:
- `@biconomy/abstractjs` - Official MEE SDK
- `@rhinestone/module-sdk` - Required dependency
- `viem` - Ethereum library

### 2. Update Existing .env File

**Edit** the existing `.env` file in the `backend` folder:

```bash
# Update this line with your new API key
BICONOMY_API_KEY=your_api_key_from_biconomy_dashboard

# These should already exist - verify they're correct
SERVER_PRIVATE_KEY=your_backend_wallet_private_key
RPC_URL=https://rpc-amoy.polygon.technology/
CHAIN_ID=80002
PORT=3000
NODE_ENV=development
ALLOWED_ORIGINS=*
```

**Important**: 
- The `.env` file **already exists** - just edit it, don't create a new one
- `BICONOMY_API_KEY` is **REQUIRED** for sponsorship to work
- Get your API key from: https://dashboard.biconomy.io/
- The backend wallet (SERVER_PRIVATE_KEY) holds the tokens to distribute
- Gas is paid by Biconomy, NOT by your backend wallet

### 3. Get Biconomy API Key

1. Visit [Biconomy Dashboard](https://dashboard.biconomy.io/)
2. Create an account or sign in
3. Create a new project for Polygon Amoy testnet
4. Copy your API key (starts with `mee_`)
5. Add it to your `.env` file

### 4. Fund Backend Smart Account

The backend creates a smart account that holds the tokens to distribute. You need to send tokens to this smart account address.

**Find your smart account address:**
```bash
# Start the server
npm run dev

# In another terminal, check the smart account address:
curl http://localhost:3000/api/sponsorship/smart-account
```

**Send tokens to this address** from your Flutter app or MetaMask.

### 5. Start the Backend

```bash
npm run dev
```

You should see:
```
🚀 Biconomy MEE Sponsorship Service initialized
   Chain: Polygon Amoy (80002)
   API Key: mee_4tDgt6JRov...
   Backend Account: 0xC54b90E8...

💫 Gas Sponsorship:
   ✨ Biconomy MEE Sponsorship
   💰 Users pay: $0.00
   🎯 Method: Biconomy-hosted sponsorship via apiKey
```

## API Reference

### Send Sponsored Transaction

**POST** `/api/gasless/send-token`

```json
{
  "tokenAddress": "0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F",
  "toAddress": "0x573c0ecb03a8455d9bd3458160ffd078d5d56023",
  "amount": "10",
  "userAddress": "0x92a4ec754dc7cb6afb0d56c707ef9e4840242876"
}
```

**Response:**
```json
{
  "success": true,
  "txHash": "0x...",
  "mode": "sponsored",
  "transaction": {
    "token": "AKOFA",
    "amount": "10",
    "to": "0x573c...",
    "from": "0x92a4e...",
    "isGasless": true,
    "gasPaymentMethod": "Biconomy MEE Sponsorship",
    "userPaidMatic": "0",
    "userPaidToken": "0",
    "userPaidUSD": "0.00",
    "sponsored": true
  },
  "message": "Gas fully sponsored by Biconomy - User paid $0.00"
}
```

### Other Endpoints

- `GET /api/sponsorship/health` - Check if MEE service is working
- `GET /api/sponsorship/smart-account` - Get smart account address
- `POST /api/gasless/estimate-gas` - Estimate gas (always $0 for user)
- `GET /api/gasless/transaction-status/:txHash` - Check transaction status
- `POST /api/gasless/check-eligibility` - Check if user can send gasless tx

## Testing

### 1. Check Service Health

```bash
curl http://localhost:3000/api/sponsorship/health
```

Expected response:
```json
{
  "success": true,
  "service": "Biconomy MEE Sponsorship",
  "message": "MEE client initialized successfully",
  "sponsorshipAvailable": true
}
```

### 2. Get Smart Account Address

```bash
curl http://localhost:3000/api/sponsorship/smart-account
```

Fund this address with tokens!

### 3. Send Tokens (from Flutter app)

The Flutter app should call:
```dart
final result = await BiconomyBackendService.sendGaslessTransaction(
  tokenAddress: '0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F',
  toAddress: recipientAddress,
  amount: 10.0,
  userAddress: currentUserAddress,
);
```

## Key Differences from Old Implementation

| Aspect | Old ❌ | New ✅ |
|--------|--------|---------|
| **Package** | `@biconomy/account` | `@biconomy/abstractjs` |
| **Method** | Mixed Fusion/Faucet | Pure Sponsorship |
| **User Cost** | Varies | Always $0.00 |
| **Gas Paid By** | Unclear | Biconomy (via apiKey) |
| **Implementation** | Custom/Incorrect | Official Docs |
| **Smart Account** | Regular SA | Multichain Nexus |
| **Quote Method** | `getFusionQuote()` | `getQuote({ sponsorship: true })` |

## Troubleshooting

### Error: "Failed to initialize MEE client"

**Causes:**
- Missing or invalid `BICONOMY_API_KEY`
- Network issues connecting to Polygon Amoy
- Invalid `SERVER_PRIVATE_KEY`

**Solutions:**
1. Verify your API key from Biconomy Dashboard
2. Check your internet connection
3. Ensure RPC_URL is correct and accessible

### Error: "Insufficient token balance in smart account"

**Cause:** Smart account doesn't have tokens to distribute

**Solution:** Send tokens to the smart account address (check with `/api/sponsorship/smart-account`)

### Error: "Biconomy API key invalid or not configured"

**Solution:** 
1. Get API key from https://dashboard.biconomy.io/
2. Make sure it starts with `mee_`
3. Add it to `.env` file
4. Restart the server

### Transaction pending forever

**Possible causes:**
- Network congestion
- RPC issues
- Biconomy service issues

**Check:**
```bash
curl http://localhost:3000/api/gasless/transaction-status/YOUR_TX_HASH
```

## Rate Limiting

- **10 transactions per wallet per day**
- Resets every 24 hours
- Tracked by wallet address
- Can be adjusted in `middleware/userRateLimiter.js`

## Security Features

✅ **Wallet-Based Authentication**: Requires valid wallet address
✅ **Per-Wallet Rate Limiting**: Prevents abuse
✅ **IP-Based Rate Limiting**: Additional protection
✅ **CORS**: Configured for your domain
✅ **Helmet**: Security headers enabled

## Production Checklist

Before deploying to production:

- [ ] Get production Biconomy API key (not testnet)
- [ ] Set `NODE_ENV=production` in `.env`
- [ ] Configure `ALLOWED_ORIGINS` to your domain
- [ ] Set appropriate rate limits
- [ ] Monitor API key usage on Biconomy Dashboard
- [ ] Set up logging and alerts
- [ ] Test with real tokens
- [ ] Configure proper CORS origins

## Resources

- [Biconomy Dashboard](https://dashboard.biconomy.io/)
- [Sponsor Gas Docs](https://docs.biconomy.io/new/getting-started/sponsor-gas-for-users)
- [MEE Client Reference](https://docs.biconomy.io/sdk-reference/mee-client/)
- [Biconomy Support](https://discord.gg/biconomy)

---

**Status**: ✅ **Sponsorship-Only Implementation Complete**

Users pay: **$0.00** for ALL transactions
Gas paid by: **Biconomy** (via your apiKey)
