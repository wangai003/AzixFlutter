# 🌐 Flutter Web + M-Pesa Integration Guide

## 🎯 **Web-Specific Solutions for CORS Issues**

Since your app is **Flutter Web**, here are the **best solutions** tailored specifically for web deployment:

---

## ✅ **SOLUTION 1: CORS Proxy (Recommended for Web)**

### **Why This Works Best for Flutter Web:**
- ✅ **Bypasses browser CORS restrictions**
- ✅ **Works with all browsers**
- ✅ **No browser extensions needed**
- ✅ **Production-ready approach**

### **Step-by-Step Setup:**

#### **1. Install CORS Proxy**
```bash
# Install globally (one time)
npm install -g cors-anywhere

# Verify installation
cors-anywhere --version
```

#### **2. Enable Proxy in Your Code**
```dart
// In lib/services/enhanced_mpesa_service.dart
static const bool _useCorsProxy = true; // ✅ ENABLE THIS
```

#### **3. Start Proxy Server**
```bash
# Start CORS proxy (keep this running)
cors-anywhere

# You should see:
# Running CORS Anywhere on http://localhost:8080
```

#### **4. Test Your App**
```bash
# Terminal 1: Keep proxy running
cors-anywhere

# Terminal 2: Run Flutter Web
flutter run -d chrome
```

### **Expected Success Output:**
```
🌐 M-Pesa Environment: 🧪 SANDBOX | 🌐 WITH CORS PROXY
🔗 Proxy URL: http://localhost:8080/
💰 Initiating AKOFA purchase: 100 KES = 1.0 AKOFA
🔐 Requesting M-Pesa access token...
✅ Access token obtained successfully
📤 Sending STK Push request to M-Pesa API
✅ STK Push initiated successfully
📱 Check your phone for M-Pesa prompt!
```

---

## ✅ **SOLUTION 2: Browser Extensions (Quick Testing)**

### **For Chrome:**
1. **Install Extension:**
   - Visit: https://chrome.google.com/webstore/detail/allow-cors-access-control/lhobafahddgcelffkeicbaginigeejlf
   - Click "Add to Chrome"

2. **Enable for Testing:**
   - Click extension icon in toolbar
   - Toggle "Allow CORS: ON" (should be green)
   - Icon shows: "CORS: ✅"

3. **Test:**
   ```bash
   flutter run -d chrome
   ```

### **For Firefox:**
1. **Install Extension:**
   - Visit: https://addons.mozilla.org/en-US/firefox/addon/cors-everywhere/
   - Click "Add to Firefox"

2. **Enable:** Click extension icon → Enable

### **For Edge:**
1. **Install Extension:**
   - Visit: https://microsoftedge.microsoft.com/addons/detail/allow-cors-access-contro/omdbclllcmbdgngmddgilfhldkooeglm
   - Click "Get"

---

## ✅ **SOLUTION 3: Custom Backend Proxy (Production)**

### **Create a Simple Node.js Proxy:**

#### **1. Create Backend Service**
```javascript
// mpesa-proxy.js
const express = require('express');
const axios = require('axios');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// M-Pesa STK Push proxy
app.post('/mpesa/stkpush', async (req, res) => {
  try {
    // Get access token first
    const auth = Buffer.from(
      `${process.env.MPESA_CONSUMER_KEY}:${process.env.MPESA_CONSUMER_SECRET}`
    ).toString('base64');

    const tokenResponse = await axios.get(
      'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials',
      {
        headers: { 'Authorization': `Basic ${auth}` }
      }
    );

    const accessToken = tokenResponse.data.access_token;

    // Make STK Push request
    const stkResponse = await axios.post(
      'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest',
      req.body,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    res.json(stkResponse.data);
  } catch (error) {
    console.error('M-Pesa Proxy Error:', error.response?.data || error.message);
    res.status(500).json({
      error: error.response?.data || error.message
    });
  }
});

// M-Pesa query proxy
app.post('/mpesa/query', async (req, res) => {
  try {
    const auth = Buffer.from(
      `${process.env.MPESA_CONSUMER_KEY}:${process.env.MPESA_CONSUMER_SECRET}`
    ).toString('base64');

    const tokenResponse = await axios.get(
      'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials',
      { headers: { 'Authorization': `Basic ${auth}` } }
    );

    const accessToken = tokenResponse.data.access_token;

    const queryResponse = await axios.post(
      'https://sandbox.safaricom.co.ke/mpesa/stkpushquery/v1/query',
      req.body,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    res.json(queryResponse.data);
  } catch (error) {
    res.status(500).json({
      error: error.response?.data || error.message
    });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`M-Pesa proxy running on port ${PORT}`);
});
```

#### **2. Environment Variables**
```bash
# .env file
MPESA_CONSUMER_KEY=your_consumer_key_here
MPESA_CONSUMER_SECRET=your_consumer_secret_here
```

#### **3. Update Flutter Code**
```dart
// In lib/services/enhanced_mpesa_service.dart
static const String _customBackendUrl = 'http://localhost:3001';

static String get _stkPushUrl => '$_customBackendUrl/mpesa/stkpush';
static String get _queryUrl => '$_customBackendUrl/mpesa/query';
```

#### **4. Run Backend**
```bash
# Install dependencies
npm install express axios cors dotenv

# Start backend
node mpesa-proxy.js
```

---

## 🚀 **Quick Start Commands for Flutter Web:**

### **Option A: CORS Proxy (Most Reliable)**
```bash
# Terminal 1: Start CORS proxy
cors-anywhere

# Terminal 2: Enable proxy in code (_useCorsProxy = true)

# Terminal 3: Run Flutter Web
flutter run -d chrome
```

### **Option B: Browser Extension (Quickest)**
```bash
# 1. Install "Allow CORS" extension
# 2. Enable extension (green toggle)
# 3. Run Flutter Web
flutter run -d chrome
```

### **Option C: Custom Backend (Production-Ready)**
```bash
# Terminal 1: Start backend proxy
node mpesa-proxy.js

# Terminal 2: Update Flutter code to use backend URLs

# Terminal 3: Run Flutter Web
flutter run -d chrome
```

---

## 🔧 **Flutter Web-Specific Configuration:**

### **Web Build Configuration:**
```yaml
# web/index.html - Add this for better CORS handling
<meta http-equiv="Cross-Origin-Opener-Policy" content="same-origin">
<meta http-equiv="Cross-Origin-Embedder-Policy" content="require-corp">
```

### **Flutter Web Renderer:**
```yaml
# In pubspec.yaml - Use HTML renderer for better web compatibility
flutter:
  web:
    renderer: html
```

---

## 🌐 **Flutter Web Deployment Considerations:**

### **For Development:**
- ✅ Use **CORS proxy** or **browser extensions**
- ✅ Test on `localhost` first
- ✅ Use sandbox credentials

### **For Production:**
- ✅ Deploy **backend proxy service**
- ✅ Use **production M-Pesa credentials**
- ✅ Configure proper domains in M-Pesa portal
- ✅ Use HTTPS for all requests

### **Web Hosting Services:**
```bash
# Firebase Hosting
firebase init hosting
firebase deploy

# Vercel
vercel --prod

# Netlify
netlify deploy --prod
```

---

## 📊 **Testing Checklist for Flutter Web:**

### **✅ Development Testing:**
- [ ] CORS proxy running on port 8080
- [ ] `_useCorsProxy = true` in code
- [ ] Flutter Web running on Chrome
- [ ] M-Pesa test phone number: `254708374149`
- [ ] Test amount: `100 KES`

### **✅ Production Testing:**
- [ ] Backend proxy deployed
- [ ] Production M-Pesa credentials configured
- [ ] HTTPS enabled
- [ ] Domain whitelisted in M-Pesa portal

---

## 🚨 **Common Flutter Web Issues & Fixes:**

### **Issue: "CORS proxy not working"**
```bash
# Solution: Check if proxy is running
curl http://localhost:8080/https://httpbin.org/get

# Restart proxy
pkill -f cors-anywhere
cors-anywhere
```

### **Issue: "Extension not working"**
- ✅ Make sure extension is **enabled** (green)
- ✅ Try **incognito mode**
- ✅ Check for conflicting extensions
- ✅ Try different browser

### **Issue: "Web app not loading"**
```bash
# Clear Flutter web cache
flutter clean
flutter pub get

# Run with specific port
flutter run -d chrome --web-port=3000
```

---

## 🎯 **Recommended Workflow for Flutter Web:**

### **Phase 1: Development (Current)**
```bash
✅ Use CORS proxy for development
✅ Test with sandbox credentials
✅ Verify STK Push works on phone
✅ Debug UI/UX flows
```

### **Phase 2: Staging**
```bash
🔄 Deploy backend proxy to staging
🔄 Test with production credentials
🔄 Verify on multiple browsers
🔄 Test real transactions (small amounts)
```

### **Phase 3: Production**
```bash
💰 Deploy to production hosting
💰 Enable real M-Pesa payments
💰 Monitor transactions
💰 Handle customer support
```

---

## 📞 **Support & Resources:**

### **M-Pesa Resources:**
- [Safaricom Developer Portal](https://developer.safaricom.co.ke/)
- [M-Pesa API Documentation](https://developer.safaricom.co.ke/docs)
- [Sandbox Testing Guide](https://developer.safaricom.co.ke/test)

### **Flutter Web Resources:**
- [Flutter Web Documentation](https://flutter.dev/web)
- [CORS Anywhere GitHub](https://github.com/Rob--W/cors-anywhere)
- [Flutter Web Deployment](https://flutter.dev/docs/deployment/web)

---

## 🎉 **Ready to Test on Flutter Web?**

**Your app is now ready for Flutter Web with M-Pesa!** 🚀

### **Quick Test:**
```bash
# 1. Start CORS proxy
cors-anywhere

# 2. Enable proxy in code (_useCorsProxy = true)

# 3. Run Flutter Web
flutter run -d chrome

# 4. Test purchase with phone: 254708374149
```

**Questions?** All web-specific solutions are documented above!

**Happy Flutter Web development!** 🌐✨