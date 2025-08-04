import 'package:flutter/material.dart';
import '../../services/vendor_onboarding_service.dart';
import '../../models/vendor_application.dart';
import '../../theme/app_theme.dart';

class VendorOnboardingStatusScreen extends StatefulWidget {
  const VendorOnboardingStatusScreen({Key? key}) : super(key: key);

  @override
  State<VendorOnboardingStatusScreen> createState() => _VendorOnboardingStatusScreenState();
}

class _VendorOnboardingStatusScreenState extends State<VendorOnboardingStatusScreen> {
  VendorApplication? _application;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final app = await VendorOnboardingService.fetchLatestVendorApplication();
    setState(() {
      _application = app;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.black,
          title: Text('Vendor Application Status', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_application == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.black,
          title: Text('Vendor Application Status', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No vendor application found.',
                  style: TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.black,
                  ),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    String message;
    Color statusColor = AppTheme.primaryGold;
    IconData statusIcon = Icons.hourglass_top;
    switch (_application!.status) {
      case 'approved':
        message = 'Congratulations! Your vendor application has been approved.';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        message = 'Sorry, your vendor application was rejected.';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        if (_application!.rejectionReason != null && _application!.rejectionReason!.isNotEmpty) {
          message += '\nReason: ${_application!.rejectionReason}';
        }
        break;
      default:
        message = 'Your vendor application is under review.';
        statusColor = AppTheme.primaryGold;
        statusIcon = Icons.hourglass_top;
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Text('Vendor Application Status', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 64),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                ),
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 