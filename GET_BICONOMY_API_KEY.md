# How to Get the Correct Biconomy API Key

## ⚠️ Important: You Need the Traditional Meta-Transaction API Key

Your current key (`mee_...`) is for Biconomy MEE, which is different from what we need.

For **gasless ERC-20 transfers on Polygon Amoy**, you need the **traditional Gasless API** key.

---

## Step-by-Step Guide

### Step 1: Access Biconomy Dashboard

1. Go to: **https://dashboard.biconomy.io**
2. Sign in with your account
3. You should see the main dashboard

### Step 2: Look for the Correct Section

You need to find **"Gasless API"** or **"Gasless Transactions"** section.

**Important Navigation Tips:**

- **DO NOT** use "MEE" section (that's what you used before)
- Look for sections labeled:
  - ✅ "Gasless API"
  - ✅ "Gasless Transactions"
  - ✅ "Meta Transactions"
  - ✅ "Hyphen" (older UI)
  - ❌ NOT "MEE" or "Meta-Execution Environment"

### Step 3: Create a New Project/DApp

If this is your first time:

1. Click **"Create New Project"** or **"Register DApp"**
2. Fill in the details:

```
Project Name: AzixFlutter Gasless
Description: Gasless token transfers for AzixFlutter wallet
Type: Gasless Transactions
```

### Step 4: Select Network

This is crucial:

1. Look for **Network** or **Chain** selection
2. Select: **"Polygon Amoy Testnet"** or **"Polygon Testnet"**
3. Chain ID should be: **80002**

**Important**: 
- ❌ DO NOT select "Polygon Mumbai" (deprecated)
- ✅ SELECT "Polygon Amoy Testnet" (current testnet)

### Step 5: Get Your API Key

After creating the project:

1. You should see an **API Key** displayed
2. The key format will be:
   - Could start with `pk_` 
   - Could be a long alphanumeric string
   - Should NOT start with `mee_`

3. Copy this key

**Example format:**
```
Good: pk_test_1234567890abcdef...
Good: 1a2b3c4d-5e6f-7g8h-9i0j-k1l2m3n4o5p6
Bad: mee_4tDgt6JRovzz33xioQ3m2r (this is MEE)
```

### Step 6: Register Your Smart Contracts

This is essential for gasless transactions to work:

1. In your project dashboard, find **"Smart Contracts"** or **"Contracts"** section
2. Click **"Add New Contract"**
3. Fill in your AKOFA token details:

```
Contract Address: [Your AKOFA Token Address on Polygon Amoy]
Contract Type: ERC-20
Network: Polygon Amoy Testnet (80002)
```

4. After adding, you need to **whitelist functions**:
   - Find the contract you just added
   - Click **"Add Function"** or **"Manage Functions"**
   - Enable: `transfer(address,uint256)`
   - Save

### Step 7: Fund Your Gas Tank

For testnet:

1. Go to **"Gas Tank"** section in dashboard
2. Copy your **gas tank address** (shown on the page)
3. Get testnet MATIC from faucet:
   - Visit: https://faucet.polygon.technology/
   - Select: "Polygon Amoy"
   - Paste your gas tank address
   - Request MATIC
4. Wait for MATIC to arrive (check on PolygonScan Amoy)
5. Recommended: Add 5-10 MATIC to start

### Step 8: Update Your Code

Once you have the correct API key:

1. Open: `lib/services/biconomy_service.dart`
2. Replace line 12 with your new key:

```dart
static const String _biconomyApiKey = 'YOUR_CORRECT_API_KEY_HERE';
```

**Example:**
```dart
static const String _biconomyApiKey = 'pk_test_1234567890abcdef...';
```

---

## Troubleshooting

### Issue: "I don't see Gasless API section"

**Solutions:**

1. **Check the sidebar navigation**:
   - Look for "Products" menu
   - Should have: Gasless, Paymasters, Bundlers, etc.
   - Click on "Gasless"

2. **Try the old dashboard**:
   - URL: https://dashboard-v1.biconomy.io
   - This might have clearer navigation

3. **Look for "Hyphen"**:
   - Some UIs call it "Hyphen Gasless"
   - Same functionality

### Issue: "Only see MEE option"

**Solution:**

The dashboard UI might have changed. Try:

1. Look for a **toggle** or **version selector**
2. Some dashboards have "V2" or "Classic" mode
3. Contact Biconomy support if needed

### Issue: "Can't find Polygon Amoy"

**Solution:**

- Make sure you're in "Testnet" mode
- Toggle testnet/mainnet switch (usually top-right)
- Polygon Amoy is the NEW testnet (Mumbai is deprecated)

### Issue: "API key doesn't work"

**Checklist:**

- [ ] Key is for Gasless API (not MEE)
- [ ] Network is Polygon Amoy (80002)
- [ ] Token contract is registered
- [ ] Transfer function is whitelisted
- [ ] Gas tank has MATIC
- [ ] No spaces or quotes around the key in code

---

## Alternative: Contact Biconomy Support

If you're having trouble navigating the dashboard:

### Discord (Fastest)
1. Join: https://discord.gg/biconomy
2. Go to #support channel
3. Ask: "I need help getting a Gasless API key for Polygon Amoy testnet"

### Telegram
- Join: https://t.me/biconomy
- Ask in the main chat

### Email
- Email: support@biconomy.io
- Subject: "Gasless API Key Setup - Polygon Amoy"

---

## What to Ask Support (Copy/Paste)

```
Hi Biconomy team,

I'm trying to set up gasless transactions for ERC-20 tokens on Polygon Amoy testnet.

I need:
1. A Gasless API key (NOT MEE) for Polygon Amoy testnet (Chain ID: 80002)
2. Help registering my ERC-20 token contract for gasless transfers
3. The transfer(address,uint256) function whitelisted

Project: AzixFlutter Wallet
Use case: Gasless AKOFA token transfers
Network: Polygon Amoy Testnet (80002)

Currently I have a MEE API key (mee_...) but I need the traditional Gasless API key instead.

Thank you!
```

---

## Verification Steps

After getting your API key, verify it works:

### 1. Check API Key Format
```dart
// Your key should look like one of these:
'pk_test_abc123...'  // ✅ Good
'1a2b3c-4d5e...'     // ✅ Good  
'mee_abc123...'      // ❌ Bad (this is MEE)
```

### 2. Test in Code
After updating the key, your app should:
- Not throw "invalid API key" errors
- Show gasless option when MATIC is low
- Successfully send gasless transactions

### 3. Check Dashboard
- Transaction should appear in dashboard analytics
- Gas tank balance should decrease
- Success rate should be tracked

---

## Quick Reference

### What You Need:
✅ Traditional Gasless API key (NOT MEE)
✅ Polygon Amoy Testnet (Chain ID: 80002)
✅ Token contract registered
✅ Transfer function whitelisted
✅ Gas tank funded with 5-10 MATIC

### Dashboard URLs:
- **Main**: https://dashboard.biconomy.io
- **V1 (if needed)**: https://dashboard-v1.biconomy.io
- **Docs**: https://docs.biconomy.io

### Testnet Resources:
- **Faucet**: https://faucet.polygon.technology/
- **Explorer**: https://amoy.polygonscan.com/

---

## Next Steps After Getting Key

1. ✅ Update `biconomy_service.dart` with new key
2. ✅ Register your AKOFA token contract
3. ✅ Whitelist transfer function
4. ✅ Fund gas tank with testnet MATIC
5. ✅ Test gasless transaction in your app

---

**Need More Help?**

- Check: `GASLESS_QUICKSTART.md` for testing steps
- Check: `BICONOMY_SETUP_GUIDE.md` for detailed setup
- Ask in Discord: https://discord.gg/biconomy

Good luck! 🚀

