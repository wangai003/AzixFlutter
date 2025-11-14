import 'package:flutter/material.dart';
import '../bridge_config.dart';
import '../models/route_models.dart' as bridge_models;
import '../models/bridge_job.dart';
import '../services/lifi_client.dart';
import '../services/job_store.dart';
import '../services/route_executor.dart';
import '../crypto/stellar_signer.dart';
import '../crypto/evm_signer.dart';
import '../../services/stellar_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Bridge provider for state management
class BridgeProvider extends ChangeNotifier {
  final LifiClient _lifiClient;
  final JobStore _jobStore;
  final RouteExecutor _routeExecutor;
  final StellarSigner _stellarSigner;
  final EvmSigner _evmSigner;
  final StellarService _stellarService = StellarService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State
  bool _isLoading = false;
  String? _error;
  List<bridge_models.BridgeRoute> _availableRoutes = [];
  bridge_models.BridgeRoute? _selectedRoute;
  BridgeJob? _currentJob;
  List<BridgeJob> _jobHistory = [];

  // Quote request state
  String? _fromChain;
  String? _toChain;
  String? _fromToken;
  String? _toToken;
  String? _fromAmount;
  String? _fromAddress;
  String? _toAddress;

  BridgeProvider({
    LifiClient? lifiClient,
    JobStore? jobStore,
    StellarSigner? stellarSigner,
    EvmSigner? evmSigner,
  })  : _lifiClient = lifiClient ?? LifiClient(),
        _jobStore = jobStore ?? JobStore(),
        _stellarSigner = stellarSigner ?? StellarSigner(useTestnet: BridgeConfig.useTestnet),
        _evmSigner = evmSigner ?? EvmSigner(),
        _routeExecutor = RouteExecutor(
          lifiClient: lifiClient ?? LifiClient(),
          jobStore: jobStore ?? JobStore(),
          stellarSigner: stellarSigner ?? StellarSigner(useTestnet: BridgeConfig.useTestnet),
          evmSigner: evmSigner ?? EvmSigner(),
        ) {
    _initialize();
  }

  Future<void> _initialize() async {
    await loadJobHistory();
    await _evmSigner.initialize();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<bridge_models.BridgeRoute> get availableRoutes => _availableRoutes;
  bridge_models.BridgeRoute? get selectedRoute => _selectedRoute;
  BridgeJob? get currentJob => _currentJob;
  List<BridgeJob> get jobHistory => _jobHistory;

  String? get fromChain => _fromChain;
  String? get toChain => _toChain;
  String? get fromToken => _fromToken;
  String? get toToken => _toToken;
  String? get fromAmount => _fromAmount;
  String? get fromAddress => _fromAddress;
  String? get toAddress => _toAddress;

  /// Set quote parameters
  void setQuoteParams({
    String? fromChain,
    String? toChain,
    String? fromToken,
    String? toToken,
    String? fromAmount,
    String? fromAddress,
    String? toAddress,
  }) {
    _fromChain = fromChain ?? _fromChain;
    _toChain = toChain ?? _toChain;
    _fromToken = fromToken ?? _fromToken;
    _toToken = toToken ?? _toToken;
    _fromAmount = fromAmount ?? _fromAmount;
    _fromAddress = fromAddress ?? _fromAddress;
    _toAddress = toAddress ?? _toAddress;
    
    // Clear error when parameters are updated
    if (fromChain != null || toChain != null || fromToken != null || 
        toToken != null || fromAmount != null || fromAddress != null || 
        toAddress != null) {
      _error = null;
    }
    
    notifyListeners();
  }

  /// Get quote from LI.FI
  Future<void> getQuote() async {
    // Check all required fields
    final missingFields = <String>[];
    
    if (_fromChain == null || _fromChain!.isEmpty) {
      missingFields.add('From Chain');
    }
    if (_toChain == null || _toChain!.isEmpty) {
      missingFields.add('To Chain');
    }
    if (_fromToken == null || _fromToken!.isEmpty) {
      missingFields.add('From Token');
    }
    if (_toToken == null || _toToken!.isEmpty) {
      missingFields.add('To Token');
    }
    if (_fromAmount == null || _fromAmount!.trim().isEmpty) {
      missingFields.add('Amount');
    }
    if (_fromAddress == null || _fromAddress!.trim().isEmpty) {
      missingFields.add('From Address');
    }
    if (_toAddress == null || _toAddress!.trim().isEmpty) {
      missingFields.add('To Address');
    }
    
    if (missingFields.isNotEmpty) {
      _error = 'Please fill in all required fields:\n${missingFields.join(', ')}';
      notifyListeners();
      return;
    }

    _setLoading(true);
    _error = null; // Clear previous errors
    notifyListeners(); // Update UI immediately

    try {
      final request = bridge_models.QuoteRequest(
        fromChain: _fromChain!.trim(),
        toChain: _toChain!.trim(),
        fromToken: _fromToken!.trim(),
        toToken: _toToken!.trim(),
        fromAmount: _fromAmount!.trim(),
        fromAddress: _fromAddress!.trim(),
        toAddress: _toAddress!.trim(),
        allowBridges: BridgeConfig.preferredProviders,
      );

      final routes = await _lifiClient.getQuote(request);
      
      _availableRoutes = routes;
      if (routes.isNotEmpty) {
        _selectedRoute = routes.first; // Select best route by default
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Select a route
  void selectRoute(bridge_models.BridgeRoute route) {
    _selectedRoute = route;
    notifyListeners();
  }

  /// Execute selected route
  Future<BridgeJob> executeRoute() async {
    if (_selectedRoute == null) {
      throw Exception('No route selected');
    }

    if (_fromChain == null ||
        _toChain == null ||
        _fromToken == null ||
        _toToken == null ||
        _fromAmount == null ||
        _fromAddress == null ||
        _toAddress == null) {
      throw Exception('Missing required parameters');
    }

    _setLoading(true);
    _error = null;

    try {
      final request = bridge_models.QuoteRequest(
        fromChain: _fromChain!,
        toChain: _toChain!,
        fromToken: _fromToken!,
        toToken: _toToken!,
        fromAmount: _fromAmount!,
        fromAddress: _fromAddress!,
        toAddress: _toAddress!,
      );

      final job = await _routeExecutor.executeRoute(_selectedRoute!, request);
      
      _currentJob = job;
      await loadJobHistory();

      _setLoading(false);
      notifyListeners();
      
      return job;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  /// Sign current step
  Future<void> signCurrentStep() async {
    if (_currentJob == null) {
      throw Exception('No active job');
    }

    _setLoading(true);
    _error = null;

    try {
      await _routeExecutor.signStep(
        _currentJob!.id,
        _currentJob!.currentStepIndex,
      );

      // Reload job
      _currentJob = await _jobStore.getJob(_currentJob!.id);
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  /// Load job history
  Future<void> loadJobHistory() async {
    try {
      _jobHistory = await _jobStore.getAllJobs();
      notifyListeners();
    } catch (e) {
      print('❌ Error loading job history: $e');
    }
  }

  /// Get supported tokens for a chain
  Future<List<bridge_models.Token>> getSupportedTokens(String chainId) async {
    try {
      return await _lifiClient.getSupportedTokens(chainId);
    } catch (e) {
      print('❌ Error getting supported tokens: $e');
      return [];
    }
  }

  /// Get Stellar public key
  /// Tries secure storage first, then falls back to Firestore
  Future<String?> getStellarPublicKey() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      // First try to get from secure storage (via StellarSigner)
      final publicKey = await _stellarSigner.getPublicKey(user.uid);
      if (publicKey != null && publicKey.isNotEmpty) {
        return publicKey;
      }
      
      // Fallback: try to get from Firestore (via StellarService)
      final fallbackKey = await _stellarService.getPublicKey();
      if (fallbackKey != null && fallbackKey.isNotEmpty) {
        return fallbackKey;
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting Stellar public key: $e');
      return null;
    }
  }

  /// Connect EVM wallet
  Future<String> connectEvmWallet() async {
    try {
      return await _evmSigner.connect();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Check if EVM wallet is connected
  bool get isEvmWalletConnected => _evmSigner.isConnected;

  /// Get EVM address
  String? get evmAddress => _evmSigner.currentAddress;

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _routeExecutor.dispose();
    super.dispose();
  }
}

