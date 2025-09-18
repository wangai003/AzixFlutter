# M-Pesa Integration Guide

## Overview
This document explains how to handle M-Pesa integration in Flutter applications, particularly addressing CORS issues when running on web platforms.

## The CORS Issue

When running Flutter web applications, direct HTTP requests to external APIs (like M-Pesa) are blocked by CORS (Cross-Origin Resource Sharing) policy. This is a browser security feature.

### Error Example:
```
Access to fetch at 'https://sandbox.safaricom.co.ke/oauth/v1/generate' has been blocked by CORS policy
```

## Solutions

### 1. Development Solutions

#### Option A: Use Mock Responses (Current Implementation)
The app automatically detects web platform and uses mock M-Pesa responses for development:

```dart
if (kIsWeb) {
  return await _initiateMockSTKPush(...);
}
```

**Pros:**
- ✅ Works immediately
- ✅ No external dependencies
- ✅ Safe for development

**Cons:**
- ❌ Not real M-Pesa integration
- ❌ Can't test real payments

#### Option B: CORS Proxy Extension
Install a browser extension to disable CORS for development:

**Chrome:** "Allow CORS" or "CORS Unblock"
**Firefox:** "CORS Everywhere"

**Pros:**
- ✅ Real M-Pesa API calls
- ✅ Test actual payment flow

**Cons:**
- ❌ Security risk (disable CORS)
- ❌ Not suitable for production

#### Option C: Local CORS Proxy
Set up a local proxy server:

```bash
# Using cors-anywhere
npm install -g cors-anywhere
cors-anywhere

# Then modify API URLs to go through proxy
const proxyUrl = 'http://localhost:8080/';
const apiUrl = proxyUrl + 'https://sandbox.safaricom.co.ke/...';
```

### 2. Production Solution

#### Backend Service (Recommended)
Create a backend service to handle M-Pesa API calls:

**Architecture:**
```
Flutter App → Your Backend → M-Pesa API
```

**Implementation Steps:**

1. **Create Backend Service:**
   ```javascript
   // Node.js/Express example
   const express = require('express');
   const axios = require('axios');

   app.post('/mpesa/stkpush', async (req, res) => {
     try {
       const response = await axios.post(
         'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest',
         req.body,
         {
           headers: {
             'Authorization': `Bearer ${accessToken}`,
             'Content-Type': 'application/json'
           }
         }
       );
       res.json(response.data);
     } catch (error) {
       res.status(500).json({ error: error.message });
     }
   });
   ```

2. **Update Flutter App:**
   ```dart
   // Replace direct API calls with backend calls
   static const String _stkPushUrl = 'https://your-backend.com/mpesa/stkpush';
   ```

3. **Security Benefits:**
   - API keys stored securely on backend
   - No CORS issues
   - Better error handling
   - Request/response logging

## Configuration

### 1. Get M-Pesa Credentials

1. Visit [Safaricom Developer Portal](https://developer.safaricom.co.ke/)
2. Create an app and get:
   - Consumer Key
   - Consumer Secret
   - Pass Key
   - Short Code
   - Callback URL

### 2. Environment Variables

**For Development:**
```dart
// Use environment variables instead of hardcoded values
static const String _consumerKey = String.fromEnvironment('MPESA_CONSUMER_KEY');
static const String _consumerSecret = String.fromEnvironment('MPESA_CONSUMER_SECRET');
```

**For Production:**
Store credentials securely in your backend service.

### 3. Platform-Specific Configuration

```dart
// Detect platform and configure accordingly
if (kIsWeb) {
  // Use mock responses or proxy
} else if (Platform.isAndroid || Platform.isIOS) {
  // Direct API calls work fine
}
```

## Testing

### Mock Testing
```dart
// Test with mock responses
final result = await mpesaService.purchaseAkofaTokens(
  phoneNumber: '254712345678',
  amountKES: 100,
);

// Mock response includes 'mock: true' flag
if (result['mock'] == true) {
  print('Using mock M-Pesa for testing');
}
```

### Real API Testing
```dart
// Test with real M-Pesa (requires CORS proxy or backend)
final result = await mpesaService.purchaseAkofaTokens(
  phoneNumber: '254712345678',
  amountKES: 100,
);
```

## Security Considerations

### 1. Never Expose Credentials
- ❌ Don't hardcode API keys in client code
- ✅ Use environment variables
- ✅ Store credentials on backend
- ✅ Use secure key management

### 2. Validate Inputs
```dart
// Always validate phone numbers and amounts
String? formattedPhone = _formatPhoneNumber(phoneNumber);
if (formattedPhone == null) {
  return {'success': false, 'error': 'Invalid phone number'};
}
```

### 3. Handle Errors Gracefully
```dart
try {
  final result = await mpesaService.purchaseAkofaTokens(...);
  if (!result['success']) {
    // Show user-friendly error message
    showErrorDialog(result['error']);
  }
} catch (e) {
  // Handle network errors, CORS issues, etc.
  showErrorDialog('Network error. Please try again.');
}
```

## Troubleshooting

### Common Issues:

1. **CORS Error on Web:**
   - Solution: Use mock responses or CORS proxy

2. **Invalid Credentials:**
   - Solution: Verify API keys in Safaricom portal

3. **Network Timeout:**
   - Solution: Increase timeout values for slow connections

4. **Invalid Phone Number:**
   - Solution: Ensure proper formatting (254XXXXXXXXX)

### Debug Tips:

```dart
// Enable detailed logging
if (kDebugMode) {
  print('M-Pesa Debug: $debugInfo');
}

// Check platform
print('Platform: ${kIsWeb ? 'Web' : 'Mobile'}');

// Test API connectivity
final testResult = await _testMpesaConnection();
```

## Migration Path

### From Development to Production:

1. **Phase 1: Mock Integration**
   - Use current mock implementation
   - Test UI/UX flow
   - Validate business logic

2. **Phase 2: Backend Setup**
   - Create backend service
   - Move API calls to backend
   - Test with real credentials

3. **Phase 3: Production Deployment**
   - Deploy backend service
   - Update API endpoints
   - Enable real payments

## Conclusion

The current implementation provides a solid foundation for M-Pesa integration with proper CORS handling for web development. For production, implement a backend service to handle API calls securely and avoid CORS issues entirely.

**Remember:** Always prioritize security and never expose sensitive API credentials in client-side code.