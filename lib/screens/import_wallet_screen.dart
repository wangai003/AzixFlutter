import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/stellar_provider.dart';
import 'wallet_screen.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({Key? key}) : super(key: key);

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final TextEditingController _secretKeyController = TextEditingController();
  bool _isImporting = false;
  bool _success = false;
  String? _error;

  Future<void> _importWallet() async {
    setState(() {
      _isImporting = true;
      _error = null;
    });
    final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
    final result = await stellarProvider.recoverWalletWithSecretKey(_secretKeyController.text.trim());
    setState(() {
      _isImporting = false;
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
        title: const Text('Import Wallet'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/login_animation.json', height: 160),
              const SizedBox(height: 32),
              Text('Import Your Wallet', style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGold)),
              const SizedBox(height: 16),
              Text('Paste your secret key or upload a backup file.', style: AppTheme.bodyLarge.copyWith(color: AppTheme.white)),
              const SizedBox(height: 32),
              TextField(
                controller: _secretKeyController,
                decoration: InputDecoration(
                  hintText: 'Enter secret key',
                  filled: true,
                  fillColor: AppTheme.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.white.withOpacity(0.5)),
                ),
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: AppTheme.bodyMedium.copyWith(color: Colors.red)),
                ),
              ElevatedButton(
                onPressed: _isImporting ? null : _importWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: AppTheme.headingMedium,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isImporting
                    ? const CircularProgressIndicator(color: AppTheme.black)
                    : const Text('Import Wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 