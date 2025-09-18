#!/bin/bash

echo "🚀 Running Stellar Transaction Retrieval Tests"
echo "=============================================="

# Function to run a test
run_test() {
    local test_name=$1
    local test_file=$2

    echo ""
    echo "🧪 Running $test_name..."
    echo "----------------------------------------"

    if [ -f "$test_file" ]; then
        dart run "$test_file"
        local exit_code=$?
        echo ""
        echo "✅ $test_name completed with exit code: $exit_code"
        return $exit_code
    else
        echo "❌ Test file not found: $test_file"
        return 1
    fi
}

# Test 1: Simple SDK Test (no dependencies)
echo "📋 Test 1: Basic Stellar SDK Functionality"
run_test "Simple SDK Test" "simple_transaction_test.dart"

# Test 2: Full Integration Test (requires project setup)
echo ""
echo "📋 Test 2: Full Blockchain Service Integration"
echo "⚠️  Note: This test requires Firebase authentication"
echo "💡 Make sure you're logged into the app first"
run_test "Full Integration Test" "test_transaction_retrieval.dart"

echo ""
echo "🎉 All tests completed!"
echo "=============================================="
echo ""
echo "🔍 Next Steps:"
echo "1. Check the output above for any errors"
echo "2. If tests pass, transaction retrieval is working"
echo "3. If tests fail, check network connectivity"
echo "4. Verify Firebase authentication if using full test"
echo ""
echo "📊 Common Issues:"
echo "- Network errors: Check internet connection"
echo "- 404 errors: Account may not exist or have transactions"
echo "- Firebase errors: Make sure user is authenticated"
echo ""

