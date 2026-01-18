# Biconomy Gasless Transaction Setup Guide

## Overview
This guide will help you set up Biconomy for gasless transactions on Polygon Amoy Testnet, allowing your users to send tokens without needing MATIC for gas fees.

## What is Biconomy?
Biconomy is a meta-transaction infrastructure that sponsors gas fees for users, enabling gasless transactions. Your app pays for the gas fees through a gas tank, and users can send tokens without holding MATIC.

## Features Implemented
✅ **Automatic Gasless Detection** - System automatically offers gasless transactions when users lack MATIC
✅ **ERC-20 Token Support** - Works with AKOFA and other ERC-20 tokens on Polygon
✅ **Fallback to Regular Transactions** - Uses regular transactions when user has MATIC
✅ **User-Friendly UI** - Clear messaging about free transactions with visual indicators
✅ **Smart Routing** - Automatically chooses the best transaction method

## Setup Instructions

### 1. Sign Up for Biconomy

1. Visit [Biconomy Dashboard](https://dashboard.biconomy.io)
2. Create an account or sign in
3. Navigate to "Gasless API" section

### 2. Configure Your DApp

1. **Register Your DApp**
   - Click "Register New DApp"
   - DApp Name: `AzixFlutter`
   - Network: `Polygon Amoy Testnet`
   - Submit

2. **Get Your API Key**
   - After registration, you'll receive an API key
   - Copy this key - you'll need it in step 3

3. **Add API Key to Your App**
   - Open `lib/services/biconomy_service.dart`
   - Replace `YOUR_BICONOMY_API_KEY` with your actual API key:
   
   ```dart
   static const String _biconomyApiKey = 'your-actual-api-key-here';
   ```

### 3. Register Smart Contracts

For each ERC-20 token you want to support gasless transactions:

1. In Biconomy Dashboard, go to **"Meta Transaction"** tab
2. Click **"Add Contract"**
3. Enter your token contract details:
   - **Contract Address**: Your AKOFA token address on Polygon Amoy
   - **Contract Type**: Select "ERC-20"
   - **Functions to Enable**: Select `transfer(address,uint256)`

4. Click **"Add"** and wait for confirmation

### 4. Configure Gas Tank

1. Navigate to **"Gas Tank"** section in dashboard
2. **Fund Your Gas Tank**:
   - Add MATIC to your gas tank (testnet MATIC for Amoy)
   - Recommended starting amount: 5-10 MATIC for testing
   
3. **Set Gas Limits** (Optional):
   - Daily limit per user
   - Transaction limit
   - Total daily limit

### 5. Get Testnet MATIC

To fund your gas tank on Amoy testnet:

1. Visit [Polygon Faucet](https://faucet.polygon.technology/)
2. Select "Polygon Amoy Testnet"
3. Enter your gas tank wallet address
4. Request MATIC

Alternative faucets:
- [Alchemy Polygon Faucet](https://mumbaifaucet.com/)
- [QuickNode Faucet](https://faucet.quicknode.com/polygon/mumbai)

### 6. Token Contract Addresses

Update these in your configuration:

```dart
// In lib/services/biconomy_service.dart or your config file
const String AKOFA_CONTRACT_ADDRESS = 'YOUR_AKOFA_CONTRACT_ADDRESS';
```

For Polygon Amoy testnet:
- **AKOFA Token**: `0x...` (Get from your deployment)
- **USDC**: `0x...` (If supporting stablecoins)

### 7. Enable Gasless in Your App

The gasless feature is enabled by default. To customize:

```dart
// In your app initialization or settings
walletProvider.setGaslessEnabled(true); // Enable gasless
walletProvider.setUseGaslessWhenPossible(true); // Auto-use when MATIC is low
```

## Testing

### Test Gasless Transactions

1. **Create a test wallet** with 0 MATIC
2. **Receive some AKOFA tokens** (or test ERC-20)
3. **Try to send tokens** - system should offer gasless option
4. **Complete transaction** - should succeed without MATIC

### Test Regular Transactions

1. **Fund wallet with MATIC**
2. **Send tokens** - should use regular transaction by default
3. **Verify gas fees** were deducted from your MATIC balance

### Verify in Biconomy Dashboard

- Check **"Analytics"** tab for transaction stats
- Monitor **"Gas Tank"** balance
- View **"Transaction History"**

## Configuration Options

### Disable Gasless Transactions

```dart
walletProvider.setGaslessEnabled(false);
```

### Force Gasless for Specific Transaction

```dart
await walletProvider.sendAsset(
  recipientAddress: '0x...',
  asset: akofaAsset,
  amount: 100,
  password: userPassword,
  forceGasless: true, // Force gasless even if user has MATIC
);
```

### Check if Gasless is Available

```dart
final canUseGasless = await BiconomyService.canUseGasless(
  userAddress: userWalletAddress,
  tokenAddress: tokenContractAddress,
);
```

## Troubleshooting

### Issue: "Gasless transactions are currently disabled"
**Solution**: Check that `_biconomyApiKey` is set and not the placeholder value.

### Issue: "Failed to relay meta-transaction"
**Solution**: 
- Verify contract is registered in Biconomy dashboard
- Check that `transfer` function is whitelisted
- Ensure gas tank has sufficient MATIC

### Issue: "Token not whitelisted"
**Solution**: Register the token contract in Biconomy dashboard and enable the transfer function.

### Issue: Transaction fails silently
**Solution**: 
- Check Biconomy dashboard logs
- Verify network is set to Amoy testnet
- Ensure user has sufficient token balance

### Issue: High gas costs in tank
**Solution**: 
- Set daily/per-user limits in dashboard
- Monitor for spam/abuse patterns
- Implement rate limiting in your app

## Cost Management

### Estimating Costs

Average gas cost per ERC-20 transfer: ~100,000 gas
Current Polygon gas price: ~30 gwei

Estimated cost per transaction: ~0.003 MATIC ($0.001)

For 1000 transactions/day:
- Daily cost: ~3 MATIC
- Monthly cost: ~90 MATIC

### Setting Limits

Recommended settings for production:

```dart
// In Biconomy Dashboard:
- Per-user daily limit: 10 transactions
- Per-transaction gas limit: 200,000
- Daily total limit: 1000 transactions
```

### Monitoring

Set up alerts in Biconomy dashboard:
- Low gas tank balance (< 10 MATIC)
- High transaction volume
- Failed transaction rate

## Production Checklist

Before going live on mainnet:

- [ ] Replace testnet RPC with mainnet RPC
- [ ] Update `_chainId` to 137 (Polygon mainnet)
- [ ] Register contracts on mainnet Biconomy dashboard
- [ ] Fund gas tank with mainnet MATIC
- [ ] Test all token types (AKOFA, USDC, etc.)
- [ ] Set production limits and alerts
- [ ] Enable rate limiting
- [ ] Monitor costs for first week
- [ ] Have backup MATIC for emergency top-ups

## Security Best Practices

1. **API Key Security**
   - Never commit API keys to git
   - Use environment variables in production
   - Rotate keys periodically

2. **Gas Tank Management**
   - Keep minimum balance for operations
   - Set spending limits
   - Monitor for unusual activity

3. **User Limits**
   - Implement per-user rate limiting
   - Track user transaction patterns
   - Ban suspicious addresses

4. **Contract Security**
   - Only whitelist necessary functions
   - Verify contract addresses before adding
   - Monitor for reentrancy attacks

## Support

- **Biconomy Documentation**: https://docs.biconomy.io
- **Discord**: https://discord.gg/biconomy
- **Telegram**: https://t.me/biconomy
- **GitHub Issues**: Report bugs in this repository

## Additional Resources

- [Biconomy SDK Documentation](https://docs.biconomy.io/products/enable-gasless-transactions)
- [EIP-2771: Secure Protocol for Native Meta Transactions](https://eips.ethereum.org/EIPS/eip-2771)
- [EIP-712: Typed structured data hashing and signing](https://eips.ethereum.org/EIPS/eip-712)
- [Polygon Network Documentation](https://docs.polygon.technology/)

## FAQ

**Q: Do I need Biconomy for MATIC transfers?**
A: No, gasless only works for ERC-20 tokens. MATIC transfers require gas.

**Q: What happens if my gas tank runs out?**
A: Gasless transactions will fail. Users will see regular "insufficient gas" messages. Top up immediately.

**Q: Can users choose between gasless and regular transactions?**
A: Yes, if users have MATIC, they can use regular transactions. The app auto-suggests gasless when MATIC is insufficient.

**Q: Is there a transaction limit per user?**
A: You can set limits in the Biconomy dashboard to prevent abuse.

**Q: How do I handle failed gasless transactions?**
A: The app automatically falls back to showing the top-up option. Failed transaction details are in Biconomy dashboard logs.

---

**Last Updated**: December 2024
**Version**: 1.0.0
**Polygon Network**: Amoy Testnet

