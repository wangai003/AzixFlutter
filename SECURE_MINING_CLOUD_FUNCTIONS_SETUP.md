# 🔐 Secure Mining with Cloud Functions - Setup Guide

## Overview

Your mining infrastructure now uses **Firebase Cloud Functions** for secure token payouts. The distributor secret key **NEVER leaves the backend** - ensuring maximum security for your AKOFA token distribution.

## 🏗️ Architecture

```
┌─────────────────┐
│  Flutter App    │
│  (Client Side)  │
└────────┬────────┘
         │
         │ Calls Cloud Function
         │ (No secret keys here!)
         ▼
┌─────────────────┐
│  Cloud Function │
│   (Backend)     │
│                 │
│  ✅ Has secret  │
│  ✅ Secure      │
│  ✅ Verified    │
└────────┬────────┘
         │
         │ Sends AKOFA
         ▼
┌─────────────────┐
│  User's Wallet  │
│   (Stellar)     │
└─────────────────┘
```

## 📋 Prerequisites

1. Firebase project set up
2. Node.js 18+ installed
3. Firebase CLI installed (`npm install -g firebase-tools`)
4. Stellar distributor account with AKOFA tokens

## 🚀 Step-by-Step Setup

### 1. Install Dependencies

```bash
cd functions
npm install
```

This installs:
- `stellar-sdk` - For Stellar blockchain interactions
- `firebase-functions` - Cloud Functions runtime
- `firebase-admin` - Admin SDK for Firestore/Auth

### 2. Configure Secret Keys (CRITICAL ⚠️)

**Option A: Using Firebase Config (Recommended)**

```bash
# Set your distributor's secret key (KEEP THIS SECURE!)
firebase functions:config:set stellar.distributor_secret="YOUR_STELLAR_SECRET_KEY"

# Set your distributor's public key
firebase functions:config:set stellar.distributor_public="YOUR_STELLAR_PUBLIC_KEY"

# Set the AKOFA issuer public key
firebase functions:config:set stellar.akofa_issuer="AKOFA_ISSUER_PUBLIC_KEY"
```

**Option B: Using Environment Variables (For testing)**

Create `.env` file in `/functions` folder (DON'T commit this!):
```
STELLAR_DISTRIBUTOR_SECRET=YOUR_STELLAR_SECRET_KEY
STELLAR_DISTRIBUTOR_PUBLIC=YOUR_STELLAR_PUBLIC_KEY  
STELLAR_AKOFA_ISSUER=AKOFA_ISSUER_PUBLIC_KEY
```

Add to `.gitignore`:
```
functions/.env
functions/.runtimeconfig.json
```

### 3. Deploy Cloud Functions

```bash
# From project root
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:sendMinedTokens
firebase deploy --only functions:processPendingMiningPayouts
```

### 4. Verify Deployment

```bash
# Check logs
firebase functions:log

# Test the function (will fail without auth, but shows it's deployed)
curl https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendMinedTokens
```

## 📱 Flutter App Usage

The Flutter app automatically uses Cloud Functions through the reward engine:

```dart
// In reward_engine.dart (already configured)
final callable = _functions.httpsCallable('sendMinedTokens');
final result = await callable.call({
  'amount': 0.02083333, // AKOFA amount
  'sessionId': 'mining_session_123',
});
```

## 🔒 Security Features

### ✅ What's Secure

1. **Distributor secret key NEVER leaves backend**
2. **Authentication required** - Only logged-in users can call the function
3. **Amount validation** - Max 10 AKOFA per payout
4. **Wallet verification** - Checks account exists and has trustline
5. **Transaction logging** - All payouts recorded in Firestore
6. **Error handling** - Failed transactions recorded for retry

### ⚠️ Important Security Notes

- Never commit secret keys to git
- Use Firebase Config for production
- Monitor Cloud Function logs for suspicious activity
- Set up billing alerts on Firebase console

## 📊 Monitoring & Debugging

### View Logs

```bash
# Real-time logs
firebase functions:log --follow

# Specific function logs
firebase functions:log --only sendMinedTokens

# Recent errors
firebase functions:log --only sendMinedTokens --lines 50
```

### Check Firestore Collections

- `mining_payouts` - All completed payouts
- `pending_mining_payouts` - Queued payouts (processed every 5 minutes)
- `reward_transactions` - Transaction records from reward engine

### Common Issues

**Issue: "distributor_secret not set"**
```bash
# Solution: Set the config
firebase functions:config:set stellar.distributor_secret="YOUR_KEY"
firebase deploy --only functions
```

**Issue: "User does not have AKOFA trustline"**
- User needs to add AKOFA trustline first
- Check in app's wallet setup flow

**Issue: "Account not funded"**
- User's Stellar account needs XLM for activation
- Minimum 1 XLM required

## 🔄 How Mining Payouts Work

### Every 5 Minutes (Automatic)

1. User mines for 5 minutes
2. Tokens accumulate locally (0.25 AKOFA/hour = ~0.02083 per 5min)
3. Reward engine queues payout
4. `_distributePendingRewards()` is called
5. Cloud Function `sendMinedTokens` is invoked
6. AKOFA tokens sent to user's wallet
7. Transaction hash recorded

### Flow Diagram

```
Mining Start
    ↓
Every Second: Calculate (0.25 / 3600) AKOFA
    ↓
After 5 Minutes: Accumulated ~0.02083 AKOFA
    ↓
Call Cloud Function
    ↓
Cloud Function:
  - Verify user
  - Check wallet
  - Load distributor account
  - Build Stellar transaction
  - Sign with SECRET KEY (backend only!)
  - Submit to Stellar network
    ↓
Success! Tokens in wallet
    ↓
Record transaction
    ↓
Reset accumulator
    ↓
Continue mining...
```

## 🧪 Testing

### Local Emulator Testing

```bash
# Start emulators
firebase emulators:start

# In another terminal, test the function
curl -X POST http://localhost:5001/YOUR_PROJECT/us-central1/sendMinedTokens \
  -H "Content-Type: application/json" \
  -d '{"data":{"amount":0.02,"sessionId":"test"}}'
```

### Test with Flutter App

1. Start mining session
2. Wait 5 minutes
3. Check console for Cloud Function logs
4. Verify AKOFA balance in wallet increased
5. Check Stellar transaction on horizon testnet/mainnet

## 📈 Scaling Considerations

- Cloud Functions scale automatically
- Each payout ~1-2 seconds
- Max 50 concurrent payouts in batch processing
- Monitor Firebase quota usage

## 💰 Cost Estimate

**Per 1,000 mining payouts:**
- Cloud Functions invocations: $0.40
- Firestore writes: $0.36
- Network egress: $0.12
- **Total**: ~$0.88 per 1,000 users

## 🆘 Support & Troubleshooting

### Check Function Status

```bash
firebase functions:list
```

### View Configuration

```bash
firebase functions:config:get
```

### Re-deploy After Changes

```bash
cd functions
npm install  # If dependencies changed
cd ..
firebase deploy --only functions
```

## ✅ Verification Checklist

- [ ] Firebase CLI installed
- [ ] Dependencies installed (`npm install` in functions/)
- [ ] Secret keys configured (firebase functions:config:set)
- [ ] Functions deployed (firebase deploy --only functions)
- [ ] Distributor account has AKOFA tokens
- [ ] Tested with real mining session
- [ ] Tokens successfully sent to wallet
- [ ] Transactions visible on Stellar

## 🎉 You're All Set!

Your mining infrastructure is now secure and ready to distribute AKOFA tokens! The distributor secret key is safely stored on Firebase servers and never exposed to clients.

Happy mining! ⛏️💎

