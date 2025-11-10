# Enhanced Wallet Screen - Complete File Analysis

## Overview
The **Enhanced Wallet Screen** (`lib/screens/enhanced_wallet_screen.dart`) is a comprehensive multi-asset wallet interface that supports Stellar (XLM, AKOFA), Polygon (MATIC), M-Pesa payments, MoonPay purchases, and secure wallet management.

---

## 📁 Core Screen File

### 1. `lib/screens/enhanced_wallet_screen.dart`
**Role**: Main UI component for the wallet screen
**Responsibilities**:
- Displays wallet balances (XLM, AKOFA, MATIC, and other assets)
- Shows transaction history in tabs (All, Sent, Received)
- Provides UI for sending/receiving assets
- Handles wallet creation flow
- Manages QR code display for receiving
- Integrates purchase/sell dialogs (M-Pesa, MoonPay, Card, Bank Transfer)
- Shows AKOFA tag information
- Displays wallet credentials (public key, secret key)
- Handles refresh and real-time updates

---

## 🔧 Provider Layer (State Management)

### 2. `lib/providers/enhanced_wallet_provider.dart`
**Role**: Central state management for wallet operations
**Responsibilities**:
- Manages wallet state (hasWallet, publicKey, balances, transactions)
- Coordinates between multiple services (Stellar, M-Pesa, MoonPay, Polygon)
- Handles secure wallet integration
- Manages real-time transaction monitoring
- Provides methods for:
  - Wallet creation/checking
  - Loading balances and transactions
  - Sending/receiving assets
  - M-Pesa purchase/sell operations
  - MoonPay transaction monitoring
  - Polygon wallet operations
  - Biometric authentication
- Notifies UI of state changes via ChangeNotifier

---

## 🛠️ Service Layer (Business Logic)

### 3. `lib/services/enhanced_stellar_service.dart`
**Role**: Stellar blockchain operations
**Responsibilities**:
- Wallet creation and management
- Balance queries (XLM, AKOFA, and other Stellar assets)
- Transaction history retrieval
- Sending/receiving Stellar assets
- Trustline management (AKOFA trustline creation)
- Real-time transaction monitoring
- Account funding (Friendbot for testnet)
- Transaction signing and submission

### 4. `lib/services/secure_wallet_service.dart`
**Role**: Secure wallet encryption and storage
**Responsibilities**:
- Encrypted wallet storage in Firestore
- Biometric authentication integration
- Wallet key encryption/decryption
- Secure wallet creation and retrieval
- Public/private key management
- Wallet recovery functionality

### 5. `lib/services/enhanced_mpesa_service.dart`
**Role**: M-Pesa payment integration
**Responsibilities**:
- M-Pesa STK Push (buy AKOFA with M-Pesa)
- M-Pesa sell (convert AKOFA to M-Pesa)
- Payment status checking
- Transaction history for M-Pesa payments
- Webhook handling for payment confirmations

### 6. `lib/services/moonpay_service.dart`
**Role**: MoonPay cryptocurrency purchase integration
**Responsibilities**:
- MoonPay widget integration
- Purchase transaction creation
- Transaction status monitoring
- MoonPay API communication
- Purchase history tracking

### 7. `lib/services/moonpay_callback_service.dart`
**Role**: MoonPay webhook and callback handling
**Responsibilities**:
- Processing MoonPay webhook callbacks
- Transaction status updates
- Payment confirmation handling
- Error handling for MoonPay transactions

### 8. `lib/services/polygon_wallet_service.dart`
**Role**: Polygon blockchain wallet operations
**Responsibilities**:
- Polygon wallet creation
- MATIC balance queries
- ERC-20 token balance queries
- Polygon transaction history
- Polygon address management

### 9. `lib/services/payment_webhook_service.dart`
**Role**: Payment webhook processing
**Responsibilities**:
- M-Pesa webhook handling
- Payment status updates
- Transaction confirmation processing

### 10. `lib/services/payment_security_service.dart`
**Role**: Payment security and validation
**Responsibilities**:
- Payment amount validation
- Security checks for transactions
- Fraud prevention
- Transaction verification

### 11. `lib/services/akofa_tag_service.dart`
**Role**: AKOFA tag management
**Responsibilities**:
- Tag creation (e.g., "david2356")
- Tag-to-wallet address resolution
- Wallet-to-tag resolution
- Tag validation
- Multi-blockchain tag support (Stellar, Polygon)

---

## 🎨 Widget Layer (UI Components)

### 12. `lib/widgets/multi_asset_balance_display.dart`
**Role**: Display wallet balances for multiple assets
**Responsibilities**:
- Shows XLM, AKOFA, MATIC balances
- Displays other Stellar assets
- Balance formatting and display
- Asset icons and symbols

### 13. `lib/widgets/enhanced_transaction_list.dart`
**Role**: Transaction history display
**Responsibilities**:
- Lists all transactions
- Filters by type (Sent/Received)
- Transaction details display
- Transaction status indicators
- Date/time formatting

### 14. `lib/widgets/send_akofa_dialog.dart`
**Role**: Dialog for sending AKOFA tokens
**Responsibilities**:
- Recipient address/tag input
- Amount input and validation
- Transaction confirmation
- Memo field
- Sending AKOFA via Stellar

### 15. `lib/widgets/qr_code_display.dart`
**Role**: QR code generation and display
**Responsibilities**:
- Generates QR code for wallet address
- Displays QR code for receiving assets
- Share functionality
- Copy address to clipboard

### 16. `lib/widgets/mpesa_purchase_dialog.dart`
**Role**: M-Pesa purchase dialog
**Responsibilities**:
- Amount input for M-Pesa purchase
- Phone number input
- M-Pesa STK Push initiation
- Purchase confirmation UI

### 17. `lib/widgets/mpesa_sell_dialog.dart`
**Role**: M-Pesa sell dialog
**Responsibilities**:
- Amount input for selling AKOFA
- Phone number input for M-Pesa payout
- Sell confirmation
- Transaction processing

### 18. `lib/widgets/moonpay_purchase_dialog.dart`
**Role**: MoonPay purchase dialog
**Responsibilities**:
- MoonPay widget integration
- Purchase amount selection
- MoonPay transaction flow
- Purchase status display

### 19. `lib/widgets/moonpay_button.dart`
**Role**: MoonPay purchase button widget
**Responsibilities**:
- MoonPay widget button
- Purchase flow initiation
- Status indicators

### 20. `lib/widgets/token_sell_dialog.dart`
**Role**: Generic token sell dialog
**Responsibilities**:
- Token selling interface
- Amount selection
- Sell confirmation

### 21. `lib/widgets/card_payment_dialog.dart`
**Role**: Card payment dialog
**Responsibilities**:
- Card payment UI
- Payment processing
- Card details input

### 22. `lib/widgets/bank_transfer_dialog.dart`
**Role**: Bank transfer dialog
**Responsibilities**:
- Bank transfer instructions
- Bank details display
- Transfer confirmation

---

## 📱 Supporting Screens

### 23. `lib/screens/secure_wallet_creation_screen.dart`
**Role**: Secure wallet creation flow
**Responsibilities**:
- New wallet creation UI
- Biometric setup
- Wallet encryption setup
- Recovery phrase display
- Wallet backup instructions

### 24. `lib/screens/buy_crypto_screen.dart`
**Role**: Cryptocurrency purchase screen
**Responsibilities**:
- Purchase options display
- M-Pesa, MoonPay, Card payment options
- Purchase flow navigation

---

## 📊 Model Layer (Data Structures)

### 25. `lib/models/transaction.dart`
**Role**: Transaction data model
**Responsibilities**:
- Transaction data structure
- Transaction types (send, receive, buy, swap, etc.)
- Transaction status (pending, completed, failed)
- Firestore serialization/deserialization
- Transaction metadata

### 26. `lib/models/asset_config.dart`
**Role**: Asset configuration model
**Responsibilities**:
- Asset definitions (code, issuer, name, symbol)
- Stellar asset configuration
- Stablecoin configuration
- Asset metadata

---

## 🔐 Authentication & Security

### 27. `lib/providers/auth_provider.dart`
**Role**: User authentication state
**Responsibilities**:
- User authentication status
- Firebase Auth integration
- User session management

---

## 🎨 Theme & Styling

### 28. `lib/theme/app_theme.dart`
**Role**: App-wide theme configuration
**Responsibilities**:
- Color schemes (black, gold, grey)
- Typography styles
- Button styles
- Card styles
- Consistent UI theming

---

## 📋 Navigation Integration

### 29. `lib/screens/main_navigation.dart`
**Role**: Main app navigation
**Responsibilities**:
- Wallet screen navigation
- Tab navigation setup
- Screen routing

---

## 🔄 Data Flow Summary

```
User Interaction (UI)
    ↓
EnhancedWalletScreen
    ↓
EnhancedWalletProvider (State Management)
    ↓
Services Layer:
    - EnhancedStellarService (Stellar operations)
    - SecureWalletService (Encryption/Storage)
    - EnhancedMpesaService (M-Pesa payments)
    - MoonPayService (Crypto purchases)
    - PolygonWalletService (Polygon operations)
    - AkofaTagService (Tag management)
    ↓
External APIs:
    - Stellar Blockchain
    - Firebase Firestore
    - M-Pesa API
    - MoonPay API
    - Polygon RPC
    ↓
Data Models:
    - Transaction
    - AssetConfig
    ↓
UI Updates via Provider Notifications
```

---

## 🎯 Key Features Supported

1. **Multi-Asset Support**: XLM, AKOFA, MATIC, and other Stellar assets
2. **Secure Wallet**: Encrypted storage with biometric authentication
3. **M-Pesa Integration**: Buy/sell AKOFA with M-Pesa
4. **MoonPay Integration**: Purchase crypto with card/bank
5. **Polygon Support**: MATIC wallet and ERC-20 tokens
6. **AKOFA Tags**: Human-readable wallet identifiers
7. **Real-time Updates**: Live transaction and balance monitoring
8. **QR Codes**: Easy asset receiving via QR codes
9. **Transaction History**: Complete transaction tracking
10. **Multi-blockchain**: Stellar and Polygon support

---

## 📝 File Count Summary

- **Core Screen**: 1 file
- **Providers**: 1 file
- **Services**: 11 files
- **Widgets**: 11 files
- **Models**: 2 files
- **Supporting Screens**: 2 files
- **Theme**: 1 file
- **Navigation**: 1 file

**Total: ~30 files** directly associated with the Enhanced Wallet Screen functionality.

