import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import 'main_navigation.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Complete user registration with phone and referral
      final success = await authProvider.completeGoogleUserRegistration(
        _phoneController.text.trim(),
        referralCode: _referralController.text.trim().isEmpty ? null : _referralController.text.trim(),
      );

      if (success) {
        // Mark profile as complete
        await authProvider.markProfileComplete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile completed successfully! Welcome to AZIX!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to main app (PI mining screen)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MainNavigation(),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = authProvider.error ?? 'Failed to complete registration';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to complete registration: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: ResponsiveLayout.isDesktop(context)
            ? _buildDesktopLayout()
            : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: _buildForm(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: _buildForm(),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Column(
          children: [
            Icon(
              Icons.person_add,
              size: 64,
              color: AppTheme.primaryGold,
            ),
            const SizedBox(height: 24),
            Text(
              'Complete Your Profile',
              style: AppTheme.headingLarge.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please provide your phone number to complete your registration',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),

        const SizedBox(height: 48),

        // Form
        Form(
          key: _formKey,
          child: Column(
            children: [
              // Phone Number Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  hintText: '+1234567890',
                  hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                  filled: true,
                  fillColor: AppTheme.darkGrey.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  if (value.trim().length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Referral Code Field (Optional)
              TextFormField(
                controller: _referralController,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                decoration: InputDecoration(
                  labelText: 'Referral Code (Optional)',
                  labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  hintText: 'Enter referral code if you have one',
                  hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.share, color: AppTheme.primaryGold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                  filled: true,
                  fillColor: AppTheme.darkGrey.withOpacity(0.3),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                          ),
                        )
                      : Text(
                          'Complete Registration',
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),

              // Info Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryGold,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your phone number will be used for account verification and security purposes.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryGold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 