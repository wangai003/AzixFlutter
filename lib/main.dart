import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/stellar_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/security_provider.dart';
import 'theme/app_theme.dart';
import 'utils/responsive_layout.dart';
import 'wrapper.dart';
import 'screens/all_transactions_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler for Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    // Optionally, send to a logging service
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stack) {
    // Print and optionally log the error
    print('Failed to initialize Firebase: $e');
    print(stack);
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, StellarProvider>(
          create: (_) => StellarProvider(),
          update: (_, auth, previousStellarProvider) {
            // If auth state changes, we want to refresh the Stellar provider
            if (auth.isAuthenticated && previousStellarProvider != null) {
              previousStellarProvider.checkWalletStatus();
            }
            return previousStellarProvider ?? StellarProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AZIX',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const Wrapper(),
            builder: (context, child) {
              // Apply a responsive layout wrapper to the entire app
              return MediaQuery(
                // Ensure text scaling doesn't break layouts
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
                ),
                child: child!,
              );
            },
            routes: {
              '/all-transactions': (context) => const AllTransactionsScreen(),
            },
          );
        },
      ),
    );
  }
}
