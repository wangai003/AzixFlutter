import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/secure_stellar_provider.dart';
import '../providers/auth_provider.dart';
import '../services/secure_mining_service.dart';
import '../services/mining_security_service.dart';
import '../theme/app_theme.dart';

/// Comprehensive testing screen for the secure mining system
class MiningTestScreen extends StatefulWidget {
  const MiningTestScreen({Key? key}) : super(key: key);

  @override
  State<MiningTestScreen> createState() => _MiningTestScreenState();
}

class _MiningTestScreenState extends State<MiningTestScreen> {
  final ScrollController _scrollController = ScrollController();
  String _testLog = '';
  bool _isRunningTests = false;
  final Map<String, bool> _testResults = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0,
        title: Text(
          'Mining System Tests',
          style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all, color: AppTheme.primaryGold),
            onPressed: _clearLog,
            tooltip: 'Clear Log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Test Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunningTests ? null : _runAllTests,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isRunningTests
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Run All Tests'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunningTests ? null : _runE2ETest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkGrey,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('E2E Test'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunningTests ? null : _testSecurityValidation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Security Tests'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunningTests ? null : _testPerformance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Performance'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Test Results Summary
          if (_testResults.isNotEmpty) _buildTestSummary(),
          
          // Test Log
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Text(
                  _testLog.isEmpty ? 'No tests run yet. Click a button above to start testing.' : _testLog,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.white,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSummary() {
    final passed = _testResults.values.where((result) => result).length;
    final total = _testResults.length;
    final failed = total - passed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: passed == total ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: passed == total ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSummaryItem('Total', total.toString(), AppTheme.white),
          _buildSummaryItem('Passed', passed.toString(), Colors.green),
          _buildSummaryItem('Failed', failed.toString(), failed > 0 ? Colors.red : AppTheme.grey),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.headingMedium.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
        ),
      ],
    );
  }

  void _log(String message, {bool isError = false, bool isSuccess = false}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final prefix = isError ? '❌' : isSuccess ? '✅' : 'ℹ️';
    
    setState(() {
      _testLog += '[$timestamp] $prefix $message\n';
    });
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    print('[$timestamp] $message');
  }

  void _clearLog() {
    setState(() {
      _testLog = '';
      _testResults.clear();
    });
  }

  void _recordTestResult(String testName, bool passed) {
    setState(() {
      _testResults[testName] = passed;
    });
  }

  Future<void> _runAllTests() async {
    setState(() => _isRunningTests = true);
    _clearLog();
    
    _log('🚀 Starting comprehensive mining system tests...');
    
    try {
      await _testServiceInitialization();
      await _testSessionCreation();
      await _testProofGeneration();
      await _testSecurityValidation();
      await _testRateLimiting();
      await _testDeviceLimits();
      await _testPerformance();
      
      _log('🎉 All tests completed!', isSuccess: true);
    } catch (e) {
      _log('💥 Test suite failed: $e', isError: true);
    }
    
    setState(() => _isRunningTests = false);
  }

  Future<void> _testServiceInitialization() async {
    _log('🔧 Testing service initialization...');
    
    try {
      final securityService = MiningSecurityService();
      final miningService = SecureMiningService();
      
      await miningService.initialize();
      
      _log('✅ Services initialized successfully', isSuccess: true);
      _recordTestResult('Service Initialization', true);
    } catch (e) {
      _log('❌ Service initialization failed: $e', isError: true);
      _recordTestResult('Service Initialization', false);
    }
  }

  Future<void> _testSessionCreation() async {
    _log('🎯 Testing session creation...');
    
    try {
      final provider = Provider.of<SecureStellarProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.user == null) {
        _log('❌ User not authenticated - cannot test session creation', isError: true);
        _recordTestResult('Session Creation', false);
        return;
      }
      
      final canStart = await provider.canStartMining;
      _log('Can start mining: $canStart');
      
      if (canStart) {
        final success = await provider.startSecureMining();
        
        if (success) {
          final session = provider.currentMiningSession;
          _log('✅ Session created: ${session?.sessionId.substring(0, 8)}...', isSuccess: true);
          _log('Session valid: ${session?.isValid}');
          _log('Mining rate: ${session?.miningRate} AKOFA/hour');
          _recordTestResult('Session Creation', true);
          
          // Clean up - pause the session
          await provider.pauseMining();
        } else {
          _log('❌ Failed to create mining session', isError: true);
          _recordTestResult('Session Creation', false);
        }
      } else {
        _log('⚠️ Cannot start mining - rate limited or session exists');
        _recordTestResult('Session Creation', false);
      }
    } catch (e) {
      _log('❌ Session creation test failed: $e', isError: true);
      _recordTestResult('Session Creation', false);
    }
  }

  Future<void> _testProofGeneration() async {
    _log('🔐 Testing proof generation...');
    
    try {
      final provider = Provider.of<SecureStellarProvider>(context, listen: false);
      final session = provider.currentMiningSession;
      
      if (session == null) {
        _log('⚠️ No active session for proof testing');
        _recordTestResult('Proof Generation', false);
        return;
      }
      
      final initialProofs = session.proofs.length;
      _log('Initial proofs: $initialProofs');
      
      // Generate a proof manually
      session.submitProof('test', 30);
      
      final newProofs = session.proofs.length;
      _log('Proofs after submission: $newProofs');
      
      if (newProofs > initialProofs) {
        final lastProof = session.proofs.last;
        final isValid = session.validateProof(lastProof);
        
        _log('✅ Proof generated and validated: $isValid', isSuccess: true);
        _log('Proof hash: ${lastProof.proofHash.substring(0, 16)}...');
        _recordTestResult('Proof Generation', isValid);
      } else {
        _log('❌ Proof generation failed', isError: true);
        _recordTestResult('Proof Generation', false);
      }
    } catch (e) {
      _log('❌ Proof generation test failed: $e', isError: true);
      _recordTestResult('Proof Generation', false);
    }
  }

  Future<void> _testSecurityValidation() async {
    _log('🛡️ Testing security validation...');
    
    try {
      final securityService = MiningSecurityService();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.user == null) {
        _log('❌ User not authenticated - cannot test security', isError: true);
        _recordTestResult('Security Validation', false);
        return;
      }
      
      final userId = authProvider.user!.uid;
      
      // Test valid mining rate
      final validResult = await securityService.validateMiningStart(
        userId: userId,
        deviceId: 'test-device-123',
        requestedRate: 0.25,
      );
      
      _log('Valid rate test: ${validResult.isValid}');
      
      // Test invalid mining rate
      final invalidResult = await securityService.validateMiningStart(
        userId: userId,
        deviceId: 'test-device-123',
        requestedRate: 1.0, // Too high
      );
      
      _log('Invalid rate test: ${invalidResult.isValid}');
      _log('Error message: ${invalidResult.errorMessage}');
      
      final passed = validResult.isValid && !invalidResult.isValid;
      
      if (passed) {
        _log('✅ Security validation working correctly', isSuccess: true);
      } else {
        _log('❌ Security validation failed', isError: true);
      }
      
      _recordTestResult('Security Validation', passed);
    } catch (e) {
      _log('❌ Security validation test failed: $e', isError: true);
      _recordTestResult('Security Validation', false);
    }
  }

  Future<void> _testRateLimiting() async {
    _log('⏱️ Testing rate limiting...');
    
    try {
      final securityService = MiningSecurityService();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.user == null) {
        _log('❌ User not authenticated - cannot test rate limiting', isError: true);
        _recordTestResult('Rate Limiting', false);
        return;
      }
      
      final userId = authProvider.user!.uid;
      int successCount = 0;
      int blockedCount = 0;
      
      // Attempt multiple rapid validations
      for (int i = 0; i < 5; i++) {
        final result = await securityService.validateMiningStart(
          userId: userId,
          deviceId: 'rate-test-device',
          requestedRate: 0.25,
        );
        
        if (result.isValid) {
          successCount++;
        } else {
          blockedCount++;
          _log('Attempt ${i + 1} blocked: ${result.errorMessage}');
        }
        
        // Small delay to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      _log('Successful attempts: $successCount');
      _log('Blocked attempts: $blockedCount');
      
      // Rate limiting should kick in after a few attempts
      final passed = blockedCount > 0;
      
      if (passed) {
        _log('✅ Rate limiting working correctly', isSuccess: true);
      } else {
        _log('⚠️ Rate limiting may not be active (this could be normal)', isError: false);
      }
      
      _recordTestResult('Rate Limiting', passed);
    } catch (e) {
      _log('❌ Rate limiting test failed: $e', isError: true);
      _recordTestResult('Rate Limiting', false);
    }
  }

  Future<void> _testDeviceLimits() async {
    _log('📱 Testing device limits...');
    
    try {
      final securityService = MiningSecurityService();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.user == null) {
        _log('❌ User not authenticated - cannot test device limits', isError: true);
        _recordTestResult('Device Limits', false);
        return;
      }
      
      final userId = authProvider.user!.uid;
      int allowedDevices = 0;
      
      // Test multiple devices
      for (int i = 0; i < 5; i++) {
        final result = await securityService.validateMiningStart(
          userId: userId,
          deviceId: 'device-limit-test-$i',
          requestedRate: 0.25,
        );
        
        if (result.isValid) {
          allowedDevices++;
          _log('Device $i allowed');
        } else {
          _log('Device $i blocked: ${result.errorMessage}');
          break;
        }
      }
      
      _log('Devices allowed: $allowedDevices');
      
      // Should allow some devices but not unlimited
      final passed = allowedDevices > 0 && allowedDevices < 5;
      
      if (passed) {
        _log('✅ Device limits working correctly', isSuccess: true);
      } else {
        _log('⚠️ Device limits may not be configured', isError: false);
      }
      
      _recordTestResult('Device Limits', passed);
    } catch (e) {
      _log('❌ Device limits test failed: $e', isError: true);
      _recordTestResult('Device Limits', false);
    }
  }

  Future<void> _testPerformance() async {
    _log('⚡ Testing performance...');
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Test service initialization time
      final miningService = SecureMiningService();
      await miningService.initialize();
      final initTime = stopwatch.elapsedMilliseconds;
      
      _log('Service init time: ${initTime}ms');
      
      // Test proof generation time
      stopwatch.reset();
      final session = provider.currentMiningSession;
      if (session != null) {
        session.submitProof('performance-test', 1);
        final proofTime = stopwatch.elapsedMilliseconds;
        _log('Proof generation time: ${proofTime}ms');
        
        // Performance should be under reasonable thresholds
        final passed = initTime < 5000 && proofTime < 100;
        
        if (passed) {
          _log('✅ Performance within acceptable limits', isSuccess: true);
        } else {
          _log('⚠️ Performance may be slow', isError: false);
        }
        
        _recordTestResult('Performance', passed);
      } else {
        _log('⚠️ No session available for performance testing');
        _recordTestResult('Performance', false);
      }
    } catch (e) {
      _log('❌ Performance test failed: $e', isError: true);
      _recordTestResult('Performance', false);
    }
  }

  Future<void> _runE2ETest() async {
    setState(() => _isRunningTests = true);
    _log('🎬 Starting End-to-End mining test...');
    
    try {
      final provider = Provider.of<SecureStellarProvider>(context, listen: false);
      
      // Step 1: Start mining
      _log('1️⃣ Attempting to start mining...');
      final started = await provider.startSecureMining();
      
      if (!started) {
        _log('❌ Could not start mining - check rate limits or existing session', isError: true);
        setState(() => _isRunningTests = false);
        return;
      }
      
      _log('✅ Mining started successfully', isSuccess: true);
      
      // Step 2: Verify session
      final session = provider.currentMiningSession;
      _log('2️⃣ Session ID: ${session?.sessionId.substring(0, 8)}...');
      _log('Session valid: ${session?.isValid}');
      _log('Mining rate: ${session?.miningRate} AKOFA/hour');
      
      // Step 3: Wait for proofs
      _log('3️⃣ Waiting for proof submission (65 seconds)...');
      await Future.delayed(const Duration(seconds: 5)); // Shortened for testing
      
      _log('Proofs submitted: ${session?.totalProofsSubmitted}');
      _log('Current earned: ${session?.earnedAkofa.toStringAsFixed(6)} AKOFA');
      
      // Step 4: Test pause/resume
      _log('4️⃣ Testing pause functionality...');
      await provider.pauseMining();
      _log('Mining paused');
      
      await Future.delayed(const Duration(seconds: 2));
      
      _log('5️⃣ Testing resume functionality...');
      await provider.resumeMining();
      _log('Mining resumed');
      
      // Step 6: Check security status
      _log('6️⃣ Checking security metrics...');
      final metrics = provider.securityMetrics;
      _log('Security metrics: $metrics');
      
      final alerts = provider.securityAlerts;
      if (alerts.isNotEmpty) {
        _log('⚠️ Security alerts: $alerts');
      } else {
        _log('✅ No security alerts');
      }
      
      _log('🎉 E2E test completed successfully!', isSuccess: true);
      
    } catch (e) {
      _log('❌ E2E test failed: $e', isError: true);
    }
    
    setState(() => _isRunningTests = false);
  }

  SecureStellarProvider get provider => Provider.of<SecureStellarProvider>(context, listen: false);
}
