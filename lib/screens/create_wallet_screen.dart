import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/stellar_provider.dart';
import 'wallet_screen.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({Key? key}) : super(key: key);

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  bool _isCreating = false;
  bool _success = false;
  String? _error;

  Future<void> _createWallet() async {
    setState(() {
      _isCreating = true;
      _error = null;
    });
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    final result = await stellarProvider.createWallet(context);
    setState(() {
      _isCreating = false;
      _success = result;
      _error = stellarProvider.error;
    });
    if (result) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WalletScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0,
        title: const Text('Create Wallet'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/login_animation.json', height: 160),
              const SizedBox(height: 32),
              Text('Create Your Wallet', style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGold)),
              const SizedBox(height: 16),
              Text('Secure your wallet with a password or biometrics.', style: AppTheme.bodyLarge.copyWith(color: AppTheme.white)),
              const SizedBox(height: 32),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: AppTheme.bodyMedium.copyWith(color: Colors.red)),
                ),
              ElevatedButton(
                onPressed: _isCreating ? null : _createWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: AppTheme.headingMedium,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: AppTheme.black)
                    : const Text('Create Wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 