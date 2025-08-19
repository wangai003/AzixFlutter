import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/image_upload_widget.dart';

import '../../theme/marketplace_theme.dart';
import '../../providers/auth_provider.dart' as local_auth;
import '../main_navigation.dart';

/// Complete vendor registration screen with instant approval
class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<VendorRegistrationScreen> createState() => _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _websiteController = TextEditingController();
  
  String _selectedBusinessType = 'Individual';
  List<String> _selectedCategories = [];
  List<String> _logoImages = [];
  List<String> _bannerImages = [];
  bool _isLoading = false;
  
  final List<String> _businessTypes = [
    'Individual',
    'Small Business',
    'Corporation',
    'Non-Profit',
  ];
  
  final List<String> _availableCategories = [
    'Electronics',
    'Fashion',
    'Food & Beverage',
    'Health & Beauty',
    'Home & Garden',
    'Sports & Outdoors',
    'Books & Media',
    'Automotive',
    'Services',
    'Digital Products',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: const Text(
          'Become a Vendor',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: MarketplaceTheme.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 32),
              _buildBusinessInfoSection(),
              const SizedBox(height: 24),
              _buildContactInfoSection(),
              const SizedBox(height: 24),
              _buildCategoriesSection(),
              const SizedBox(height: 24),
              _buildImagesSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MarketplaceTheme.primaryBlue, MarketplaceTheme.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🚀 Start Selling Today!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join thousands of vendors earning on our platform. Registration is instant - no approval needed!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildFeatureItem('✅ Instant Approval'),
              const SizedBox(width: 16),
              _buildFeatureItem('💰 Start Earning'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBusinessInfoSection() {
    return _buildSection(
      title: 'Business Information',
      children: [
        _buildTextField(
          controller: _businessNameController,
          label: 'Business Name',
          hint: 'Enter your business or store name',
          validator: (value) => value?.isEmpty ?? true ? 'Business name is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descriptionController,
          label: 'Business Description',
          hint: 'Describe what you sell and what makes you unique',
          maxLines: 3,
          validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Business Type',
          value: _selectedBusinessType,
          items: _businessTypes,
          onChanged: (value) => setState(() => _selectedBusinessType = value!),
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSection(
      title: 'Contact Information',
      children: [
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: '+1 (555) 123-4567',
          keyboardType: TextInputType.phone,
          validator: (value) => value?.isEmpty ?? true ? 'Phone number is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: 'Business Address',
          hint: 'Street address',
          validator: (value) => value?.isEmpty ?? true ? 'Address is required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _cityController,
                label: 'City',
                hint: 'City',
                validator: (value) => value?.isEmpty ?? true ? 'City is required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _stateController,
                label: 'State',
                hint: 'State',
                validator: (value) => value?.isEmpty ?? true ? 'State is required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _websiteController,
          label: 'Website (Optional)',
          hint: 'https://yourwebsite.com',
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    return _buildSection(
      title: 'Product Categories',
      subtitle: 'Select the categories you plan to sell in',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableCategories.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(category);
                  } else {
                    _selectedCategories.add(category);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? MarketplaceTheme.primaryBlue : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? MarketplaceTheme.primaryBlue : Colors.grey.shade400,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedCategories.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select at least one category',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildImagesSection() {
    return _buildSection(
      title: 'Branding Images',
      subtitle: 'Upload your logo and banner to make your store stand out',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Images
            Text(
              'Store Logo',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Square image (512x512) recommended',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            ImageUploadWidget(
              initialImages: _logoImages,
              onImagesChanged: (images) {
                setState(() {
                  _logoImages = images;
                });
              },
              maxImages: 1,
              category: 'vendor_logo',
              allowMultiple: false,
              helpText: 'Upload a square logo image for your store',
            ),
            
            const SizedBox(height: 24),
            
            // Banner Images
            Text(
              'Store Banner',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wide image (1200x400) recommended',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            ImageUploadWidget(
              initialImages: _bannerImages,
              onImagesChanged: (images) {
                setState(() {
                  _bannerImages = images;
                });
              },
              maxImages: 1,
              category: 'vendor_banner',
              allowMultiple: false,
              helpText: 'Upload a wide banner image for your store',
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: MarketplaceTheme.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Start Selling Now!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: MarketplaceTheme.primaryBlue),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: MarketplaceTheme.primaryBlue),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ],
    );
  }



  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategories.isEmpty) {
      _showErrorSnackBar('Please select at least one category');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('Please log in first');
        return;
      }

      // Create vendor profile
      final vendorData = {
        'userId': user.uid,
        'businessName': _businessNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'businessType': _selectedBusinessType,
        'contactInfo': {
          'phone': _phoneController.text.trim(),
          'email': user.email,
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'website': _websiteController.text.trim(),
        },
        'categories': _selectedCategories,
        'images': {
          'logo': _logoImages.isNotEmpty ? _logoImages.first : null,
          'banner': _bannerImages.isNotEmpty ? _bannerImages.first : null,
        },
        'status': 'active', // Instant approval
        'isVerified': false, // Can be verified later
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'analytics': {
          'totalSales': 0,
          'totalOrders': 0,
          'rating': 0.0,
          'reviewCount': 0,
        },
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('vendor_profiles')
          .doc(user.uid)
          .set(vendorData);

      // Update user role
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'role': 'vendor',
        'vendorProfile': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local auth provider
      final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
      await authProvider.refreshUserData();

      _showSuccessDialog();

    } catch (e) {
      _showErrorSnackBar('Registration failed: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Welcome to Our Marketplace!'),
        content: const Text(
          'Your vendor account has been created successfully! You can now start listing products and services.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainNavigation()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketplaceTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Selling'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}


