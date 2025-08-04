import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/vendor_onboarding_service.dart';
import '../../theme/app_theme.dart';
import 'dart:io';

class GoodsVendorOnboardingScreen extends StatefulWidget {
  const GoodsVendorOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<GoodsVendorOnboardingScreen> createState() => _GoodsVendorOnboardingScreenState();
}

class _GoodsVendorOnboardingScreenState extends State<GoodsVendorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _businessLicenseController = TextEditingController();
  final _shippingRegionsController = TextEditingController();
  final _contactInfoController = TextEditingController();
  bool _loading = false;

  File? _registrationDoc;
  File? _idDoc;
  File? _logoImage;
  String? _registrationDocUrl;
  String? _idDocUrl;
  String? _logoImageUrl;
  String? _selectedCategory;
  String? _selectedSubcategory;

  Future<void> _pickFile(Function(File) onPicked, {ImageSource? source, bool isImage = true}) async {
    final picker = ImagePicker();
    final picked = isImage
        ? await picker.pickImage(source: source ?? ImageSource.gallery, imageQuality: 85)
        : await picker.pickImage(source: source ?? ImageSource.gallery, imageQuality: 85); // For PDF, use file picker package
    if (picked != null) {
      onPicked(File(picked.path));
    }
  }

  Future<String> _uploadFile(File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child('vendor_docs/$path/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}');
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_registrationDoc == null || _idDoc == null || _logoImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload all required documents.')));
      return;
    }
    setState(() => _loading = true);
    // Upload files
    _registrationDocUrl = await _uploadFile(_registrationDoc!, 'registration');
    _idDocUrl = await _uploadFile(_idDoc!, 'id');
    _logoImageUrl = await _uploadFile(_logoImage!, 'logo');
    final success = await VendorOnboardingService.submitGoodsVendorApplication(
      businessName: _businessNameController.text.trim(),
      businessLicense: _businessLicenseController.text.trim(),
      productCategories: [_selectedCategory ?? '', _selectedSubcategory ?? ''],
      shippingRegions: _shippingRegionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      contactInfo: _contactInfoController.text.trim(),
      registrationDocUrl: _registrationDocUrl,
      idDocUrl: _idDocUrl,
      logoImageUrl: _logoImageUrl,
    );
    setState(() => _loading = false);
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission failed. Please try again.')));
      }
      return;
    }
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.white,
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.primaryGold, size: 32),
              const SizedBox(width: 8),
              const Text('Application Submitted'),
            ],
          ),
          content: const Text('Your goods vendor application has been submitted!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessLicenseController.dispose();
    _shippingRegionsController.dispose();
    _contactInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Import goodsCategories from marketplace_home_screen.dart or duplicate here for now
    final Map<String, List<String>> goodsCategories = {
      'Retail & Consumer Goods': [
        'Groceries', 'Clothing & Apparel', 'Electronics & Gadgets', 'Home Appliances', 'Beauty & Personal Care', 'Health & Wellness'
      ],
      'Agriculture': [
        'Fresh Produce', 'Livestock & Poultry', 'Farming Tools & Equipment', 'Fertilizers & Pesticides', 'Seeds & Nurseries'
      ],
      'Artisanal & Handicrafts': [
        'Jewelry', 'Textiles & Fashion', 'Pottery & Ceramics', 'Cultural Artifacts & Home Decor', 'Handmade Furniture'
      ],
      'Food & Beverage': [
        'Local Food Vendors', 'Bakeries & Confectionery', 'Beverage Suppliers', 'Packaged & Processed Foods', 'Organic & Specialty Foods'
      ],
      'Construction & Building Materials': [
        'Raw Materials', 'Structural Components', 'Finishing Materials', 'Construction Tools & Equipment'
      ],
      'Education & Learning': [
        'School Supplies', 'Libraries & Bookstores'
      ],
      'Automotive & Transportation': [
        'Vehicles & Motorcycles', 'Auto Parts & Accessories', 'Vehicle Rentals & Leasing'
      ],
      'Technology & Software': [
        'Computers & Accessories', 'Software & Digital Solutions'
      ],
      'Finance & Business Services': [
        'Banking & Financial Services'
      ],
      'Travel & Hospitality': [
        'Hotels & Accommodations'
      ],
    };
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Text('Goods Vendor Onboarding', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Text('Business Information', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: InputDecoration(labelText: 'Business Name'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessLicenseController,
                      decoration: InputDecoration(labelText: 'Business License'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Main Category'),
                      items: goodsCategories.keys.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val;
                          _selectedSubcategory = null;
                        });
                      },
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    // Subcategory Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedSubcategory,
                      decoration: const InputDecoration(labelText: 'Subcategory'),
                      items: _selectedCategory == null
                          ? []
                          : goodsCategories[_selectedCategory]!.map((sub) => DropdownMenuItem(value: sub, child: Text(sub))).toList(),
                      onChanged: (val) => setState(() => _selectedSubcategory = val),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _shippingRegionsController,
                      decoration: InputDecoration(labelText: 'Shipping Regions (comma separated)'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactInfoController,
                      decoration: InputDecoration(labelText: 'Contact Info'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    Text('Upload Documents', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildFilePicker('Business Registration Certificate', _registrationDoc, (file) => setState(() => _registrationDoc = file)),
                    const SizedBox(height: 12),
                    _buildFilePicker('National ID/Passport', _idDoc, (file) => setState(() => _idDoc = file)),
                    const SizedBox(height: 12),
                    _buildFilePicker('Business Logo', _logoImage, (file) => setState(() => _logoImage = file), isImage: true),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: AppTheme.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _submit,
                        child: const Text('Submit Application'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilePicker(String label, File? file, Function(File) onPicked, {bool isImage = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
              onPressed: () => _pickFile(onPicked, isImage: isImage),
            ),
            const SizedBox(width: 12),
            if (file != null)
              isImage
                  ? Image.file(file, width: 56, height: 56, fit: BoxFit.cover)
                  : const Icon(Icons.insert_drive_file, color: AppTheme.primaryGold, size: 32),
          ],
        ),
      ],
    );
  }
} 