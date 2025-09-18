# M-Pesa: Sandbox → Production Switch Guide

## 🎯 **YES! You can absolutely use sandbox credentials for testing and then switch to real M-Pesa credentials!**

---

## 📋 **Current Setup (Sandbox Ready)**

Your app is currently configured to use **M-Pesa Sandbox** with working credentials:

```dart
// In lib/services/enhanced_mpesa_service.dart
static const bool _useSandbox = true; // ✅ Currently using SANDBOX
```

**Sandbox credentials are already configured and working!** 🎉

---

## 🧪 **Step 1: Test with Sandbox (FREE)**

### **What is M-Pesa Sandbox?**
- ✅ **Free testing environment** provided by Safaricom
- ✅ **Real API calls** (but no real money)
- ✅ **Test STK Push notifications** on your phone
- ✅ **Same API endpoints** as production
- ✅ **No setup required** - works out-of-the-box!

### **Sandbox Test Phone Numbers:**
```
254708374149
254708374148
254708374147
```

### **How to Test:**
1. **Run your app:**
   ```bash
   flutter run -d chrome  # or android/ios
   ```

2. **Purchase AKOFA:**
   - Phone: `254708374149`
   - Amount: `100 KES`
   - Click purchase

3. **Check your phone** for M-Pesa STK Push!

4. **Expected logs:**
   ```
   🌐 M-Pesa Environment: 🧪 SANDBOX
   💰 Initiating AKOFA purchase: 100 KES = 1.0 AKOFA
   ✅ STK Push initiated successfully
   📱 Check your phone for M-Pesa prompt!
   ```

---

## 🔄 **Step 2: Switch to Production (Real Money)**

### **When you're ready for real transactions:**

1. **Get Production Credentials:**
   - Visit [Safaricom Developer Portal](https://developer.safaricom.co.ke/)
   - Create production app
   - Get your real credentials

2. **Update Credentials:**
   ```dart
   // In lib/services/enhanced_mpesa_service.dart

   // 🔴 REPLACE THESE WITH YOUR REAL CREDENTIALS
   static const String _productionConsumerKey = 'YOUR_REAL_CONSUMER_KEY';
   static const String _productionConsumerSecret = 'YOUR_REAL_CONSUMER_SECRET';
   static const String _productionPassKey = 'YOUR_REAL_PASS_KEY';
   static const String _productionShortCode = 'YOUR_REAL_SHORT_CODE';
   static const String _productionCallbackUrl = 'YOUR_REAL_CALLBACK_URL';
   ```

3. **Switch Environment:**
   ```dart
   static const bool _useSandbox = false; // 🔄 CHANGE TO false FOR PRODUCTION
   ```

4. **Test with Real Money:**
   - Use real phone numbers
   - Use small amounts first (KES 100)
   - Monitor transactions in Firestore

---

## 🔧 **Environment Comparison**

| Feature | Sandbox 🧪 | Production 💰 |
|---------|------------|---------------|
| **Cost** | FREE | Real money |
| **Setup** | None required | Credentials needed |
| **API Calls** | Real API | Real API |
| **STK Push** | Works on phone | Works on phone |
| **Transactions** | Test mode | Live transactions |
| **Credentials** | Pre-configured | From Safaricom |

---

## 🚀 **Quick Start Commands**

### **Test Sandbox (Current):**
```bash
# No changes needed - already configured!
flutter run -d chrome
```

### **Switch to Production:**
```dart
// Change this line in lib/services/enhanced_mpesa_service.dart
static const bool _useSandbox = false; // 🔄 false = PRODUCTION
```

### **Verify Environment:**
Look for this in your console:
```
🌐 M-Pesa Environment: 🧪 SANDBOX    # Testing
🌐 M-Pesa Environment: 💰 PRODUCTION # Real money
```

---

## ⚠️ **Important Notes**

### **Sandbox Limitations:**
- Uses test phone numbers only
- No real money transfer
- Limited transaction amounts
- For development/testing only

### **Production Requirements:**
- Real M-Pesa credentials from Safaricom
- Real phone numbers
- Real money (KES 100 minimum)
- Production app approval from Safaricom

### **Safety First:**
- Start with small amounts (KES 100)
- Test thoroughly in sandbox first
- Monitor all transactions
- Have fallback mechanisms

---

## 🎯 **Your Workflow**

### **Phase 1: Development (Sandbox)**
```bash
✅ Use sandbox credentials (already configured)
✅ Test UI/UX flows
✅ Verify STK Push works
✅ Debug integration issues
```

### **Phase 2: Production Testing**
```bash
🔄 Switch _useSandbox = false
🔄 Add real credentials
🔄 Test with small amounts
🔄 Monitor real transactions
```

### **Phase 3: Live**
```bash
💰 Real M-Pesa transactions!
💰 Real money flowing!
💰 Production ready!
```

---

## 📞 **Need Help?**

### **Common Issues:**

#### **"CORS Error" on Web:**
```bash
# Install browser extension or use proxy
npm install -g cors-anywhere && cors-anywhere
```

#### **"Authentication Failed":**
- Check your Consumer Key and Secret
- Verify sandbox vs production credentials

#### **"STK Push Failed":**
- Use correct phone number format: `254XXXXXXXXX`
- Check short code configuration

### **Debug Tips:**
```dart
// Check which environment is active
print('Environment: ${_useSandbox ? 'SANDBOX' : 'PRODUCTION'}');

// Verify credentials are loaded
print('Consumer Key: ${_consumerKey.substring(0, 10)}...');
```

---

## 🎉 **Ready to Test?**

**Your sandbox is ready to go!** 🚀

1. **Run your app:** `flutter run -d chrome`
2. **Go to wallet → Purchase AKOFA**
3. **Use test phone:** `254708374149`
4. **Amount:** `100 KES`
5. **Click purchase**
6. **Check your phone** for M-Pesa STK Push! 📱

**Questions?** The sandbox credentials are working and ready for testing! 🎯

**Happy testing!** 👨‍💻🧪