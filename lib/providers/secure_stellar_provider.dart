import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/secure_mining_session.dart';
import '../services/secure_mining_service.dart';
import '../services/stellar_service.dart';
import '../services/real_time_mining_service.dart';

/// Enhanced Stellar provider with secure mining capabilities
class SecureStellarProvider extends ChangeNotifier {
  final StellarService _stellarService;
  final SecureMiningService _securityService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final RealTimeMiningService _realTimeMiningService;

  // State management
  bool _hasWallet = false;
  bool _isLoading = false;
  String? _error;
  String? _publicKey;
  String _balance = '0';
  bool _hasAkofaTrustline = false;
  List<Map<String, dynamic>> _transactions = [];
  bool _isTransactionLoading = false;
  List<Map<String, dynamic>> _walletAssets = [];
  bool _isLoadingWalletAssets = false;

  // Mining state
  SecureMiningSession? _currentMiningSession;
  Timer? _miningUpdateTimer;
  bool _isLoadingMiningSessions = false;
  
  // Security monitoring
  Map<String, dynamic> _securityMetrics = {};
  List<String> _securityAlerts = [];
  DateTime? _lastSecurityCheck;
  String? _deviceId;

  SecureStellarProvider({
    StellarService? stellarService,
    SecureMiningService? securityService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    RealTimeMiningService? realTimeMiningService,
  }) : _stellarService = stellarService ?? StellarService(),
       _securityService = securityService ?? SecureMiningService(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _realTimeMiningService = realTimeMiningService ?? RealTimeMiningService(stellarService ?? StellarService()) {
    _initialize();
  }

  // Getters
  bool get hasWallet => _hasWallet;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get publicKey => _publicKey;
  String get balance => _balance;
  bool get hasAkofaTrustline => _hasAkofaTrustline;
  List<Map<String, dynamic>> get transactions => _transactions;
  bool get isTransactionLoading => _isTransactionLoading;
  List<Map<String, dynamic>> get walletAssets => _walletAssets;
  bool get isLoadingWalletAssets => _isLoadingWalletAssets;
  SecureMiningSession? get currentMiningSession => _currentMiningSession;
  bool get isLoadingMiningSessions => _isLoadingMiningSessions;
  Map<String, dynamic> get securityMetrics => _securityMetrics;
  List<String> get securityAlerts => _securityAlerts;
  DateTime? get lastSecurityCheck => _lastSecurityCheck;

  /// Initialize the provider
  Future<void> _initialize() async {
    await _securityService.initialize();
    await _realTimeMiningService.initialize();
    await _loadWalletState();
    await _loadMiningSession();
    _startSecurityMonitoring();
    _subscribeToRealTimeUpdates();
  }

  /// Subscribe to real-time mining updates
  void _subscribeToRealTimeUpdates() {
    _realTimeMiningService.sessionStream.listen((session) {
      _currentMiningSession = session;
      notifyListeners(); // This is crucial for UI updates!
      print('🔄 Real-time mining update: ${session.earnedAkofa.toStringAsFixed(6)} AKOFA');
    });
  }

  /// Load wallet state
  Future<void> _loadWalletState() async {
    _setLoading(true);
    try {
      final credentials = await _stellarService.getWalletCredentials();
      if (credentials != null) {
        _hasWallet = true;
        _publicKey = credentials['publicKey'];
        await refreshBalance();
        await checkAkofaTrustline();
      }
    } catch (e) {
      _setError('Failed to load wallet: $e');
    }
    _setLoading(false);
  }

  /// Load mining session
  Future<void> _loadMiningSession() async {
    _isLoadingMiningSessions = true;
    notifyListeners();
    
    try {
      // Load from real-time service first
      _currentMiningSession = _realTimeMiningService.getCurrentSession();
      
      // Fallback to security service if needed
      if (_currentMiningSession == null) {
        _currentMiningSession = await _securityService.loadSession();
      }
      
      if (_currentMiningSession != null) {
        _startMiningUpdateTimer();
      }
    } catch (e) {
      _setError('Failed to load mining session: $e');
    }
    
    _isLoadingMiningSessions = false;
    notifyListeners();
  }



  /// Start security monitoring
  void _startSecurityMonitoring() {
    Timer.periodic(const Duration(minutes: 10), (_) => _performSecurityCheck());
  }

  /// Perform periodic security check
  Future<void> _performSecurityCheck() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get mining statistics and security metrics
      _securityMetrics = await _securityService.getMiningStatistics(userId);
      
      // Check for security alerts
      _checkSecurityAlerts();
      
      // Validate current session integrity
      if (_currentMiningSession != null && !_currentMiningSession!.isValid) {
        _addSecurityAlert('Session integrity compromised');
        await _terminateMiningSession('integrity_violation');
      }
      
      _lastSecurityCheck = DateTime.now();
      notifyListeners();
      
    } catch (e) {
      print('Error during security check: $e');
    }
  }

  /// Check for security alerts based on metrics
  void _checkSecurityAlerts() {
    _securityAlerts.clear();
    
    final trustLevel = _securityMetrics['trustLevel'] ?? 'new';
    final flaggedSessions = _securityMetrics['flaggedSessions'] ?? 0;
    final integrityScore = _securityMetrics['integrityScore'] ?? 1.0;
    
    if (trustLevel == 'low') {
      _addSecurityAlert('Low trust level detected');
    }
    
    if (flaggedSessions > 0) {
      _addSecurityAlert('$flaggedSessions flagged sessions found');
    }
    
    if (integrityScore < 0.8) {
      _addSecurityAlert('Low integrity score: ${(integrityScore * 100).toStringAsFixed(1)}%');
    }
  }

  /// Add security alert
  void _addSecurityAlert(String alert) {
    if (!_securityAlerts.contains(alert)) {
      _securityAlerts.add(alert);
    }
  }

  /// Start secure mining
  Future<bool> startSecureMining() async {
    if (!_hasWallet || _publicKey == null) {
      _setError('Wallet required for mining');
      return false;
    }

    try {
      _setLoading(true);
      
      // Check if user can start mining
      if (!await _securityService.canStartMining()) {
        _setError('Cannot start mining: Daily limit reached or session in progress');
        return false;
      }

      // Get user ID and device ID
      final user = _auth.currentUser;
      if (user == null) {
        _setError('User not authenticated');
        return false;
      }
      
      final deviceId = await _getDeviceId();
      
      // Start real-time mining session
      _currentMiningSession = await _realTimeMiningService.startSession(user.uid, deviceId);
      
      // Also register with security service for monitoring
      await _securityService.startMining(await _getUserMiningRate());
      
      if (_currentMiningSession != null) {
        _startMiningUpdateTimer();
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      _setError('Failed to start mining: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get user's mining rate based on referrals and boosts
  Future<double> _getUserMiningRate() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0.25; // Default rate

      final userDoc = await _firestore.collection('USER').doc(userId).get();
      if (!userDoc.exists) return 0.25;

      final userData = userDoc.data()!;
      final isRateBoosted = userData['miningRateBoosted'] ?? false;
      final referralCount = userData['referralCount'] ?? 0;

      // Apply boost if eligible
      if (isRateBoosted && referralCount >= 5) {
        return 0.50; // 2x boost
      }
      
      return 0.25; // Base rate
    } catch (e) {
      print('Error getting mining rate: $e');
      return 0.25;
    }
  }

  /// Start mining update timer
  void _startMiningUpdateTimer() {
    _miningUpdateTimer?.cancel();
    _miningUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateMiningProgress(),
    );
  }

  /// Update mining progress
  void _updateMiningProgress() {
    final session = _currentMiningSession;
    if (session == null || !session.isActive) {
      _miningUpdateTimer?.cancel();
      return;
    }

    // Check if session has expired
    if (session.isExpired) {
      _endMiningSession();
      return;
    }

    // Update UI
    notifyListeners();
  }

  /// Pause mining
  Future<void> pauseMining() async {
    if (_currentMiningSession == null) return;
    
    try {
      await _realTimeMiningService.pauseSession();
      // Don't need to call notifyListeners() as stream will handle it
    } catch (e) {
      _setError('Failed to pause mining: $e');
    }
  }

  /// Resume mining
  Future<void> resumeMining() async {
    if (_currentMiningSession == null) return;
    
    try {
      await _realTimeMiningService.resumeSession();
      // Don't need to call notifyListeners() as stream will handle it
    } catch (e) {
      _setError('Failed to resume mining: $e');
    }
  }

  /// End mining session and process rewards
  Future<void> _endMiningSession() async {
    try {
      _miningUpdateTimer?.cancel();
      
      if (_currentMiningSession == null) return;
      
      // End the secure mining session
      final history = await _securityService.endMining();
      
      // Only process rewards if session is valid
      if (history.status == 'completed' && history.earnedAkofa > 0) {
        await _processSecureMiningReward(history);
      } else {
        print('Mining session flagged or invalid, no rewards processed');
      }
      
      _currentMiningSession = null;
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to end mining session: $e');
    }
  }

  /// Process mining reward with enhanced security
  Future<void> _processSecureMiningReward(SecureMiningSessionHistory history) async {
    try {
      // Validate reward amount
      if (history.earnedAkofa <= 0) {
        throw Exception('Invalid reward amount');
      }

      // Check for double-spending
      if (await _checkDuplicateReward(history.sessionId)) {
        throw Exception('Duplicate reward detected');
      }

      // Generate secure transaction hash
      final transactionHash = _generateSecureTransactionHash(history);
      
      // Record mining reward through Stellar service
      final result = await _stellarService.recordMiningReward(history.earnedAkofa);
      
      if (result['success'] == true) {
        // Update history with transaction details
        await _updateHistoryWithTransaction(history, result['hash'], transactionHash);
        
        // Refresh wallet balance
        await refreshBalance();
        await loadTransactions();
        
        print('Secure mining reward processed: ${history.earnedAkofa} AKOFA');
      } else {
        throw Exception('Failed to record reward: ${result['message']}');
      }
      
    } catch (e) {
      print('Error processing mining reward: $e');
      await _markRewardAsFailed(history, e.toString());
    }
  }

  /// Check for duplicate reward to prevent double-spending
  Future<bool> _checkDuplicateReward(String sessionId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final existingRewards = await _firestore
          .collection('secure_mining_history')
          .doc(userId)
          .collection('sessions')
          .where('sessionId', isEqualTo: sessionId)
          .where('status', isEqualTo: 'completed')
          .get();

      return existingRewards.docs.isNotEmpty;
    } catch (e) {
      print('Error checking duplicate reward: $e');
      return true; // Err on the side of caution
    }
  }

  /// Generate secure transaction hash
  String _generateSecureTransactionHash(SecureMiningSessionHistory history) {
    final input = '${history.sessionId}:${history.userId}:${history.earnedAkofa}:${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Update history with transaction details
  Future<void> _updateHistoryWithTransaction(
    SecureMiningSessionHistory history,
    String stellarHash,
    String transactionHash,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('secure_mining_history')
          .doc(userId)
          .collection('sessions')
          .where('sessionId', isEqualTo: history.sessionId)
          .get()
          .then((query) {
        if (query.docs.isNotEmpty) {
          query.docs.first.reference.update({
            'stellarHash': stellarHash,
            'transactionHash': transactionHash,
            'processedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error updating history with transaction: $e');
    }
  }

  /// Mark reward as failed
  Future<void> _markRewardAsFailed(SecureMiningSessionHistory history, String error) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('secure_mining_history')
          .doc(userId)
          .collection('sessions')
          .where('sessionId', isEqualTo: history.sessionId)
          .get()
          .then((query) {
        if (query.docs.isNotEmpty) {
          query.docs.first.reference.update({
            'status': 'failed',
            'errorReason': error,
            'failedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error marking reward as failed: $e');
    }
  }

  /// Terminate mining session due to security violation
  Future<void> _terminateMiningSession(String reason) async {
    try {
      _miningUpdateTimer?.cancel();
      _currentMiningSession = null;
      
      // Log security violation
      await _firestore.collection('security_violations').add({
        'userId': _auth.currentUser?.uid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceId': _deviceId,
      });
      
      _addSecurityAlert('Mining session terminated: $reason');
      notifyListeners();
      
    } catch (e) {
      print('Error terminating mining session: $e');
    }
  }

  /// Check if can start mining
  Future<bool> get canStartMining async {
    if (!_hasWallet || _currentMiningSession?.isActive == true) return false;
    return await _securityService.canStartMining();
  }

  // Wallet operations (unchanged from original)
  Future<bool> createWallet() async {
    _setLoading(true);
    _setError(null);
    
    try {
      final result = await _stellarService.createWalletAndStoreInFirestore();
      final success = result['status'] == 'success';
      if (success) {
        final credentials = await _stellarService.getWalletCredentials();
        if (credentials != null) {
          _hasWallet = true;
          _publicKey = credentials['publicKey'];
          await refreshBalance();
        }
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to create wallet: $e');
      return false;
    }
  }

  Future<void> refreshBalance() async {
    if (!_hasWallet || _publicKey == null) return;
    
    try {
      _balance = await _stellarService.getBalance(_publicKey!);
      notifyListeners();
    } catch (e) {
      _setError('Failed to refresh balance: $e');
    }
  }

  Future<void> checkAkofaTrustline() async {
    if (!_hasWallet || _publicKey == null) return;
    
    try {
      _hasAkofaTrustline = await _stellarService.hasAkofaTrustline(_publicKey!);
      notifyListeners();
    } catch (e) {
      _setError('Failed to check Akofa trustline: $e');
    }
  }

  Future<void> loadTransactions() async {
    if (!_hasWallet) return;
    
    _isTransactionLoading = true;
    notifyListeners();
    
    try {
      final txHistory = await _stellarService.getTransactionHistory();
      _transactions = txHistory.map((tx) => tx.toMap()).toList();
      _isTransactionLoading = false;
      notifyListeners();
    } catch (e) {
      _isTransactionLoading = false;
      _setError('Failed to load transactions: $e');
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _miningUpdateTimer?.cancel();
    _securityService.dispose();
    _realTimeMiningService.dispose();
    super.dispose();
  }

  /// Get device ID for mining sessions
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    
    // Generate a persistent device ID
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    
    if (_deviceId == null) {
      _deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', _deviceId!);
    }
    
    return _deviceId!;
  }
}
