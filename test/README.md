# Raffle System Test Suite

This comprehensive test suite covers the complete raffle system including Soroban smart contracts, Flutter services, models, and UI components.

## Test Categories

### 1. Unit Tests
- **Soroban Contract Tests** (`soroban_contract_test.dart`): Test individual contract functions and error handling
- **Raffle Service Tests** (`raffle_service_test.dart`): Test service layer methods with mocked dependencies
- **Raffle Model Tests** (`raffle_models_test.dart`): Test data models, serialization, and business logic

### 2. Integration Tests
- **Contract + Firebase Integration** (`integration_raffle_test.dart`): Test interactions between Soroban contracts and Firebase backend
- **Flutter UI + Services Integration**: Test UI components with service layer integration

### 3. End-to-End Tests
- **Complete Raffle Flows**: Test full user journeys from raffle creation to prize distribution

### 4. Security Tests
- **Authentication & Authorization** (`security_raffle_test.dart`): Test user access controls and wallet security
- **Input Validation**: Test sanitization and validation of user inputs
- **Blockchain Security**: Test transaction security and wallet operations

### 5. Performance Tests
- **Load Testing** (`performance_raffle_test.dart`): Test system performance under various loads
- **Response Time Testing**: Ensure operations complete within acceptable time limits
- **Resource Usage**: Monitor memory and database connection usage

### 6. Error Handling Tests
- **Network Failures** (`error_handling_raffle_test.dart`): Test graceful handling of connectivity issues
- **Invalid Inputs**: Test system behavior with malformed data
- **Recovery Mechanisms**: Test system recovery from partial failures

## Test Coverage

The test suite aims for:
- **Minimum 80% overall code coverage**
- **Minimum 70% coverage per file**
- **100% coverage for critical security functions**

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test Categories
```bash
# Unit tests only
flutter test test/raffle_models_test.dart test/soroban_contract_test.dart

# Integration tests
flutter test test/integration_raffle_test.dart

# Security tests
flutter test test/security_raffle_test.dart

# Performance tests
flutter test test/performance_raffle_test.dart

# Error handling tests
flutter test test/error_handling_raffle_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### Generate Coverage Report
```bash
flutter pub global activate coverage
flutter pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
genhtml coverage/lcov.info --output-directory coverage/html
```

## CI/CD Integration

Tests are automatically run on:
- **Push to main/develop branches**
- **Pull requests to main/develop branches**

### CI Pipeline Stages
1. **Unit Tests**: Fast feedback on code changes
2. **Contract Tests**: Soroban smart contract validation
3. **Integration Tests**: Full system interaction testing
4. **Security Tests**: Security vulnerability scanning
5. **Performance Tests**: Load and performance validation
6. **Coverage Check**: Ensure minimum coverage thresholds

## Test Data and Mocking

### Firebase Emulators
Integration tests use Firebase emulators for isolated testing:
```bash
firebase emulators:start --only firestore
```

### Mock Data
- **Test Users**: Predefined user accounts for testing
- **Test Raffles**: Sample raffle configurations
- **Mock Transactions**: Simulated blockchain transactions
- **Mock Balances**: Test wallet balances

## Test Organization

```
test/
├── raffle_models_test.dart          # Unit tests for data models
├── soroban_contract_test.dart       # Unit tests for contract interactions
├── raffle_service_test.dart         # Unit tests for service layer
├── integration_raffle_test.dart     # Integration tests
├── security_raffle_test.dart        # Security and auth tests
├── performance_raffle_test.dart     # Performance and load tests
├── error_handling_raffle_test.dart  # Error handling and recovery tests
├── coverage_config.yaml             # Coverage configuration
└── README.md                        # This file
```

## Key Test Scenarios

### Happy Path Tests
- Successful raffle creation and management
- Valid user entries and winner selection
- Successful prize distribution

### Edge Cases
- Raffle at maximum capacity
- Last-minute entries
- Multiple winners with equal prizes

### Failure Scenarios
- Network disconnection during critical operations
- Invalid transaction signatures
- Database connection failures
- Smart contract execution failures

### Security Scenarios
- Unauthorized access attempts
- SQL injection attempts
- XSS attack vectors
- Replay attack prevention

## Performance Benchmarks

### Response Time Targets
- Raffle creation: < 5 seconds
- User entry: < 3 seconds
- Winner selection: < 10 seconds
- Balance check: < 3 seconds

### Load Targets
- Concurrent entries: 100+ simultaneous
- Database queries: 1000+ per minute
- API calls: 500+ per minute

## Debugging Failed Tests

### Common Issues
1. **Firebase Emulator Not Running**: Start with `firebase emulators:start`
2. **Mock Data Conflicts**: Clear test data between runs
3. **Network Timeouts**: Increase timeout values for slow operations
4. **Race Conditions**: Use proper async/await patterns

### Debugging Commands
```bash
# Run tests with verbose output
flutter test --verbose

# Run specific test with debugging
flutter test --debug test/security_raffle_test.dart

# Run tests in isolation
flutter test --no-test-assets test/raffle_models_test.dart
```

## Contributing to Tests

### Adding New Tests
1. Follow existing naming conventions
2. Include both positive and negative test cases
3. Add performance assertions where appropriate
4. Update this README with new test categories

### Test Best Practices
- **Descriptive test names**: Clearly indicate what is being tested
- **Arrange-Act-Assert pattern**: Structure tests clearly
- **Independent tests**: Each test should be runnable in isolation
- **Mock external dependencies**: Don't rely on real network calls
- **Clean up after tests**: Remove test data and reset state

## Coverage Reporting

Coverage reports are generated automatically and include:
- **Line coverage**: Percentage of executable lines covered
- **Branch coverage**: Decision point coverage
- **Function coverage**: Method and function coverage

Reports are available in:
- `coverage/lcov.info`: LCOV format for CI tools
- `coverage/html/`: HTML format for manual review
- Codecov integration for PR comments

## Future Enhancements

### Planned Test Improvements
- **Visual regression tests** for UI components
- **Accessibility testing** for mobile apps
- **Cross-platform compatibility** testing
- **Real device testing** integration
- **Chaos engineering** for resilience testing

### Advanced Testing Features
- **Property-based testing** for complex algorithms
- **Fuzz testing** for input validation
- **Contract testing** for API integrations
- **Performance profiling** integration