# Store Payment Integration Guide (Third Parties)

This guide explains how third‑party stores connect to the Azix backend to
receive and verify wallet payments linked to order IDs.

## Works Well?

Yes, the integration works well if the backend is configured correctly and the
store follows the webhook or polling flow. Payments are only accepted after the
backend confirms the on‑chain receipt, so a store will not receive a "paid"
signal for a pending/failed transaction.

## Requirements

Backend operators must set the following env vars:

- `POLYGON_MAINNET_RPC_URL` (required for USDC/USDT payments)
- `POLYGON_AMOY_RPC_URL` (required for AKOFA testnet payments)
- Firestore access (either `firebase-service-account.json` in `backend/`
  or `FIREBASE_SERVICE_ACCOUNT` env var)

## Base URL

Replace `<BACKEND_URL>` with your backend base URL, for example:

- `https://api.yourdomain.com`
- `http://<SERVER_IP>:3000`

## Integration Options

You can integrate in either of these ways:

1) **Webhook (recommended)**: The backend calls your store when payment is
   stored and confirmed.
2) **Polling/Verification**: Your store checks payment status by order ID.

You may also combine both: use webhook for immediate updates and poll as
fallback.

---

## 1) Register Webhook

Register your webhook URL and receive your API key.

**Endpoint**

`POST <BACKEND_URL>/api/store-payment/stores/:storeId/webhook`

**Headers**

- `Content-Type: application/json`

**Body**

```json
{
  "webhookUrl": "https://your-store.com/webhooks/azix-payment",
  "webhookSecret": "optional_shared_secret",
  "storeName": "My Store"
}
```

**Response**

```json
{
  "success": true,
  "storeId": "store_123",
  "apiKey": "YOUR_API_KEY",
  "message": "Store webhook registered successfully"
}
```

Store the returned `apiKey` securely. You will use it for payment verification.

---

## 2) Webhook Delivery

When a payment is confirmed on-chain and stored, the backend sends:

**Event**

`payment.completed`

**Webhook Payload**

```json
{
  "event": "payment.completed",
  "data": {
    "orderId": "ORDER_ABC",
    "paymentId": "FIRESTORE_DOC_ID",
    "transactionHash": "0x...",
    "amount": 12.5,
    "assetCode": "USDC",
    "status": "completed",
    "timestamp": "2026-01-15T12:00:00.000Z"
  },
  "timestamp": "2026-01-15T12:00:00.000Z"
}
```

**Signature (optional)**

If you provide `webhookSecret`, the backend includes:

- Header: `X-Webhook-Signature: sha256=<hex>`

To verify, compute:

```
HMAC_SHA256(webhookSecret, rawBody)
```

Compare the hex digest with the header value.

---

## 3) Verify Payment by Order ID (Polling)

Use the API key to check payment status if you do not use webhooks, or as a
fallback.

**Endpoint**

`GET <BACKEND_URL>/api/store-payment/verify/:orderId`

**Headers**

- `X-API-Key: <YOUR_API_KEY>`

or

- `Authorization: Bearer <YOUR_API_KEY>`

**Response (not paid)**

```json
{
  "success": true,
  "verified": false,
  "orderId": "ORDER_ABC",
  "message": "No payment found for this order"
}
```

**Response (paid)**

```json
{
  "success": true,
  "verified": true,
  "payment": {
    "id": "FIRESTORE_DOC_ID",
    "orderId": "ORDER_ABC",
    "transactionHash": "0x...",
    "amount": 12.5,
    "assetCode": "USDC",
    "status": "completed",
    "recipientAddress": "0x...",
    "senderAddress": "0x...",
    "createdAt": "2026-01-15T12:00:00.000Z"
  }
}
```

---

## Recommended Store Flow

1) Create order in your system (status: `pending`).
2) User pays using the wallet in the Azix app.
3) Receive `payment.completed` webhook OR poll `/verify/:orderId`.
4) On success, mark order as `paid` or `completed` in your system.

---

## Testing Checklist

- Webhook URL reachable from backend.
- Signature verification works (if enabled).
- `/verify/:orderId` returns `verified: true` after payment confirmation.
- Orders updated correctly in your store system.

---

## Troubleshooting

- `409` on `/api/store-payment/store`: the transaction is still pending.
- `503` on `/api/store-payment/store`: backend Firestore or RPC not configured.
- `verified: false`: payment not stored yet (check webhook delivery or wait).


