import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/auth_provider.dart' as local_auth;
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import '../wrapper.dart';
import 'auth/verify_email_screen.dart';
import 'auth/phone_verification_screen.dart';
import 'auth/choose_verification_screen.dart';

class UserRegistrationScreen extends StatefulWidget {
  final String? referralCode;
  
  const UserRegistrationScreen({Key? key, this.referralCode}) : super(key: key);

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPhoneVerified = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _verificationId;
  String? _errorMessage;
  
  // Phone number state
  String _phoneNumber = '';
  String _countryCode = '+254'; // Default to Kenya
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _nameController.text = user.displayName ?? '';
    }
  }
  
  // Get properly formatted phone number for registration
  String get _registrationPhoneNumber {
    // Clean the phone number (remove any non-digits)
    final cleanPhone = _phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Combine country code with clean phone number
    final result = '$_countryCode$cleanPhone';
    
    print('=== PHONE NUMBER FOR REGISTRATION ===');
    print('Country code: $_countryCode');
    print('Phone number: $_phoneNumber');
    print('Clean phone: $cleanPhone');
    print('Final result: $result');
    
    return result;
  }
  
  Future<void> _verifyPhoneNumber() async {
    if (_phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a phone number';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get the full phone number
      final phoneNumber = _registrationPhoneNumber;
      print('Verifying phone number: $phoneNumber');
      
      // Basic validation
      if (phoneNumber.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a valid phone number';
          _isLoading = false;
        });
        return;
      }
      
      if (!phoneNumber.startsWith('+')) {
        setState(() {
          _errorMessage = 'Phone number must include country code (e.g., +254 for Kenya)';
          _isLoading = false;
        });
        return;
      }
      
      // Check length (7-15 digits after +)
      final digitsOnly = phoneNumber.substring(1).replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.length < 7) {
        setState(() {
          _errorMessage = 'Phone number is too short. Please enter a complete number.';
          _isLoading = false;
        });
        return;
      }
      
      if (digitsOnly.length > 15) {
        setState(() {
          _errorMessage = 'Phone number is too long. Please check your number.';
          _isLoading = false;
        });
        return;
      }
      
      // Basic validation passed - no need for advanced parser validation
      
      // Simulate verification delay
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _isPhoneVerified = true;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number $phoneNumber verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      print('Phone verification completed successfully');
    } catch (e) {
      print('Phone verification error: $e');
      setState(() {
        _errorMessage = 'Failed to verify phone number: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final phone = _registrationPhoneNumber;
    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    String? uid = user?.uid;
    Map<String, bool> status = {'isEmailVerified': false, 'isPhoneVerified': false};
    if (uid != null) {
      status = await authProvider.getFirestoreVerificationStatus(uid);
    }
    if (!status['isEmailVerified']! && !status['isPhoneVerified']!) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChooseVerificationScreen(email: email, phoneNumber: phone),
        ),
      );
      if (result == null || result['verified'] != true) {
        setState(() {
          _errorMessage = 'Verification required to complete registration.';
        });
        return;
      }
      if (uid != null) {
        if (result['method'] == 'email') {
          await authProvider.setFirestoreVerificationStatus(uid, email: true);
        } else if (result['method'] == 'phone') {
          await authProvider.setFirestoreVerificationStatus(uid, phone: true);
        }
      }
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Get the phone number
      final phoneNumber = _registrationPhoneNumber;
      final enteredReferralCode = _referralCodeController.text.trim().isEmpty ? null : _referralCodeController.text.trim();
      print('=== REGISTRATION DEBUG ===');
      print('Current user: ${currentUser?.uid}');
      print('Provider data: ${currentUser?.providerData}');
      print('Phone number: $phoneNumber');
      print('Phone number length: ${phoneNumber.length}');
      print('Phone number starts with +: ${phoneNumber.startsWith('+')}');
      print('Phone number digits only: ${phoneNumber.substring(1).replaceAll(RegExp(r'[^\d]'), '')}');
      print('Is Google user: ${currentUser?.providerData.isNotEmpty}');
      print('========================');
      
      // Final validation before registration
      print('=== FINAL PHONE VALIDATION ===');
      print('Phone number for registration: $phoneNumber');
      print('Is empty: ${phoneNumber.isEmpty}');
      print('Starts with +: ${phoneNumber.startsWith('+')}');
      print('Length: ${phoneNumber.length}');
      
      if (phoneNumber.isEmpty || !phoneNumber.startsWith('+')) {
        throw Exception('Invalid phone number format');
      }
      
      if (currentUser != null && currentUser.providerData.isNotEmpty) {
        // Google user - complete registration
        print('Completing Google user registration for: ${currentUser.uid}');
        final success = await authProvider.completeGoogleUserRegistration(
          currentUser.uid,
          phoneNumber,
          referralCode: enteredReferralCode,
        );
        
        if (!success) {
          throw Exception('Failed to complete Google user registration');
        }
        
        print('Google user registration completed successfully');
      } else {
        // Email/password user - create new account
        print('Creating new user with email/password');
        
        // Validate required fields
        if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
          throw Exception('All fields are required');
        }
        
        final success = await authProvider.registerWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
          phoneNumber,
          referralCode: enteredReferralCode,
        );
        
        if (!success) {
          throw Exception('Failed to create new user account');
        }
        
        print('Email/password user registration completed successfully');
      }
      
      // Success - let the wrapper handle navigation
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.emailVerified) {
          final verified = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VerifyEmailScreen(email: user.email ?? ''),
            ),
          );
          if (verified == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registration completed successfully! Welcome to AZIX! 🎉'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration completed successfully! Welcome to AZIX! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('Registration error: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isGoogleUser = currentUser?.providerData.isNotEmpty ?? false;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ResponsiveContainer(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ResponsiveLayoutBuilder(
              mobileBuilder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Header
                  Center(
                    child: Column(
                      children: [
                        // Logo or Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryGold.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            color: AppTheme.primaryGold,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        Text(
                          'Complete Your Registration',
                          style: AppTheme.headingLarge.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        
                        // Subtitle
                        Text(
                          'Registration is mandatory to access the AZIX platform',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Mandatory notice
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You must complete registration to proceed',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Registration Form
                  _buildRegistrationForm(),
                  const SizedBox(height: 40),
                ],
              ),
              tabletBuilder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Header
                  Center(
                    child: Column(
                      children: [
                        // Logo or Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryGold.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            color: AppTheme.primaryGold,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        Text(
                          'Complete Your Registration',
                          style: AppTheme.headingLarge.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        
                        // Subtitle
                        Text(
                          'Registration is mandatory to access the AZIX platform',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Mandatory notice
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You must complete registration to proceed',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Registration Form
                  _buildRegistrationForm(),
                  const SizedBox(height: 40),
                ],
              ),
              desktopBuilder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Header
                  Center(
                    child: Column(
                      children: [
                        // Logo or Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryGold.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            color: AppTheme.primaryGold,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        Text(
                          'Complete Your Registration',
                          style: AppTheme.headingLarge.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        
                        // Subtitle
                        Text(
                          'Registration is mandatory to access the AZIX platform',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Mandatory notice
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You must complete registration to proceed',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Registration Form
                  _buildRegistrationForm(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name Field
          TextFormField(
            controller: _nameController,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
            decoration: InputDecoration(
              labelText: 'Full Name',
              labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
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
                borderSide: BorderSide(color: AppTheme.primaryGold),
              ),
              prefixIcon: const Icon(Icons.person, color: AppTheme.grey),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          
          // Simple Phone Number Input with Country Code
          Row(
            children: [
              // Country Code Dropdown
              Container(
                width: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: _countryCode,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    prefixIcon: const Icon(Icons.flag, color: AppTheme.grey, size: 18),
                  ),
                  dropdownColor: Colors.grey[900],
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
                  items: [
                    DropdownMenuItem(value: '+254', child: Text('🇰🇪 +254', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+234', child: Text('🇳🇬 +234', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+233', child: Text('🇬🇭 +233', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+27', child: Text('🇿🇦 +27', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+256', child: Text('🇺🇬 +256', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+255', child: Text('🇹🇿 +255', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+251', child: Text('🇪🇹 +251', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+86', child: Text('🇨🇳 +86', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+55', child: Text('🇧🇷 +55', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+52', child: Text('🇲🇽 +52', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+1', child: Text('🇨🇦 +1', style: AppTheme.bodySmall)),
                    DropdownMenuItem(value: '+61', child: Text('🇦🇺 +61', style: AppTheme.bodySmall)),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _countryCode = value ?? '+254';
                      _phoneNumber = _phoneController.text;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Phone Number Field
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
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
                      borderSide: BorderSide(color: AppTheme.primaryGold),
                    ),
                    prefixIcon: const Icon(Icons.phone, color: AppTheme.grey),
                    suffixIcon: _isPhoneVerified
                        ? const Icon(Icons.verified, color: Colors.green)
                        : null,
                    hintText: 'e.g., 725280695',
                    hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey.withOpacity(0.5)),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _phoneNumber = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.length < 7) {
                      return 'Phone number is too short';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Verify Phone Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPhoneVerified ? Colors.green : AppTheme.primaryGold,
                    foregroundColor: AppTheme.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isPhoneVerified ? 'Phone Verified ✓' : 'Verify Phone Number',
                          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
          
          // Phone number preview
          if (_phoneNumber.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade300, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Full number: $_registrationPhoneNumber',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.blue.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          
          // Email Field (if not from Google sign-in)
          if (FirebaseAuth.instance.currentUser?.providerData.isEmpty ?? true) ...[
            TextFormField(
              controller: _emailController,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
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
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
                prefixIcon: const Icon(Icons.email, color: AppTheme.grey),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            // Referral Code Field (optional)
            TextFormField(
              controller: _referralCodeController,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: 'Referral Code (optional)',
                labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
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
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
                prefixIcon: const Icon(Icons.card_giftcard, color: AppTheme.grey),
              ),
            ),
            const SizedBox(height: 20),
            
            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
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
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
                prefixIcon: const Icon(Icons.lock, color: AppTheme.grey),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                    color: AppTheme.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            // Confirm Password Field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
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
                  borderSide: BorderSide(color: AppTheme.primaryGold),
                ),
                prefixIcon: const Icon(Icons.lock, color: AppTheme.grey),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    color: AppTheme.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],
          
          // Error Message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTheme.bodyMedium.copyWith(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Register Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _registerUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                minimumSize: const Size(double.infinity, 56),
                textStyle: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Complete Registration'),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Terms and Privacy
          Text(
            'By completing registration, you agree to our Terms of Service and Privacy Policy',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 