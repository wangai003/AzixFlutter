import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'providers/auth_provider.dart' as local_auth;
import 'providers/stellar_provider.dart';
import 'providers/secure_stellar_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/security_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/unified_cart_provider.dart';
import 'providers/search_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/marketplace/marketplace_provider.dart';
import 'providers/enhanced_wallet_provider.dart';
import 'providers/wallet_session_provider.dart';
import 'wallet/providers/wallet_provider.dart';
import 'wallet/providers/wallet_auth_provider.dart';
import 'bridge/providers/bridge_provider.dart';
import 'services/app_initialization_service.dart';
import 'services/stellar_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

// Import models to avoid conflicts
import 'models/asset_config.dart';
import 'models/order.dart';
import 'models/search_filter.dart';
import 'models/marketplace/listing.dart';
import 'models/marketplace/messaging.dart';

import 'wrapper.dart';
import 'screens/all_transactions_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/vendor/product_management_screen.dart';
import 'screens/vendor/service_management_screen.dart';
import 'screens/marketplace/functional_responsive_marketplace.dart';
import 'screens/onboarding/goods_vendor_onboarding_screen.dart';
import 'screens/onboarding/service_vendor_onboarding_screen.dart';
import 'screens/user_registration_screen.dart';
import 'screens/enhanced_wallet_screen.dart';

// Debug configuration - set to false to completely disable debug filtering
// When disabled, all debug messages including DebugService errors will show in console
const bool ENABLE_DEBUG_FILTERING = true;

// Override the global print function with our custom logger
void print(Object? object) {
  customPrint(object);
}

// Custom logger that filters out noisy debug messages
void customPrint(Object? object) {
  final message = object.toString();

  // Filter out various noisy debug messages that clutter the console
  final filteredMessages = [
    'DebugService: Error serving requests',
    'Cannot send Null',
    'DEBUG: Firebase initialized successfully',
    'DEBUG: Notification service initialized successfully',
    '🔄 StellarProvider: checkWalletStatus() called',
    '🔄 StellarProvider: Checking if wallet exists...',
    '🔄 StellarProvider: _hasWallet =',
    '✅ StellarProvider: Wallet found',
    '❌ StellarProvider: No wallet found',
    '🔄 StellarProvider: Calling _stellarService.getTransactionHistory()',
    '🔍 StellarProvider: loadTransactionsFromBlockchain() called',
    '🔍 Loading transactions from blockchain...',
    '📡 Calling Stellar SDK operations.forAccount...',
    '✅ StellarProvider: Loaded',
    'transactions from blockchain',
  ];

  bool shouldFilter = false;
  if (ENABLE_DEBUG_FILTERING && kDebugMode) {
    for (final filter in filteredMessages) {
      if (message.contains(filter)) {
        shouldFilter = true;
        break;
      }
    }
  }

  if (!shouldFilter) {
    // Use debugPrint instead of print to avoid the DebugService errors
    debugPrint(message);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler for Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // Only dump errors in debug mode to reduce console noise
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
    // Optionally, send to a logging service
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    customPrint('DEBUG: Firebase initialized successfully');

    // Initialize notification service
    await NotificationService.initialize();
    customPrint('DEBUG: Notification service initialized successfully');

    // Initialize the complete app system
    await AppInitializationService.initializeApp();
  } catch (e, stack) {
    // Print and optionally log the error
    customPrint('Failed to initialize Firebase: $e');
    customPrint(stack);
    // Optionally, show a fallback UI or error page
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => local_auth.AuthProvider()),
        ChangeNotifierProxyProvider<local_auth.AuthProvider, StellarProvider>(
          create: (_) => StellarProvider(),
          update: (_, auth, previousStellarProvider) {
            // If auth state changes, we want to refresh the Stellar provider
            if (auth.isAuthenticated && previousStellarProvider != null) {
              previousStellarProvider.checkWalletStatus();
            }
            return previousStellarProvider ?? StellarProvider();
          },
        ),
        // Enhanced secure mining provider
        ChangeNotifierProxyProvider<
          local_auth.AuthProvider,
          SecureStellarProvider
        >(
          create: (_) => SecureStellarProvider(),
          update: (_, auth, previousProvider) {
            if (auth.isAuthenticated && previousProvider != null) {
              // Auto-initialize when authenticated
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Provider will auto-initialize
              });
            }
            return previousProvider ?? SecureStellarProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => UnifiedCartProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        // New wallet system providers
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => WalletAuthProvider()),
        // Enhanced wallet provider with real-time monitoring
        ChangeNotifierProvider(create: (_) => EnhancedWalletProvider()),
        // Wallet session management provider
        ChangeNotifierProvider(create: (_) => WalletSessionProvider()),
        ChangeNotifierProvider(create: (_) => BridgeProvider()),
        // Enhanced marketplace provider with Stellar integration
        ChangeNotifierProxyProvider<
          StellarProvider,
          EnhancedMarketplaceProvider
        >(
          create: (_) =>
              EnhancedMarketplaceProvider(stellarService: StellarService()),
          update: (_, stellarProvider, previousMarketplaceProvider) {
            return previousMarketplaceProvider ??
                EnhancedMarketplaceProvider(stellarService: StellarService());
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AZIX',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const Wrapper(),
            builder: (context, child) {
              // Apply a responsive layout wrapper to the entire app
              final currentScale = MediaQuery.of(context).textScaleFactor;
              final clampedScale = currentScale.clamp(0.8, 1.2);
              return MediaQuery(
                // Ensure text scaling doesn't break layouts
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(clampedScale)),
                child: child!,
              );
            },
            routes: {
              '/all-transactions': (context) => const AllTransactionsScreen(),
              '/admin/dashboard': (context) => const AdminDashboardScreen(),
              '/marketplace': (context) =>
                  const FunctionalResponsiveMarketplace(),
              '/vendor/products': (context) => const ProductManagementScreen(),
              '/vendor/services': (context) => const ServiceManagementScreen(),
              '/onboarding/goods': (context) =>
                  const GoodsVendorOnboardingScreen(),
              '/onboarding/service': (context) =>
                  const ServiceVendorOnboardingScreen(),
              '/user-registration': (context) => const UserRegistrationScreen(),
              '/enhanced-wallet': (context) => const EnhancedWalletScreen(),
            },
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<String?> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('USER')
        .doc(user.uid)
        .get();
    return doc.data()?['role'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: FutureBuilder<String?>(
          future: _getUserRole(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            final role = snapshot.data;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/marketplace');
                  },
                  child: const Text('Browse Marketplace'),
                ),
                const SizedBox(height: 24),
                if (role == 'goods_vendor' || role == 'service_vendor') ...[
                  if (role == 'goods_vendor')
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/vendor/products');
                      },
                      child: const Text('Manage Products'),
                    ),
                  if (role == 'service_vendor')
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/vendor/services');
                      },
                      child: const Text('Manage Services'),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
