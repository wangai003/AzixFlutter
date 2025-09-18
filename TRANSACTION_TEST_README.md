# 🔍 Stellar Transaction Retrieval Tests

This directory contains test scripts to verify that transaction retrieval from the Stellar blockchain is working correctly.

## 📋 Available Tests

### 1. Simple SDK Test (`simple_transaction_test.dart`)
- **Purpose**: Test basic Stellar SDK functionality without Firebase dependencies
- **What it tests**:
  - Stellar SDK connection to testnet
  - Account information retrieval
  - Transaction fetching from known accounts
  - Operation retrieval and parsing
- **Requirements**: Internet connection only
- **Run command**: `dart run simple_transaction_test.dart`

### 2. Full Integration Test (`test_transaction_retrieval.dart`)
- **Purpose**: Test the complete transaction retrieval pipeline including Firebase integration
- **What it tests**:
  - Stellar SDK connection
  - BlockchainTransactionService functionality
  - Transaction conversion to app format
  - Firebase authentication integration
- **Requirements**: Firebase authentication, internet connection
- **Run command**: `dart run test_transaction_retrieval.dart`

### 3. Automated Test Runner (`run_transaction_tests.sh`)
- **Purpose**: Run both tests sequentially with clear output
- **Requirements**: Bash shell, executable permissions
- **Run command**: `./run_transaction_tests.sh`

## 🚀 How to Run Tests

### Option 1: Run Individual Tests
```bash
# Navigate to project directory
cd /Users/apple/projects/AzixFlutter

# Run simple SDK test (recommended first)
dart run simple_transaction_test.dart

# Run full integration test (requires Firebase auth)
dart run test_transaction_retrieval.dart
```

### Option 2: Run All Tests
```bash
# Make sure the script is executable
chmod +x run_transaction_tests.sh

# Run all tests
./run_transaction_tests.sh
```

## 🔍 What Each Test Verifies

### Simple SDK Test Results
- ✅ **SDK Connection**: Can connect to Stellar testnet
- ✅ **Account Retrieval**: Can fetch account information
- ✅ **Transaction Fetching**: Can retrieve transactions from blockchain
- ✅ **Operation Parsing**: Can parse payment operations correctly
- ✅ **Data Formatting**: Transactions have correct structure

### Full Integration Test Results
- ✅ **Service Integration**: BlockchainTransactionService works
- ✅ **Authentication**: Firebase auth integration
- ✅ **Data Conversion**: Stellar data converts to app Transaction format
- ✅ **Error Handling**: Proper error handling for edge cases
- ✅ **Caching**: Cache functionality works correctly

## 📊 Interpreting Test Results

### ✅ SUCCESS Indicators
```
✅ Stellar SDK connection successful
✅ Found X transactions
✅ Found X operations
✅ Account found successfully
```

### ❌ FAILURE Indicators
```
❌ Stellar SDK connection failed
❌ No transactions found
❌ Account does not exist
❌ Network connection failed
```

### ⚠️ WARNING Indicators
```
⚠️ No operations found - this might mean no transactions
⚠️ Account needs funding
💡 This is expected for fresh test accounts
```

## 🔧 Troubleshooting

### Network Issues
```bash
# Check internet connection
ping 8.8.8.8

# Check Stellar testnet status
curl https://status.stellar.org/
```

### Account Issues
```bash
# Fund a test account using Friendbot
curl "https://friendbot.stellar.org/?addr=YOUR_PUBLIC_KEY"
```

### Firebase Issues
```bash
# Make sure you're authenticated in the app
# Check Firebase console for authentication status
```

## 🎯 Next Steps After Testing

### If Tests Pass ✅
1. Transaction retrieval is working correctly
2. Check why UI isn't displaying transactions
3. Look at AllTransactionsScreen and StellarProvider
4. Verify Firebase data structure

### If Tests Fail ❌
1. Fix the identified issues (network, authentication, etc.)
2. Re-run tests to verify fixes
3. Check Stellar testnet status
4. Verify account has transactions

## 📞 Support

If tests are failing:
1. Check the error messages carefully
2. Verify network connectivity
3. Ensure Firebase is properly configured
4. Check Stellar testnet status at https://status.stellar.org/

## 📝 Test Output Examples

### Successful Test Output
```
🚀 Simple Stellar Transaction Retrieval Test
==================================================

📡 TEST 1: Stellar SDK Connection
------------------------------
🔗 Testnet Server: https://horizon-testnet.stellar.org
🔍 Testing with SDF account: GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWNW
✅ Account found successfully!
📊 Account ID: GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWNW
💰 Balances: 1
   - XLM: 10000.0000000

🔄 TEST 2: Transaction Retrieval
------------------------------
📡 Fetching recent transactions...
✅ Found 5 transactions

📋 Transaction Details:
1. Hash: abc123...
   Status: ✅ Success
   Time: 2024-01-15 10:30:00.000Z
   Fee: 100 stroops
   Source: GAAZI4...
```

### Failed Test Output
```
❌ Test failed with error: SocketException: Failed host lookup
💡 Network error - check your internet connection
```

This indicates the device cannot connect to the Stellar network.

