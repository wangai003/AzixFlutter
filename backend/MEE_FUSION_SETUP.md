# Biconomy MEE Fusion Mode - Setup Complete ✅

## What is MEE Fusion?

**MEE Fusion** allows users to pay gas fees with **ERC-20 tokens instead of MATIC**!

Users can send tokens without needing native blockchain currency - they pay gas with the tokens they're already sending (like AKOFA, USDC, etc.).

## How It Works

```
Traditional:
User needs MATIC for gas ❌

MEE Fusion:
User pays gas with AKOFA ✅ (NO MATIC needed!)
```

### Architecture

1. **Trigger**: User authorizes tokens to fund a companion account
2. **Companion Account**: Holds the gas payment tokens
3. **Execution**: Transaction executes, gas is paid from companion account
4. **Result**: User sent tokens + paid gas, all with ERC-20 tokens!

## Setup Instructions

### 1. Get Biconomy Credentials

Visit [Biconomy Dashboard](https://dashboard.biconomy.io/)

1. Create an account
2. Create a new project
3. Get your API keys:
   - **Bundler URL**: `https://bundler.biconomy.io/api/v2/80002/YOUR_BUNDLER_KEY`
   - **Paymaster URL**: `https://paymaster.biconomy.io/api/v1/80002/YOUR_PAYMASTER_KEY`

### 2. Update `.env` File

```bash
# Copy env.example if you haven't
cp env.example .env

# Update with your keys
BICONOMY_API_KEY=mee_4tDgt6JRovzz33xioQ3m2r
BICONOMY_BUNDLER_URL=https://bundler.biconomy.io/api/v2/80002/YOUR_BUNDLER_KEY
BICONOMY_PAYMASTER_URL=https://paymaster.biconomy.io/api/v1/80002/YOUR_PAYMASTER_KEY
```

### 3. Start the Backend

```bash
npm run dev
```

You should see:
```
💫 Gasless Modes:
   🔄 MEE Fusion: Users pay gas with ERC-20 tokens
   🚰 Backend Faucet: Users pay $0 (backend sponsors)
```

## API Endpoints

### Send Token (Fusion or Faucet)

**POST** `/api/gasless/send-token`

```json
{
  "tokenAddress": "0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F",
  "toAddress": "0x573c0ecb03a8455d9bd3458160ffd078d5d56023",
  "amount": "10",
  "userAddress": "0x92a4ec754dc7cb6afb0d56c707ef9e4840242876",
  "useFusion": true  // true = Fusion mode, false = Faucet mode
}
```

**Response (Fusion)**:
```json
{
  "success": true,
  "txHash": "0x...",
  "mode": "fusion",
  "transaction": {
    "userPaidMatic": "0",
    "userPaidToken": "0.001",
    "feeToken": "AKOFA"
  },
  "message": "MEE Fusion: User paid gas with AKOFA - NO MATIC needed!"
}
```

### Check Token Permit Support

**GET** `/api/fusion/check-permit/:tokenAddress`

Checks if token supports ERC20Permit (gasless trigger).

### Get Companion Address

**GET** `/api/fusion/companion-address/:userAddress`

Get the companion account address for a user.

## Two Modes Available

### Mode 1: MEE Fusion ⚡ (Default)
```json
{ "useFusion": true }
```

**How it works:**
- User pays gas with ERC-20 tokens (AKOFA, USDC, etc.)
- No MATIC needed!
- Best for: Users with ERC-20 tokens but no native tokens

**Requirements:**
- Token must have sufficient balance
- If token supports ERC20Permit: Fully gasless
- If not: User needs to `approve()` first (one-time gas cost)

### Mode 2: Backend Faucet 🚰
```json
{ "useFusion": false }
```

**How it works:**
- Backend wallet distributes tokens on behalf of users
- User pays $0
- Backend pays gas with MATIC

**Requirements:**
- Backend wallet needs tokens to distribute
- Backend wallet needs MATIC for gas

## Testing

### Test Fusion Mode:

```bash
# In Flutter app, set useFusion: true in the API call
useFusion: true
```

Then send tokens - user will pay gas with the token they're sending!

### Test Faucet Mode:

```bash
useFusion: false
```

Backend distributes tokens on user's behalf.

## Token Requirements

### For Fusion Mode:
- ✅ Any ERC-20 token can be used for gas payment
- ✅ Works with: AKOFA, USDC, USDT, DAI, etc.
- ✅ Even works with LP tokens, lending receipts, governance tokens

### Checking Permit Support:

```bash
curl http://localhost:3000/api/fusion/check-permit/0xf1266ACCf0f757c61e4DFDD9EBBcaC05D2Ee375F
```

Response:
```json
{
  "supportsPermit": true,
  "gasless": true,
  "note": "Token supports ERC20Permit - trigger is gasless!"
}
```

## Key Benefits

✅ **No MATIC Required**: Users pay gas with ERC-20 tokens
✅ **Better UX**: No need to acquire native tokens first
✅ **Flexible**: Works with thousands of tokens
✅ **Secure**: Per-wallet rate limiting prevents abuse
✅ **Wallet Compatible**: Works with MetaMask, Trust, Rabby, etc.

## Rate Limiting

Both modes respect the same rate limits:
- **10 transactions per wallet per day**
- Resets every 24 hours
- Tracked by wallet address

## Troubleshooting

### Error: "Token does not support ERC20Permit"
**Solution**: Token requires `approve()` before first use. User needs small amount of MATIC for this one-time approval.

### Error: "Insufficient token balance"
**Solution**: User needs more tokens to cover both the transfer amount and gas cost.

### Error: "Gasless service temporarily unavailable"
**Solution**: 
- Check backend wallet has MATIC (for relaying)
- Check Biconomy API keys are valid

## Production Checklist

- [ ] Get production Biconomy API keys
- [ ] Set proper rate limits for your use case
- [ ] Monitor backend wallet MATIC balance
- [ ] Set up alerts for low balance
- [ ] Test with your actual tokens
- [ ] Update `ALLOWED_ORIGINS` in `.env`

## Resources

- [Biconomy Dashboard](https://dashboard.biconomy.io/)
- [MEE Documentation](https://docs.biconomy.io/)
- [Fusion Mode Guide](https://docs.biconomy.io/new/getting-started/enable-mee-eoa-fusion)

---

**Status**: ✅ Fusion Mode Fully Implemented
**Backend**: Ready
**Frontend**: Ready (use `useFusion: true`)

