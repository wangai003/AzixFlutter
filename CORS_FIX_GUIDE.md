# 🚫 CORS Error Fix - M-Pesa Web Integration

## ❌ **The Problem:**
```
Access to fetch at 'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials'
from origin 'http://localhost:64309' has been blocked by CORS policy:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

**This is expected!** M-Pesa APIs don't allow direct browser requests due to security policies.

---

## ✅ **SOLUTION 1: Browser Extension (Quickest)**

### **Chrome - "Allow CORS" Extension:**
1. **Install Extension:**
   - Visit: https://chrome.google.com/webstore/detail/allow-cors-access-control/lhobafahddgcelffkeicbaginigeejlf
   - Click "Add to Chrome"

2. **Enable Extension:**
   - Click the extension icon in toolbar
   - Toggle "Allow CORS" to **ON** (green)
   - The icon should show "CORS: ✅"

3. **Test:**
   ```bash
   flutter run -d chrome
   ```
   - Go to wallet → Purchase AKOFA
   - Phone: `254708374149`
   - Amount: `100 KES`
   - Click purchase

### **Firefox - "CORS Everywhere" Extension:**
1. **Install:** https://addons.mozilla.org/en-US/firefox/addon/cors-everywhere/
2. **Enable:** Click extension icon → Enable
3. **Test:** Same as above

---

## ✅ **SOLUTION 2: Local CORS Proxy (Recommended)**

### **Step 1: Install CORS Proxy**
```bash
# Install globally
npm install -g cors-anywhere

# Start proxy server (runs on port 8080)
cors-anywhere

# You should see:
# Running CORS Anywhere on http://localhost:8080
```

### **Step 2: Update Flutter Code**
```dart
// In lib/services/enhanced_mpesa_service.dart
// Add proxy URL
static const String _proxyUrl = 'http://localhost:8080/';

// Update API endpoints to use proxy
static String get _baseUrl => _useSandbox
    ? '$_proxyUrlhttps://sandbox.safaricom.co.ke'
    : '$_proxyUrlhttps://api.safaricom.co.ke';
```

### **Step 3: Test**
```bash
# Terminal 1: Start proxy
cors-anywhere

# Terminal 2: Run Flutter
flutter run -d chrome
```

---

## ✅ **SOLUTION 3: Test on Mobile (No CORS Issues)**

### **Android:**
```bash
flutter run -d android
```
- No CORS proxy needed
- Direct API calls work perfectly

### **iOS:**
```bash
flutter run -d ios
```
- No CORS proxy needed
- Direct API calls work perfectly

---

## ✅ **SOLUTION 4: Backend Proxy (Production Ready)**

### **For Production - Create Backend Service:**

#### **Node.js/Express Example:**
```javascript
// server.js
const express = require('express');
const axios = require('axios');
const cors = require('cors');

const app = express();
app.use(cors());

app.post('/mpesa/stkpush', async (req, res) => {
  try {
    const response = await axios.post(
      'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/process',
      req.body,
      {
        headers: {
          'Authorization': `Bearer ${process.env.MPESA_ACCESS_TOKEN}`,
          'Content-Type': 'application/json'
        }
      }
    );
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, () => console.log('Backend proxy running on port 3000'));
```

#### **Update Flutter Code:**
```dart
// Use your backend instead of direct M-Pesa API
static const String _stkPushUrl = 'http://localhost:3000/mpesa/stkpush';
```

---

## 🔧 **Quick Fix Commands:**

### **Option A: Browser Extension (2 minutes)**
```bash
# 1. Install Chrome extension: "Allow CORS"
# 2. Enable it (green toggle)
# 3. Run Flutter
flutter run -d chrome
```

### **Option B: CORS Proxy (5 minutes)**
```bash
# 1. Install proxy
npm install -g cors-anywhere

# 2. Start proxy
cors-anywhere

# 3. Update code (add proxy URL)
# 4. Run Flutter
flutter run -d chrome
```

### **Option C: Mobile Testing (Immediate)**
```bash
# No setup needed!
flutter run -d android  # or ios
```

---

## 📊 **Expected Results After Fix:**

### **✅ Success Logs:**
```
🌐 M-Pesa Environment: 🧪 SANDBOX
💰 Initiating AKOFA purchase: 100 KES = 1.0 AKOFA
🔐 Requesting M-Pesa access token...
✅ Access token obtained successfully
📤 Sending STK Push request to M-Pesa API
✅ STK Push initiated successfully
📱 Check your phone for M-Pesa prompt!
```

### **📱 Phone Experience:**
- You'll receive a real M-Pesa STK Push notification
- Enter your M-Pesa PIN
- Transaction completes
- AKOFA tokens credited to wallet

---

## 🚨 **Troubleshooting:**

### **"Proxy not working":**
```bash
# Kill existing proxy
pkill -f cors-anywhere

# Restart proxy
cors-anywhere
```

### **"Extension not working":**
- Make sure extension is **enabled** (green)
- Try refreshing the browser
- Check if other extensions are interfering

### **"Still getting CORS error":**
- Verify proxy is running on port 8080
- Check if you're using the correct proxy URL
- Try a different browser

---

## 🎯 **Which Solution Should You Use?**

| Solution | Time | Best For | Production Ready |
|----------|------|----------|------------------|
| **Browser Extension** | 2 min | Quick testing | ❌ No |
| **CORS Proxy** | 5 min | Development | ⚠️ Partial |
| **Mobile Testing** | 1 min | All testing | ✅ Yes |
| **Backend Proxy** | 30 min | Production | ✅ Yes |

### **My Recommendation:**
1. **For immediate testing:** Use **mobile** (`flutter run -d android`)
2. **For web development:** Use **CORS proxy**
3. **For production:** Use **backend proxy**

---

## 🎉 **Ready to Test?**

**Choose your solution and test now!** 🚀

### **Quick Test (Mobile):**
```bash
flutter run -d android
# No CORS issues!
```

### **Web with Proxy:**
```bash
# Terminal 1
cors-anywhere

# Terminal 2
flutter run -d chrome
```

**Questions?** All solutions are documented above! 

**Happy testing!** 🎯📱