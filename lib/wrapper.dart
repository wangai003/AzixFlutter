import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart' as local_auth;
import 'screens/landing_screen.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({Key? key}) : super(key: key);

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  @override
  void initState() {
    super.initState();
    
    // Handle redirect results for web users
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
        authProvider.handleRedirectResult();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show landing page first - users can navigate to app from there
    return const LandingScreen();
  }
}