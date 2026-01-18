# External Store Integration Guide

## Overview

This guide explains how external stores (websites, platforms) can integrate with the AzixFlutter payment system to receive payment confirmations when customers pay using their wallet.

## Integration Methods

External stores can confirm payments using two methods:

1. **Webhook Notifications** (Recommended) - Real-time notifications when payments are completed
2. **API Polling** - Query payment status by order ID

## Method 1: Webhook Notifications (Recommended)

### Step 1: Register Your Store

Register your store to receive webhook notifications:

```bash
POST https://your-backend-url.com/api/store-payment/stores/{storeId}/webhook
Content-Type: application/json

{
  "webhookUrl": "https://your-store.com/api/payments/webhook",
  "webhookSecret": "your-secret-key-for-signature-verification",
  "storeName": "My Store Name"
}
```

**Response:**
```json
{
  "success": true,
  "storeId": "STORE-001",
  "apiKey": "generated-api-key-here",
  "message": "Store webhook registered successfully"
}
```

**Important:** Save the `apiKey` - you'll need it for payment verification!

### Step 2: Receive Webhook Notifications

When a customer completes a payment, you'll receive a POST request to your webhook URL:

**Webhook Payload:**
```json
{
  "event": "payment.completed",
  "data": {
    "orderId": "ORD-12345",
    "paymentId": "payment-abc123",
    "transactionHash": "stellar-tx-hash-here",
    "amount": 100.0,
    "assetCode": "AKOFA",
    "status": "completed",
    "timestamp": "2024-01-01T12:00:00Z"
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Headers:**
```
Content-Type: application/json
User-Agent: AzixFlutter-StorePayment/1.0
X-Webhook-Signature: sha256=<hmac-signature>  (if webhookSecret provided)
```

### Step 3: Verify Webhook Signature (Optional but Recommended)

If you provided a `webhookSecret` during registration, verify the signature:

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, secret) {
  const hmac = crypto.createHmac('sha256', secret);
  const expectedSignature = 'sha256=' + hmac.update(JSON.stringify(payload)).digest('hex');
  return signature === expectedSignature;
}

// In your webhook handler
app.post('/api/payments/webhook', (req, res) => {
  const signature = req.headers['x-webhook-signature'];
  const payload = req.body;
  
  if (!verifyWebhookSignature(payload, signature, process.env.WEBHOOK_SECRET)) {
    return res.status(401).json({ error: 'Invalid signature' });
  }
  
  // Process payment...
  res.json({ success: true });
});
```

### Step 4: Process the Payment

When you receive a webhook:

1. **Verify the signature** (if using webhookSecret)
2. **Check if order exists** in your system
3. **Update order status** to "paid"
4. **Fulfill the order** (ship products, activate services, etc.)
5. **Return 200 OK** to acknowledge receipt

**Example Webhook Handler (Node.js/Express):**

```javascript
app.post('/api/payments/webhook', async (req, res) => {
  try {
    const { event, data } = req.body;
    
    if (event !== 'payment.completed') {
      return res.status(400).json({ error: 'Unknown event type' });
    }
    
    const { orderId, transactionHash, amount, assetCode } = data;
    
    // Find order in your database
    const order = await db.orders.findOne({ orderId });
    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }
    
    // Verify payment amount matches
    if (order.amount !== amount) {
      console.error('Payment amount mismatch!');
      return res.status(400).json({ error: 'Amount mismatch' });
    }
    
    // Update order status
    await db.orders.updateOne(
      { orderId },
      {
        $set: {
          paymentStatus: 'completed',
          paymentTransactionHash: transactionHash,
          paidAt: new Date(),
        }
      }
    );
    
    // Fulfill order (ship, activate, etc.)
    await fulfillOrder(orderId);
    
    res.json({ success: true, message: 'Payment processed' });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

## Method 2: API Polling

If you prefer to poll for payment status instead of receiving webhooks:

### Verify Payment by Order ID

```bash
GET https://your-backend-url.com/api/store-payment/verify/{orderId}
Headers:
  X-API-Key: your-api-key-here
  # OR
  Authorization: Bearer your-api-key-here
```

**Response (Payment Found):**
```json
{
  "success": true,
  "verified": true,
  "payment": {
    "id": "payment-abc123",
    "orderId": "ORD-12345",
    "transactionHash": "stellar-tx-hash-here",
    "amount": 100.0,
    "assetCode": "AKOFA",
    "status": "completed",
    "recipientAddress": "G...",
    "senderAddress": "G...",
    "createdAt": "2024-01-01T12:00:00Z"
  }
}
```

**Response (No Payment Found):**
```json
{
  "success": true,
  "verified": false,
  "orderId": "ORD-12345",
  "message": "No payment found for this order"
}
```

### Polling Implementation Example

```javascript
async function checkPaymentStatus(orderId, apiKey, maxAttempts = 30) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const response = await fetch(
        `https://your-backend-url.com/api/store-payment/verify/${orderId}`,
        {
          headers: {
            'X-API-Key': apiKey,
          },
        }
      );
      
      const data = await response.json();
      
      if (data.verified) {
        return {
          success: true,
          payment: data.payment,
        };
      }
      
      // Wait 5 seconds before next check
      await new Promise(resolve => setTimeout(resolve, 5000));
    } catch (error) {
      console.error('Payment check error:', error);
    }
  }
  
  return { success: false, message: 'Payment not found after max attempts' };
}

// Usage
const result = await checkPaymentStatus('ORD-12345', 'your-api-key');
if (result.success) {
  console.log('Payment confirmed:', result.payment);
}
```

## Complete Integration Example

### PHP Example

```php
<?php
// Register webhook
function registerStoreWebhook($storeId, $webhookUrl, $webhookSecret) {
    $ch = curl_init("https://your-backend-url.com/api/store-payment/stores/$storeId/webhook");
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'webhookUrl' => $webhookUrl,
        'webhookSecret' => $webhookSecret,
        'storeName' => 'My Store',
    ]));
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    
    $response = curl_exec($ch);
    curl_close($ch);
    
    return json_decode($response, true);
}

// Webhook handler
function handlePaymentWebhook($payload, $signature) {
    // Verify signature
    $expectedSignature = 'sha256=' . hash_hmac('sha256', json_encode($payload), $_ENV['WEBHOOK_SECRET']);
    
    if ($signature !== $expectedSignature) {
        http_response_code(401);
        die('Invalid signature');
    }
    
    if ($payload['event'] === 'payment.completed') {
        $orderId = $payload['data']['orderId'];
        $transactionHash = $payload['data']['transactionHash'];
        $amount = $payload['data']['amount'];
        
        // Update order in database
        updateOrderStatus($orderId, 'paid', $transactionHash);
        
        // Fulfill order
        fulfillOrder($orderId);
    }
    
    http_response_code(200);
    echo json_encode(['success' => true]);
}
?>
```

### Python Example

```python
import requests
import hmac
import hashlib
import json
from flask import Flask, request

app = Flask(__name__)

# Register webhook
def register_webhook(store_id, webhook_url, webhook_secret):
    response = requests.post(
        f'https://your-backend-url.com/api/store-payment/stores/{store_id}/webhook',
        json={
            'webhookUrl': webhook_url,
            'webhookSecret': webhook_secret,
            'storeName': 'My Store',
        }
    )
    return response.json()

# Webhook handler
@app.route('/api/payments/webhook', methods=['POST'])
def payment_webhook():
    payload = request.json
    signature = request.headers.get('X-Webhook-Signature')
    
    # Verify signature
    if signature:
        expected = 'sha256=' + hmac.new(
            os.environ['WEBHOOK_SECRET'].encode(),
            json.dumps(payload).encode(),
            hashlib.sha256
        ).hexdigest()
        
        if signature != expected:
            return {'error': 'Invalid signature'}, 401
    
    if payload['event'] == 'payment.completed':
        order_id = payload['data']['orderId']
        transaction_hash = payload['data']['transactionHash']
        
        # Update order status
        update_order_status(order_id, 'paid', transaction_hash)
        
        # Fulfill order
        fulfill_order(order_id)
    
    return {'success': True}, 200
```

## Security Best Practices

1. **Always verify webhook signatures** to ensure requests are from AzixFlutter
2. **Use HTTPS** for webhook URLs
3. **Store API keys securely** - never expose them in client-side code
4. **Validate payment amounts** match your order amounts
5. **Implement idempotency** - handle duplicate webhook deliveries
6. **Log all webhook events** for debugging and audit trails
7. **Set up retry logic** for failed webhook processing

## Testing

### Test Webhook Registration

```bash
curl -X POST https://your-backend-url.com/api/store-payment/stores/TEST-STORE/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "webhookUrl": "https://webhook.site/unique-id",
    "webhookSecret": "test-secret",
    "storeName": "Test Store"
  }'
```

### Test Payment Verification

```bash
curl https://your-backend-url.com/api/store-payment/verify/ORD-12345 \
  -H "X-API-Key: your-api-key"
```

### Test Webhook Locally

Use a service like [webhook.site](https://webhook.site) or [ngrok](https://ngrok.com) to test webhooks locally:

```bash
# Using ngrok
ngrok http 3000

# Register webhook with ngrok URL
curl -X POST https://your-backend-url.com/api/store-payment/stores/TEST-STORE/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "webhookUrl": "https://abc123.ngrok.io/api/payments/webhook",
    "webhookSecret": "test-secret"
  }'
```

## Error Handling

### Webhook Delivery Failures

If your webhook endpoint is unreachable or returns an error:
- The system will log the failure
- You should implement polling as a fallback
- Check your webhook endpoint is accessible from the internet

### Payment Verification Failures

If payment verification fails:
- Check API key is correct
- Verify order ID format
- Ensure payment was actually completed
- Check backend logs for details

## Support

For integration support:
- Check backend logs: Payment service logs webhook attempts
- Verify webhook URL is accessible
- Test with webhook.site or ngrok
- Contact support with your storeId and orderId

## API Reference

### Register Store Webhook
- **Endpoint:** `POST /api/store-payment/stores/:storeId/webhook`
- **Auth:** None (public registration)
- **Body:** `{ webhookUrl, webhookSecret?, storeName? }`

### Verify Payment
- **Endpoint:** `GET /api/store-payment/verify/:orderId`
- **Auth:** `X-API-Key` header or `Authorization: Bearer <key>`
- **Response:** Payment details or "not found"

### Get Store Config
- **Endpoint:** `GET /api/store-payment/stores/:storeId`
- **Auth:** `X-API-Key` header
- **Response:** Store configuration (without sensitive data)

