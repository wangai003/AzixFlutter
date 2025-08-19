# Secure Mining System - Testing Guide

## Step-by-Step Testing Procedure

### Phase 1: Environment Setup

#### 1.1 Install Dependencies
```bash
# Navigate to your Flutter project
cd azixflutter

# Get latest dependencies
flutter pub get

# Clean build cache
flutter clean
```

#### 1.2 Verify Dependencies
Check that these packages are in your `pubspec.yaml`:
```yaml
dependencies:
  crypto: ^3.0.3
  device_info_plus: ^11.5.0
  cloud_firestore: ^5.6.11
  firebase_auth: ^5.6.2
  shared_preferences: ^2.2.2
  provider: ^6.1.1
```

#### 1.3 Firebase Setup
Ensure your Firebase project has the following collections configured:
- `secure_mining_sessions`
- `secure_mining_history`
- `security_audit`
- `mining_attempts`

### Phase 2: Integration Steps

#### 2.1 Update Main Application
Create or update your main application to use the new secure provider:

```dart
// lib/main.dart
import 'package:provider/provider.dart';
import 'providers/secure_stellar_provider.dart';
import 'services/secure_mining_service.dart';
import 'services/mining_security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SecureStellarProvider()),
        Provider(create: (_) => SecureMiningService()),
        Provider(create: (_) => MiningSecurityService()),
      ],
      child: MyApp(),
    ),
  );
}
```

#### 2.2 Update Navigation
Add the secure mining screen to your app routing:

```dart
// lib/routes.dart or wherever you handle navigation
import 'screens/secure_mining_screen.dart';

// Add to your routes
'/secure-mining': (context) => const SecureMiningScreen(),
```

#### 2.3 Replace Existing Mining Screen
Update your navigation to use the new secure mining screen:

```dart
// Replace old mining screen calls with:
Navigator.pushNamed(context, '/secure-mining');
```

### Phase 3: Testing Procedures

#### 3.1 Basic Functionality Tests

##### Test 1: Service Initialization
```dart
// Create a test file: test/secure_mining_test.dart
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/secure_mining_service.dart';

void main() {
  group('Secure Mining Service Tests', () {
    test('Service initializes correctly', () async {
      final service = SecureMiningService();
      await service.initialize();
      expect(service, isNotNull);
    });
  });
}
```

Run test:
```bash
flutter test test/secure_mining_test.dart
```

##### Test 2: Session Creation
Create a manual test in your app:

```dart
// Add this to a test screen or button
Future<void> testSessionCreation() async {
  final service = SecureMiningService();
  await service.initialize();
  
  final session = await service.startMining(0.25);
  print('Session created: ${session?.sessionId}');
  print('Session valid: ${session?.isValid}');
}
```

#### 3.2 Security Validation Tests

##### Test 3: Rate Limiting
```dart
// Test multiple rapid mining attempts
Future<void> testRateLimiting() async {
  final securityService = MiningSecurityService();
  
  for (int i = 0; i < 5; i++) {
    final result = await securityService.validateMiningStart(
      userId: 'test-user',
      deviceId: 'test-device',
      requestedRate: 0.25,
    );
    print('Attempt $i: ${result.isValid}');
    if (!result.isValid) {
      print('Blocked: ${result.errorMessage}');
    }
  }
}
```

##### Test 4: Device Limits
```dart
// Test device limit enforcement
Future<void> testDeviceLimits() async {
  final securityService = MiningSecurityService();
  
  for (int i = 0; i < 5; i++) {
    final result = await securityService.validateMiningStart(
      userId: 'test-user',
      deviceId: 'test-device-$i',
      requestedRate: 0.25,
    );
    print('Device $i: ${result.isValid}');
  }
}
```

#### 3.3 Cryptographic Tests

##### Test 5: Proof Generation
```dart
// Test proof-of-work validation
void testProofGeneration() {
  final session = SecureMiningSession.newSession(
    userId: 'test-user',
    deviceId: 'test-device',
    miningRate: 0.25,
  );
  
  // Submit a proof
  session.submitProof('mining', 60);
  
  // Validate the proof
  final proof = session.proofs.last;
  final isValid = session.validateProof(proof);
  print('Proof valid: $isValid');
}
```

### Phase 4: Integration Testing

#### 4.1 End-to-End Mining Flow Test

Create a comprehensive test function:

```dart
// lib/testing/e2e_mining_test.dart
import 'package:flutter/material.dart';
import '../providers/secure_stellar_provider.dart';

class MiningE2ETest extends StatefulWidget {
  @override
  _MiningE2ETestState createState() => _MiningE2ETestState();
}

class _MiningE2ETestState extends State<MiningE2ETest> {
  String _testResults = '';
  
  Future<void> runFullMiningTest() async {
    setState(() => _testResults = 'Starting E2E test...\n');
    
    try {
      final provider = Provider.of<SecureStellarProvider>(context, listen: false);
      
      // Test 1: Start mining
      _log('1. Testing mining start...');
      final started = await provider.startSecureMining();
      _log('Mining started: $started');
      
      if (started) {
        // Test 2: Check session validity
        _log('2. Checking session validity...');
        final session = provider.currentMiningSession;
        _log('Session valid: ${session?.isValid}');
        
        // Test 3: Wait and check proof submission
        _log('3. Waiting for proof submission...');
        await Future.delayed(Duration(seconds: 65));
        _log('Proofs submitted: ${session?.totalProofsSubmitted}');
        
        // Test 4: Pause and resume
        _log('4. Testing pause/resume...');
        await provider.pauseMining();
        _log('Mining paused');
        await Future.delayed(Duration(seconds: 2));
        await provider.resumeMining();
        _log('Mining resumed');
        
        // Test 5: Check security metrics
        _log('5. Checking security metrics...');
        final metrics = provider.securityMetrics;
        _log('Security metrics: $metrics');
      }
      
      _log('E2E test completed successfully!');
    } catch (e) {
      _log('E2E test failed: $e');
    }
  }
  
  void _log(String message) {
    setState(() {
      _testResults += '$message\n';
    });
    print(message);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mining E2E Test')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: runFullMiningTest,
            child: Text('Run E2E Test'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Text(_testResults),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 4.2 Security Monitoring Test

```dart
// Test security monitoring and alerts
Future<void> testSecurityMonitoring() async {
  final provider = Provider.of<SecureStellarProvider>(context, listen: false);
  
  // Monitor security alerts
  provider.addListener(() {
    if (provider.securityAlerts.isNotEmpty) {
      print('Security alerts: ${provider.securityAlerts}');
    }
  });
  
  // Trigger security check
  await provider._performSecurityCheck();
}
```

### Phase 5: Production Deployment Testing

#### 5.1 Firebase Rules Configuration

Update your Firestore security rules:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Secure mining sessions
    match /secure_mining_sessions/{sessionId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == resource.data.userId;
    }
    
    // Mining history
    match /secure_mining_history/{userId}/sessions/{sessionId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
    
    // Security audit (admin only)
    match /security_audit/{auditId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // Service account writes
    }
    
    // Mining attempts (user specific)
    match /mining_attempts/{userId}/attempts/{attemptId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
  }
}
```

#### 5.2 Performance Testing

```dart
// Test performance impact
Future<void> performanceTest() async {
  final stopwatch = Stopwatch()..start();
  
  // Test session creation time
  final service = SecureMiningService();
  await service.initialize();
  final initTime = stopwatch.elapsedMilliseconds;
  print('Initialization time: ${initTime}ms');
  
  stopwatch.reset();
  final session = await service.startMining(0.25);
  final sessionTime = stopwatch.elapsedMilliseconds;
  print('Session creation time: ${sessionTime}ms');
  
  // Test proof generation time
  stopwatch.reset();
  session?.submitProof('mining', 60);
  final proofTime = stopwatch.elapsedMilliseconds;
  print('Proof generation time: ${proofTime}ms');
}
```

### Phase 6: User Acceptance Testing

#### 6.1 Create Test User Accounts

1. Create multiple test accounts with different referral levels:
   - User A: 0 referrals (base rate: 0.25)
   - User B: 5+ referrals (boosted rate: 0.50)
   - User C: Flagged user (previous violations)

#### 6.2 Test Scenarios

##### Scenario 1: Normal Mining Flow
1. Login as User A
2. Navigate to secure mining screen
3. Start mining
4. Observe real-time updates
5. Let session run for 10 minutes
6. Check proof submissions
7. End session manually
8. Verify tokens credited

##### Scenario 2: Rate Limiting
1. Login as User B
2. Attempt to start mining 4 times rapidly
3. Verify 4th attempt is blocked
4. Wait 1 hour and try again

##### Scenario 3: Device Switching
1. Login from Device 1, start mining
2. Login from Device 2, attempt to start mining
3. Verify only one session allowed

##### Scenario 4: Security Violations
1. Attempt to manipulate session data
2. Verify security alerts appear
3. Check audit trail in Firebase

### Phase 7: Monitoring Setup

#### 7.1 Create Firebase Cloud Functions for Monitoring

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Monitor security violations
exports.monitorSecurityViolations = functions.firestore
  .document('security_audit/{auditId}')
  .onCreate((snap, context) => {
    const violation = snap.data();
    
    if (violation.severity === 'high') {
      // Send alert to admin
      console.log('High severity violation:', violation);
      // Implement notification logic
    }
  });

// Monitor mining statistics
exports.generateMiningStats = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    // Generate daily mining statistics
    const stats = await calculateDailyStats();
    await admin.firestore()
      .collection('mining_stats')
      .add(stats);
  });
```

#### 7.2 Dashboard Queries

Create these Firestore queries for monitoring:

```dart
// Active sessions count
Stream<int> getActiveSessionsCount() {
  return FirebaseFirestore.instance
    .collection('secure_mining_sessions')
    .where('sessionEnd', isGreaterThan: Timestamp.now())
    .snapshots()
    .map((snapshot) => snapshot.docs.length);
}

// Security violations in last 24h
Stream<List<Map<String, dynamic>>> getRecentViolations() {
  final yesterday = DateTime.now().subtract(Duration(days: 1));
  return FirebaseFirestore.instance
    .collection('security_audit')
    .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
    .where('severity', isEqualTo: 'high')
    .snapshots()
    .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}
```

### Phase 8: Deployment Checklist

#### 8.1 Pre-deployment
- [ ] All tests pass
- [ ] Firebase rules deployed
- [ ] Security monitoring configured
- [ ] Performance benchmarks met
- [ ] User acceptance testing completed

#### 8.2 Deployment
- [ ] Deploy to staging environment
- [ ] Run smoke tests
- [ ] Deploy to production
- [ ] Monitor for 24 hours
- [ ] Verify all security features working

#### 8.3 Post-deployment
- [ ] Monitor security audit logs
- [ ] Check performance metrics
- [ ] Verify user mining sessions
- [ ] Review error rates
- [ ] Collect user feedback

### Troubleshooting Common Issues

#### Issue 1: Session Creation Fails
```dart
// Debug session creation
try {
  final session = await service.startMining(0.25);
  if (session == null) {
    print('Session creation failed - check rate limits');
  }
} catch (e) {
  print('Session error: $e');
  // Check Firebase permissions, network connectivity
}
```

#### Issue 2: Proofs Not Submitting
```dart
// Check proof timer
if (session.proofs.isEmpty) {
  print('No proofs submitted - check timer');
  // Verify timer is running, check network
}
```

#### Issue 3: Security Alerts Firing
```dart
// Review security metrics
final metrics = provider.securityMetrics;
print('Trust level: ${metrics['trustLevel']}');
print('Flagged sessions: ${metrics['flaggedSessions']}');
// Investigate flagged patterns
```

This comprehensive testing guide ensures your secure mining system is thoroughly validated before production deployment.
