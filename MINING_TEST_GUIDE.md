# 🧪 Mining Infrastructure Testing Guide

## Overview

I've created **two test scripts** to verify your mining infrastructure works correctly:

1. **Quick Test** (`test_mining_quick.dart`) - 30 seconds, checks setup
2. **Full Test** (`test_mining_infrastructure.dart`) - 15 minutes, verifies payouts

## 📋 Prerequisites

Before running tests, ensure:

1. ✅ Firebase project configured
2. ✅ Cloud Functions deployed
3. ✅ User logged in to app
4. ✅ Wallet set up with AKOFA trustline
5. ✅ Distributor account funded with AKOFA

## 🚀 Test 1: Quick Setup Test (30 seconds)

### What It Tests

- Firebase connection
- User authentication
- Wallet configuration
- Stellar account status
- AKOFA trustline
- Cloud Function availability
- Mining service initialization
- Session creation
- Token accumulation (3 seconds)
- Cloud Function call

### How to Run

```bash
# Run the quick test
flutter run test_mining_quick.dart
```

### Expected Output

```
✅ Firebase Connection (45ms)
✅ User Authentication (12ms)
✅ Wallet Configuration (230ms)
✅ Stellar Account Funded (450ms)
✅ AKOFA Trustline (320ms)
✅ Cloud Function Available (8ms)
✅ Mining Service Init (180ms)
✅ Mining Session Creation (340ms)
✅ Token Accumulation (3125ms)
✅ Cloud Function Call (1850ms)

Passed: 10 | Failed: 0 | Total: 10
✅ All tests passed!
```

### What Success Means

If all tests pass:
- ✅ Setup is correct
- ✅ Ready for full 15-minute test
- ✅ Mining infrastructure functional

## 🎯 Test 2: Full Payout Test (15 minutes)

### What It Tests

- Complete mining session (15 minutes)
- 3 × 5-minute payout intervals
- Cloud Function payouts
- Stellar transaction confirmation
- Wallet balance verification
- Timing accuracy

### How to Run

```bash
# Run the full test (requires 15 minutes)
flutter run test_mining_infrastructure.dart
```

### What Happens

```
Timeline:
00:00 - Test starts, mining begins
       Rate: 0.25 AKOFA/hour
       Expected per 5min: 0.02083333 AKOFA

05:00 - Payout #1
       ⏰ Timer fires
       ⚡ Immediate distribution triggered
       💸 Cloud Function sends 0.02083333 AKOFA
       ✅ Wallet receives tokens
       
10:00 - Payout #2 (same process)

15:00 - Payout #3 (same process)
       🏁 Test complete
       📊 Results displayed
```

### Expected Logs

Every 30 seconds:
```
⏱️  Elapsed: 0m 30s | Accumulated: 0.00034722 AKOFA
⏱️  Elapsed: 1m 0s  | Accumulated: 0.00069444 AKOFA
...
```

At 5-minute mark:
```
🎉 ═══════════════════════════════════════
   PAYOUT #1 CONFIRMED!
🎉 ═══════════════════════════════════════
   Amount: 0.02083333 AKOFA
   Tx Hash: a1b2c3d4e5f6g7h8...
   Time: 14:25:00
   ⏱️  Expected at: 5min
   ⏱️  Actual at: 5min
   ⏱️  Difference: 0min
   ✅ TIMING PERFECT! (within 1 minute)

💰 Wallet balance updated:
   Previous: 10.0000 AKOFA
   Current: 10.0208333 AKOFA
   Increase: +0.02083333 AKOFA
```

### Success Criteria

```
📊 TEST RESULTS:
─────────────────────────────────────
   Duration: 15 minutes
   Payouts Received: 3 / 3 expected ✅
   Total Tokens: 0.06249999 AKOFA
   Wallet Increase: 0.06249999 AKOFA

✅ SUCCESS! All 3 payouts received on time!
✅ 5-minute interval mechanism working perfectly!
```

## 🐛 Troubleshooting

### Test Fails: "No user logged in"

**Solution**: Log in to the app before running tests

```dart
// In your app, ensure user is signed in:
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: 'test@example.com',
  password: 'password',
);
```

### Test Fails: "No wallet found"

**Solution**: Set up wallet in the app first

1. Open app
2. Navigate to wallet setup
3. Create or import wallet
4. Add AKOFA trustline

### Test Fails: "Account not funded"

**Solution**: Send XLM to activate account

```bash
# Get your public key from test logs
# Send minimum 1 XLM to that address
```

### Test Fails: "Cloud Function error"

**Possible Issues**:

1. **Functions not deployed**
   ```bash
   firebase deploy --only functions
   ```

2. **Environment variables not set**
   ```bash
   firebase functions:config:set stellar.distributor_secret="YOUR_KEY"
   firebase functions:config:set stellar.distributor_public="YOUR_KEY"
   firebase functions:config:set stellar.akofa_issuer="YOUR_KEY"
   ```

3. **Check function logs**
   ```bash
   firebase functions:log --only sendMinedTokens --lines 50
   ```

### Payouts Not Received

**Check**:

1. Cloud Function logs:
   ```bash
   firebase functions:log --only sendMinedTokens --follow
   ```

2. Firestore collections:
   - `mining_payouts` - Check for failed transactions
   - `reward_transactions` - Check pending rewards

3. Distributor balance:
   - Ensure distributor has enough AKOFA tokens

## 📊 Interpreting Results

### Quick Test Results

| Passed | Status | Action |
|--------|--------|--------|
| 10/10 | ✅ Perfect | Run full test |
| 9/10 | ⚠️ Almost | Fix failed test |
| 8/10 | ⚠️ Issues | Fix failed tests |
| <8/10 | ❌ Problems | Review setup |

### Full Test Results

| Payouts | Status | Meaning |
|---------|--------|---------|
| 3/3 | ✅ Perfect | System working perfectly |
| 2/3 | ⚠️ Partial | Check logs for issue |
| 1/3 | ⚠️ Problem | Investigate cause |
| 0/3 | ❌ Failed | Check all configuration |

## 🎯 What to Look For

### Timing Accuracy

```
✅ GOOD:
   Expected at: 5min
   Actual at: 5min
   Difference: 0min

⚠️ ACCEPTABLE:
   Expected at: 10min
   Actual at: 11min
   Difference: 1min

❌ PROBLEM:
   Expected at: 15min
   Actual at: 18min
   Difference: 3min
```

### Transaction Confirmation

Look for transaction hash in logs:
```
Tx Hash: abc123def456...
```

Verify on Stellar:
```
https://stellar.expert/explorer/public/tx/abc123def456...
```

## 📝 Test Checklist

Before deploying to production:

- [ ] Quick test passes 10/10
- [ ] Full test passes 3/3 payouts
- [ ] Timing accuracy within 1 minute
- [ ] Wallet balance increases correctly
- [ ] Transactions visible on Stellar
- [ ] Cloud Function logs show no errors
- [ ] Firestore payouts recorded
- [ ] Tested with multiple users

## 🚀 Running in Production

Once tests pass:

1. **Monitor First Week**
   ```bash
   # Watch logs daily
   firebase functions:log --only sendMinedTokens
   
   # Check Firestore for failed payouts
   # Collection: mining_payouts
   # Filter: status == "failed"
   ```

2. **Set Up Alerts**
   - Firebase console → Functions → Metrics
   - Set up alerts for errors
   - Monitor execution time
   - Track invocation count

3. **Refill Distributor**
   - Monitor distributor AKOFA balance
   - Set up low balance alerts
   - Keep distributor funded

## 🔍 Advanced Debugging

### Enable Detailed Logging

In `reward_engine.dart`, logs are already verbose:
```
💎 Queued reward: X AKOFA
⚡ IMMEDIATE DISTRIBUTION: Attempting...
✅ Rate limit OK: X minutes since last
💸 Calling Cloud Function...
✅ Cloud Function success! Tx hash: ...
```

### Monitor Real-Time

In Firebase Console:
1. Firestore → Collections → `mining_payouts`
2. Functions → Dashboard → `sendMinedTokens`
3. Functions → Logs → Filter by function

### Check Stellar Network

```bash
# View account transactions
curl https://horizon.stellar.org/accounts/YOUR_PUBLIC_KEY/transactions

# View specific transaction
curl https://horizon.stellar.org/transactions/TX_HASH
```

## ✅ Success Indicators

Your mining infrastructure is working if:

1. ✅ Quick test: 10/10 passed
2. ✅ Full test: 3/3 payouts received
3. ✅ Timing: All within 1 minute of expected
4. ✅ Transactions: Visible on Stellar
5. ✅ Wallet: Balance increases correctly
6. ✅ Logs: No errors in Cloud Functions
7. ✅ Firestore: All payouts marked "completed"

## 🎉 Ready to Deploy

If all tests pass, your mining infrastructure is production-ready! 🚀

The 5-minute payout mechanism is verified and working correctly. Users will receive their mined AKOFA tokens reliably every 5 minutes throughout their 24-hour mining sessions.

