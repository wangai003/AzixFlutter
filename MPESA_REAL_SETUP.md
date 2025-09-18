# M-Pesa Real Transactions Setup Guide

## 🚀 **REAL M-PESA TRANSACTIONS - NO MORE MOCKS!**

This guide will help you set up **actual M-Pesa transactions** for your Flutter app. No more mock responses - real money, real transactions!

---

## 📋 **Prerequisites**

### 1. **M-Pesa Developer Account**
1. Visit [Safaricom Developer Portal](https://developer.safaricom.co.ke/)
2. Create an account and log in
3. Create a new app for your project
4. Note down your credentials (we'll use them in Step 3)

### 2. **Development Environment**
- ✅ Flutter SDK installed
- ✅ Android Studio / VS Code
- ✅ Chrome browser (for web development)
- ✅ Node.js installed (for CORS proxy)

---

## 🔧 **Step 1: Configure M-Pesa Credentials**

### **Get Your Credentials**
1. Go to [Safaricom Developer Portal](https://developer.safaricom.co.ke/)
2. Navigate to your app dashboard
3. Copy these values:
   - **Consumer Key**
   - **Consumer Secret**
   - **Pass Key**
   - **Short Code**
   - **Callback URL**

### **Update Flutter Code**
Open `lib/services/enhanced_mpesa_service.dart` and replace the placeholder values:

```dart
// 🔴 REPLACE THESE WITH YOUR REAL CREDENTIALS
static const String _consumerKey = 'YOUR_ACTUAL_CONSUMER_KEY_HERE';
static const String _consumerSecret = 'YOUR_ACTUAL_CONSUMER_SECRET_HERE';
static const String _passKey = 'YOUR_ACTUAL_PASS_KEY_HERE';
static const String _shortCode = 'YOUR_ACTUAL_SHORT_CODE_HERE';
static const String _callbackUrl = 'YOUR_ACTUAL_CALLBACK_URL_HERE';
```

**Example:**
```dart
static const String _consumerKey = 'GtX9FWtHQ8wZGKwHvKQ1234567890abcdef';
static const String _consumerSecret = 'abcDEF1234567890ghijklmnopQRSTUV';
static const String _passKey = 'SuperSecretPassKeyFromSafaricom';
static const String _shortCode = '174379';
static const String _callbackUrl = 'https://yourdomain.com/mpesa/callback';
```

---

## 🌐 **Step 2: Handle CORS for Web Development**

Since you're running on web, you need to bypass CORS restrictions.

### **Option A: Browser Extension (Quick & Easy)**

#### **Chrome:**
1. Install "Allow CORS" extension: https://chrome.google.com/webstore/detail/allow-cors-access-control/lhobafahddgcelffkeicbaginigeejlf
2. Or install "CORS Unblock": https://chrome.google.com/webstore/detail/cors-unblock/lfhmikememgdcahcdlaciloancbhjagp

#### **Firefox:**
1. Install "CORS Everywhere": https://addons.mozilla.org/en-US/firefox/addon/cors-everywhere/

#### **How to Use:**
1. Install the extension
2. **Enable it** when testing M-Pesa payments
3. The extension will automatically handle CORS

### **Option B: Local CORS Proxy (Recommended for Development)**

#### **Install CORS Proxy:**
```bash
# Install cors-anywhere globally
npm install -g cors-anywhere

# Start the proxy server
cors-anywhere

# The proxy will run on http://localhost:8080
```

#### **Update API URLs (Optional):**
If you want to use the proxy, update the URLs in `enhanced_mpesa_service.dart`:

```dart
// Add proxy URL
static const String _proxyUrl = 'http://localhost:8080/';

// Update API endpoints
static const String _baseUrl = '$_proxyUrlhttps://sandbox.safaricom.co.ke';
```

---

## 📱 **Step 3: Test Real Transactions**

### **For Web Development:**
1. **Start your Flutter web app:**
   ```bash
   flutter run -d chrome
   ```

2. **Enable CORS extension** in your browser

3. **Test M-Pesa purchase:**
   - Go to wallet section
   - Click "Purchase AKOFA"
   - Enter phone number (254XXXXXXXXX)
   - Enter amount (KES 100 minimum)
   - Click purchase

4. **Check your phone** for M-Pesa STK Push notification

### **For Mobile Development:**
1. **No CORS setup needed!**
   ```bash
   flutter run -d android  # or ios
   ```

2. **Test directly on device/emulator**

---

## 🔍 **Step 4: Monitor Transactions**

### **Check Logs:**
Your console will show detailed logs:
```
💰 Initiating M-Pesa STK Push for 100 KES
🔐 Requesting M-Pesa access token...
📥 OAuth Response: 200
✅ Access token obtained successfully
📤 Sending STK Push request to M-Pesa API
📥 M-Pesa API Response: 200
✅ STK Push initiated successfully
```

### **Check Firestore:**
Transactions are stored in `mpesa_transactions` collection:
```json
{
  "userId": "user123",
  "phoneNumber": "254712345678",
  "amountKES": 100,
  "akofaAmount": 1.0,
  "checkoutRequestId": "ws_CO_1234567890",
  "status": "pending",
  "timestamp": "2025-01-10T10:00:00Z"
}
```

### **Query Payment Status:**
```dart
// After receiving STK Push on phone
final result = await mpesaService.queryPaymentStatus(checkoutRequestId);

// Result will show:
// - success: true/false
// - status: "completed" or "failed"
// - message: User-friendly message
```

---

## 🚨 **Troubleshooting**

### **Common Issues:**

#### **1. CORS Error Still Occurring:**
```bash
# Make sure CORS proxy is running
cors-anywhere

# Or check if browser extension is enabled
```

#### **2. Authentication Failed:**
```json
// Check your credentials in Safaricom portal
{
  "error": "Failed to get access token: 400"
}
```
**Solution:** Verify Consumer Key and Secret are correct

#### **3. STK Push Failed:**
```json
{
  "error": "Failed to initiate payment: Invalid short code"
}
```
**Solution:** Check your Short Code in developer portal

#### **4. Payment Not Received:**
- Check phone number format: `254XXXXXXXXX`
- Verify M-Pesa balance
- Check if STK Push was sent to correct number

### **Debug Commands:**

```dart
// Test OAuth token
final token = await mpesaService._getAccessToken();
print('Token: $token');

// Test STK Push
final result = await mpesaService.initiateSTKPush(
  phoneNumber: '254712345678',
  amount: 100,
  accountReference: 'TEST_001',
  akofaAmount: 1.0,
);
print('STK Result: $result');
```

---

## 💰 **Step 5: Handle Real Money**

### **Important Security Notes:**

1. **Never expose credentials** in client-side code
2. **Use HTTPS** in production
3. **Validate all inputs** (phone numbers, amounts)
4. **Implement proper error handling**
5. **Log transactions** for auditing

### **Production Considerations:**

#### **Backend Service (Recommended):**
For production, create a backend service:
```javascript
// Node.js/Express example
app.post('/mpesa/stkpush', async (req, res) => {
  // Handle M-Pesa API calls server-side
  const response = await axios.post('https://api.safaricom.co.ke/...', req.body);
  res.json(response.data);
});
```

#### **Environment Variables:**
```dart
// Use environment variables instead of hardcoded values
static const String _consumerKey = String.fromEnvironment('MPESA_CONSUMER_KEY');
static const String _consumerSecret = String.fromEnvironment('MPESA_CONSUMER_SECRET');
```

---

## 🎯 **Success Indicators**

### **✅ Successful Transaction Flow:**

1. **User clicks "Purchase AKOFA"**
2. **App requests OAuth token** → `200 OK`
3. **App sends STK Push request** → `200 OK`
4. **User receives M-Pesa notification** on phone
5. **User enters M-Pesa PIN**
6. **Payment processes** → Success/Failure
7. **App queries payment status** → `ResultCode: 0`
8. **AKOFA tokens credited** to wallet
9. **User receives success notification**

### **📊 Expected Logs:**
```
💰 Initiating M-Pesa STK Push for 100 KES
🔐 Requesting M-Pesa access token...
✅ Access token obtained successfully
📤 Sending STK Push request to M-Pesa API
✅ STK Push initiated successfully
🔍 Querying M-Pesa payment status...
💰 Payment successful - crediting AKOFA tokens
✅ AKOFA tokens credited successfully
```

---

## 🚀 **Next Steps**

### **For Development:**
- ✅ Test with small amounts (KES 100)
- ✅ Verify phone number receives STK Push
- ✅ Test successful and failed payments
- ✅ Check Firestore transaction records

### **For Production:**
- 🔄 Move API calls to backend service
- 🔄 Use environment variables for credentials
- 🔄 Implement comprehensive error handling
- 🔄 Add transaction monitoring and alerts
- 🔄 Set up proper logging and auditing

---

## 📞 **Support**

### **M-Pesa Resources:**
- [Safaricom Developer Portal](https://developer.safaricom.co.ke/)
- [M-Pesa API Documentation](https://developer.safaricom.co.ke/docs)
- [Sandbox Testing Guide](https://developer.safaricom.co.ke/test)

### **Common Issues:**
- **400 Bad Request**: Check credentials and request format
- **401 Unauthorized**: Verify Consumer Key/Secret
- **CORS Error**: Use proxy or browser extension
- **Timeout**: Check internet connection

---

## 🎉 **Congratulations!**

You now have **real M-Pesa transactions** working in your Flutter app! 🎯💰

**Test it out:**
1. Configure your credentials
2. Set up CORS proxy/extension
3. Try purchasing AKOFA tokens
4. Watch real money flow! 🚀

**Remember:** Start with small test amounts and monitor your transactions closely. Happy coding! 👨‍💻