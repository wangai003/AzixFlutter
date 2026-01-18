# Store Payment Mechanism Implementation

## Overview

This document describes the payment mechanism for users purchasing items from different stores using their wallet. The system requires users to enter an order ID when making payments, and securely stores all transaction details including the order ID in the backend.

## Architecture

The payment mechanism consists of three main components:

1. **Backend API** (`backend/controllers/storePaymentController.js`)
   - Stores payment transactions with order IDs securely
   - Provides endpoints for payment storage, retrieval, and verification
   - Works with or without Firebase Admin (gracefully degrades)

2. **Flutter Service** (`lib/services/store_payment_service.dart`)
   - Handles payment processing from the Flutter app
   - Executes wallet transactions
   - Stores payment details in both backend and Firestore
   - Records transactions in transaction history

3. **UI Dialog** (`lib/widgets/store_payment_dialog.dart`)
   - User-friendly interface for entering order ID and payment details
   - Validates inputs and resolves recipient addresses/tags
   - Shows payment status and success/error messages

## Features

✅ **Order ID Requirement**: Users must enter an order ID when making payments
✅ **Secure Storage**: Transaction details stored securely in backend and Firestore
✅ **Wallet Integration**: Uses existing wallet infrastructure (Stellar/Enhanced Stellar Service)
✅ **Address Resolution**: Supports both wallet addresses and AKOFA tags
✅ **Multiple Assets**: Supports payment in different assets (AKOFA, XLM, etc.)
✅ **Transaction History**: All payments recorded in user's transaction history
✅ **Error Handling**: Comprehensive error handling and user feedback
✅ **Backend Optional**: Works even if backend Firebase Admin is not configured

## Usage

### From Flutter App

```dart
import 'package:azixflutter/widgets/store_payment_dialog.dart';

// Show store payment dialog
final result = await showStorePaymentDialog(
  context: context,
  initialOrderId: 'ORD-12345', // Optional
  initialRecipientAddress: 'G...', // Optional - store address
  initialAmount: '100.0', // Optional
  initialStoreId: 'STORE-001', // Optional
  initialStoreName: 'My Store', // Optional
  initialAssetCode: 'AKOFA', // Optional
);

if (result == true) {
  // Payment successful
}
```

### Direct Service Usage

```dart
import 'package:azixflutter/services/store_payment_service.dart';

final result = await StorePaymentService.processStorePayment(
  orderId: 'ORD-12345',
  recipientAddress: 'GABCDEF...',
  amount: 100.0,
  assetCode: 'AKOFA',
  storeId: 'STORE-001', // Optional
  storeName: 'My Store', // Optional
  memo: 'Payment for order', // Optional
);

if (result.success) {
  print('Payment successful!');
  print('Transaction Hash: ${result.transactionHash}');
} else {
  print('Payment failed: ${result.error}');
}
```

## Backend API Endpoints

### Store Payment Transaction
**POST** `/api/store-payment/store`

Stores a payment transaction with order ID.

**Request Body:**
```json
{
  "orderId": "ORD-12345",
  "transactionHash": "abc123...",
  "amount": 100.0,
  "assetCode": "AKOFA",
  "recipientAddress": "G...",
  "senderAddress": "G...",
  "userId": "user123",
  "storeId": "STORE-001",
  "storeName": "My Store",
  "additionalData": {}
}
```

**Response:**
```json
{
  "success": true,
  "paymentId": "payment123",
  "orderId": "ORD-12345",
  "transactionHash": "abc123...",
  "message": "Payment transaction stored successfully"
}
```

### Get Payment by Order ID
**GET** `/api/store-payment/order/:orderId`

Retrieves payment transaction for a specific order.

**Response:**
```json
{
  "success": true,
  "payment": {
    "id": "payment123",
    "orderId": "ORD-12345",
    "transactionHash": "abc123...",
    "amount": 100.0,
    "assetCode": "AKOFA",
    "status": "completed",
    "createdAt": "2024-01-01T00:00:00Z"
  }
}
```

### Get User Payments
**GET** `/api/store-payment/user/:userId?limit=50`

Retrieves payment history for a user.

**Response:**
```json
{
  "success": true,
  "payments": [
    {
      "id": "payment123",
      "orderId": "ORD-12345",
      "transactionHash": "abc123...",
      "amount": 100.0,
      "assetCode": "AKOFA",
      "status": "completed"
    }
  ],
  "count": 1
}
```

### Verify Payment
**POST** `/api/store-payment/verify`

Verifies a payment transaction.

**Request Body:**
```json
{
  "orderId": "ORD-12345",
  "transactionHash": "abc123..."
}
```

**Response:**
```json
{
  "success": true,
  "verified": true,
  "payment": {
    "id": "payment123",
    "orderId": "ORD-12345",
    "transactionHash": "abc123...",
    "amount": 100.0,
    "assetCode": "AKOFA",
    "status": "completed"
  }
}
```

## Data Storage

### Firestore Collections

1. **`store_payment_transactions`** (Main collection)
   - Stores all payment transactions
   - Indexed by orderId, userId, transactionHash

2. **`users/{userId}/store_payments`** (User-specific)
   - Stores user's payment history
   - For fast user-specific queries

3. **`orders/{orderId}/payments`** (Order-specific)
   - Stores payments for specific orders
   - For order payment tracking

### Document Structure

```json
{
  "orderId": "ORD-12345",
  "transactionHash": "abc123...",
  "amount": 100.0,
  "assetCode": "AKOFA",
  "recipientAddress": "G...",
  "senderAddress": "G...",
  "userId": "user123",
  "storeId": "STORE-001",
  "storeName": "My Store",
  "status": "completed",
  "paymentType": "wallet",
  "additionalData": {},
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

## Payment Flow

1. **User initiates payment**
   - Opens store payment dialog
   - Enters order ID (required)
   - Enters store address or AKOFA tag
   - Enters amount and selects asset

2. **Address resolution**
   - If AKOFA tag entered, resolves to wallet address
   - Validates address format

3. **Transaction execution**
   - User confirms with password
   - Wallet transaction executed via Enhanced Stellar Service
   - Transaction hash obtained

4. **Payment storage**
   - Payment details sent to backend API
   - Payment stored in Firestore (local backup)
   - Transaction recorded in transaction history

5. **Confirmation**
   - Success message shown to user
   - Dialog auto-closes after 3 seconds

## Security Considerations

1. **Password Protection**: All transactions require user password confirmation
2. **Transaction Validation**: Order ID and transaction hash validated before storage
3. **Secure Storage**: Payment data stored securely in Firestore with proper access controls
4. **Backend Validation**: Backend validates all required fields before storage
5. **Error Handling**: Comprehensive error handling prevents data corruption

## Configuration

### Backend Configuration

Set environment variables in `backend/.env`:

```env
# Optional: Firebase Admin for backend storage
FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}

# Backend URL (for Flutter app)
BACKEND_URL=http://localhost:3000
```

### Flutter Configuration

Update `lib/services/store_payment_service.dart`:

```dart
// Backend server URL
static const String _backendUrl = 'http://localhost:3000';
// For production: 'https://your-backend.herokuapp.com'
// For mobile testing: 'http://YOUR_IP_ADDRESS:3000'
```

## Testing

### Test Payment Flow

1. Open the app and navigate to wallet screen
2. Click on "Store Payment" or call `showStorePaymentDialog()`
3. Enter:
   - Order ID: `TEST-ORDER-001`
   - Store Address: Valid Stellar address or AKOFA tag
   - Amount: `10.0`
   - Asset: `AKOFA`
4. Confirm with password
5. Verify payment appears in transaction history
6. Check backend/Firestore for stored payment

### Verify Backend Storage

```bash
# Check backend health
curl http://localhost:3000/api/store-payment/health

# Get payment by order ID
curl http://localhost:3000/api/store-payment/order/TEST-ORDER-001
```

## Error Handling

The system handles various error scenarios:

- **Invalid Order ID**: Validated before processing
- **Invalid Address**: Address resolution fails gracefully
- **Insufficient Balance**: Caught by wallet service
- **Network Errors**: Backend storage failures don't block transaction
- **Transaction Failures**: Clear error messages shown to user

## External Store Integration

External stores (websites, platforms) can integrate to receive payment confirmations:

### Webhook Notifications (Recommended)

Stores can register webhook URLs to receive real-time notifications when payments are completed:

1. **Register Store Webhook:**
   ```bash
   POST /api/store-payment/stores/{storeId}/webhook
   {
     "webhookUrl": "https://your-store.com/api/payments/webhook",
     "webhookSecret": "your-secret-key",
     "storeName": "My Store"
   }
   ```

2. **Receive Webhook Notifications:**
   - POST request sent to your webhook URL when payment completes
   - Includes order ID, transaction hash, amount, and status
   - Optional HMAC signature for security verification

### API Polling

Stores can poll for payment status using their API key:

```bash
GET /api/store-payment/verify/{orderId}
Headers: X-API-Key: your-api-key
```

**See `EXTERNAL_STORE_INTEGRATION.md` for complete integration guide.**

## Future Enhancements

Potential improvements:

1. **Payment Status Tracking**: Real-time payment status updates
2. **Refund Support**: Process refunds for store payments
3. **Payment Analytics**: Dashboard for payment statistics
4. **Multi-currency Support**: Support for more assets
5. **Payment Receipts**: Generate and email payment receipts
6. **Store Dashboard**: Web interface for stores to manage payments

## Support

For issues or questions:
- Check backend logs: `backend/server.js`
- Check Flutter logs: Payment service logs prefixed with `[STORE PAYMENT]`
- Verify Firestore rules allow write access to payment collections

