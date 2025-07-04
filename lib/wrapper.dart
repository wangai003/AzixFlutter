import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/stellar_provider.dart';
import 'screens/main_navigation.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/modern_auth_screen.dart';
import 'utils/responsive_layout.dart';
import 'widgets/stellar_wallet_prompt.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({Key? key}) : super(key: key);

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  @override
  void initState() {
    super.initState();
    // Check for Stellar wallet after a short delay to allow the UI to build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStellarWallet();
    });
  }

  Future<void> _checkStellarWallet() async {
    // Skip wallet check on web platform
    if (kIsWeb) {
      return;
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    
    // Only check for wallet if user is authenticated
    if (authProvider.isAuthenticated) {
      final hasWallet = await stellarProvider.checkWalletStatus();
      
      // If user doesn't have a wallet, show the prompt
      if (!hasWallet && mounted) {
        // Show the wallet prompt dialog and await its result
        final result = await showDialog(
          context: context,
          barrierDismissible: false, // User must take an action
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SizedBox(
              width: ResponsiveLayout.getValueForScreenType<double>(
                context: context,
                mobile: MediaQuery.of(context).size.width * 0.85,
                tablet: 500,
                desktop: 600,
              ),
              child: const StellarWalletPrompt(),
            ),
          ),
        );
        // Optionally, handle result if needed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Return either MainNavigation or ModernAuthScreen based on authentication state
    if (authProvider.isAuthenticated) {
      return const MainNavigation();
    } else {
      return const ModernAuthScreen();
    }
  }
}