# Soroban Mining Contract Deployment Guide

This guide walks you through deploying the onchain mining contract to Stellar testnet.

## Prerequisites

1. **Node.js** (>= 16.0.0)
2. **Rust** and **Cargo** (for building the contract)
3. **Stellar testnet account** with XLM for fees
4. **AKOFA tokens** in the distributor account

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Build the contract:**
   ```bash
   npm run build-contract
   ```

3. **Verify WASM file exists:**
   ```bash
   ls -la soroban_contracts/mining_contract/target/wasm32-unknown-unknown/release/
   # Should see: mining_contract.wasm
   ```

## Configuration

Update the following in `deploy_contract.js`:

```javascript
const DISTRIBUTOR_SECRET = 'SCB3ICTKZ3FQX6R6JRBV2427JVPGN7IELDUWQOKDFGT5BGKQKWBURPIR'; // Your distributor key
const AKOFA_ISSUER = 'GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW'; // AKOFA issuer
const AKOFA_CODE = 'AKOFA'; // Asset code
```

## Deployment Steps

1. **Ensure distributor account has XLM:**
   - Account needs ~5 XLM for contract operations
   - Fund via [Stellar Laboratory](https://laboratory.stellar.org/) or Friendbot

2. **Ensure distributor account has AKOFA tokens:**
   - The distributor account must hold AKOFA tokens to pay mining rewards
   - Transfer AKOFA to: `GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

3. **Deploy the contract:**
   ```bash
   npm run deploy
   ```

## What the Deployment Does

1. **Uploads WASM** to Stellar network
2. **Creates contract instance** with unique ID
3. **Initializes contract** with AKOFA asset details and mining rate
4. **Saves deployment info** to `contract_deployment.json`

## Expected Output

```
🚀 Starting Soroban mining contract deployment...
📝 Using account: GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
📦 Loaded WASM file, size: 21780 bytes
💰 Account sequence: 123456789
⬆️  Step 1: Uploading contract WASM...
📤 Submitting WASM upload transaction...
⏳ Waiting for WASM upload confirmation...
✅ WASM uploaded, hash: a1b2c3d4...
🏗️  Step 2: Creating contract instance...
📤 Submitting contract creation transaction...
⏳ Waiting for contract creation confirmation...
✅ Contract created, ID: CA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLTJJFC7MGXUA74P7UJVSGZ
⚙️  Step 3: Initializing contract...
📤 Submitting contract initialization...
⏳ Waiting for initialization confirmation...
✅ Contract initialized successfully!

🎉 DEPLOYMENT COMPLETE!
📋 Contract Details:
   Contract ID: CA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLTJJFC7MGXUA74P7UJVSGZ
   Network: Stellar Testnet
   AKOFA Asset: AKOFA:GAXGCEV2XGCUORUWQ4B2NTRVLKUVDCOQT2EL5C3GY3X72LFR2G3QKSKW
   Mining Rate: 0.25 AKOFA/hour
💾 Deployment info saved to contract_deployment.json
```

## Update Flutter App

After successful deployment:

1. **Copy the Contract ID** from the output or `contract_deployment.json`

2. **Update SorobanMiningService:**
   ```dart
   // In lib/services/soroban_mining_service.dart
   SorobanMiningService() {
     _contractId = "CA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLTJJFC7MGXUA74P7UJVSGZ"; // Your deployed ID
   }
   ```

3. **Test the integration:**
   - Start mining from the app
   - Verify onchain session creation
   - Wait for automatic payout (or trigger Cloud Function manually)

## Troubleshooting

### Common Issues

1. **"WASM file not found"**
   - Run `npm run build-contract` first
   - Check the path in `deploy_contract.js`

2. **"Insufficient balance"**
   - Fund the distributor account with XLM
   - Use Stellar Laboratory to check balance

3. **"Contract initialization failed"**
   - Ensure distributor account holds AKOFA tokens
   - Check AKOFA asset details are correct

4. **Transaction timeouts**
   - Increase timeout in `deploy_contract.js`
   - Check Stellar testnet status

### Manual Verification

Use [Stellar Laboratory](https://laboratory.stellar.org/) to:

1. **Check contract existence:** Search for the contract ID
2. **Verify transactions:** Look for contract creation and initialization txs
3. **Test contract calls:** Use the contract explorer

## Next Steps

1. **Test mining flow** end-to-end
2. **Monitor Cloud Function** for automatic payouts
3. **Deploy to mainnet** when ready (change `NETWORK` and `RPC_URL`)
4. **Add monitoring** and alerting for contract operations

## Security Notes

- **Never commit private keys** to version control
- **Use environment variables** for secrets in production
- **Test thoroughly** on testnet before mainnet deployment
- **Monitor contract balance** to ensure sufficient AKOFA for payouts

## Support

For issues:
1. Check Stellar testnet status
2. Verify account balances
3. Review transaction results in Laboratory
4. Check contract logs in deployment output