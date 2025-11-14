# Cross-Chain Bridge Implementation

## Overview

This implementation adds a fully-Flutter, non-custodial cross-chain bridge feature to Azix Wallet, enabling users to bridge tokens between Stellar and EVM chains (Ethereum, Polygon, BSC, Avalanche) via LI.FI/Allbridge.

## Architecture

### Components

1. **LI.FI Client** (`lib/bridge/services/lifi_client.dart`)
   - Handles all LI.FI API calls
   - Quote requests, route status, execution

2. **Route Executor** (`lib/bridge/services/route_executor.dart`)
   - Manages multi-step route execution
   - Coordinates signing and submission
   - Polls for route completion

3. **Signers**
   - **Stellar Signer** (`lib/bridge/crypto/stellar_signer.dart`): Signs Stellar XDR transactions
   - **EVM Signer** (`lib/bridge/crypto/evm_signer.dart`): Signs EVM transactions via WalletConnect

4. **Job Store** (`lib/bridge/services/job_store.dart`)
   - SQLite persistence for bridge jobs
   - Survives app restarts

5. **Bridge Provider** (`lib/bridge/providers/bridge_provider.dart`)
   - State management
   - Coordinates all bridge operations

6. **Bridge Screen** (`lib/screens/bridge_screen.dart`)
   - User interface for bridge operations
   - Quote display, route selection, progress tracking

## Setup Instructions

### 1. Install Dependencies

The following packages have been added to `pubspec.yaml`:
- `web3dart: ^2.7.3` - EVM operations
- `walletconnect_dart: ^1.0.0` - WalletConnect integration
- `sqflite: ^2.3.0` - SQLite database
- `path: ^1.8.3` - Path utilities

Run:
```bash
flutter pub get
```

### 2. Configure Bridge Settings

Edit `lib/bridge/bridge_config.dart`:

1. **Set Network Mode**:
   ```dart
   static const bool useTestnet = true; // Set to false for mainnet
   ```

2. **Configure WalletConnect**:
   ```dart
   static const String walletConnectProjectId = 'YOUR_WALLETCONNECT_PROJECT_ID';
   ```
   Get your project ID from [WalletConnect Cloud](https://cloud.walletconnect.com/)

3. **Configure RPC Endpoints** (optional, for read-only queries):
   ```dart
   static const String ethereumRpcUrl = 'https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY';
   static const String polygonRpcUrl = 'https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY';
   ```

### 3. Secure Storage Setup

The bridge uses `flutter_secure_storage` for Stellar secret seeds. Ensure your app has proper security configuration:

**Android**: Already configured in `android/app/build.gradle`

**iOS**: Add to `ios/Runner/Info.plist`:
```xml
<key>NSFaceIDUsageDescription</key>
<string>We need Face ID to secure your wallet</string>
```

### 4. Testnet Setup

For testing, use Stellar testnet and EVM testnets:

- **Stellar Testnet**: Already configured
- **Ethereum Goerli**: Chain ID `5`
- **Polygon Mumbai**: Chain ID `80001`

## Usage

### Getting a Quote

1. Open the Bridge screen from navigation
2. Select source chain (e.g., Stellar)
3. Select destination chain (e.g., Polygon)
4. Select tokens (e.g., XLM → USDC)
5. Enter amount
6. Enter recipient address
7. Click "Get Quote"

### Executing a Bridge

1. Review available routes
2. Select preferred route (shows fees, ETA)
3. Click "Start Bridge"
4. Sign transactions as prompted:
   - **Stellar**: Signs XDR in-app using secure storage
   - **EVM**: Opens WalletConnect to sign in external wallet
5. Monitor progress in real-time
6. Bridge completes automatically

### Receiving Bridged Tokens

1. Go to Bridge screen
2. Click "Receive" (future feature)
3. Copy Stellar address or memo
4. Send tokens from other chain to that address

## Security

- **Private Keys**: Never transmitted off-device
- **Stellar Seeds**: Stored in `flutter_secure_storage` with biometric protection
- **EVM Signing**: Uses WalletConnect (user's wallet app)
- **HTTPS**: All API calls use HTTPS
- **Encryption**: Job data encrypted at rest

## Testing

### Testnet Testing

1. Set `useTestnet = true` in `bridge_config.dart`
2. Use Stellar testnet account (fund with Friendbot)
3. Use EVM testnet accounts (fund with faucets)
4. Test routes:
   - Stellar → Polygon (testnet)
   - Polygon → Stellar (testnet)

### Test Accounts

For QA only (testnet):
- Stellar testnet: Use Friendbot to fund
- EVM testnets: Use faucets (Goerli, Mumbai)

**⚠️ Never commit mainnet private keys**

## Troubleshooting

### "Secret seed not found"
- Ensure wallet is created/imported
- Check secure storage permissions
- Verify biometric authentication is enabled

### "Wallet not connected" (EVM)
- Ensure WalletConnect is initialized
- User must approve connection in wallet app
- Check WalletConnect project ID is correct

### "No routes found"
- Check token addresses are correct
- Verify chains are supported by LI.FI
- Ensure sufficient balance for fees

### Route stalls
- Check network connectivity
- Verify transaction was submitted
- Check LI.FI status endpoint
- Review job store for error messages

## API Endpoints

- **LI.FI Quote**: `https://li.quest/v1/quote`
- **LI.FI Status**: `https://li.quest/v1/status`
- **LI.FI Execute**: `https://li.quest/v1/execute`

## Future Enhancements

- [ ] Receive screen with QR codes
- [ ] Token fallback suggestions
- [ ] Advanced route view
- [ ] Route history
- [ ] Fee optimization
- [ ] Multi-step progress visualization
- [ ] Error recovery flows
- [ ] Analytics integration

## Support

For issues or questions:
1. Check logs in console
2. Review job store for error details
3. Check LI.FI API status
4. Verify network connectivity

## License

Part of Azix Wallet project.

