import 'package:flutter/material.dart';
import '../../services/vendor_onboarding_service.dart';
import '../../theme/app_theme.dart';
class ServiceVendorOnboardingScreen extends StatefulWidget {
  const ServiceVendorOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<ServiceVendorOnboardingScreen> createState() => _ServiceVendorOnboardingScreenState();
}

class _ServiceVendorOnboardingScreenState extends State<ServiceVendorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skillsController = TextEditingController();
  final _portfolioLinksController = TextEditingController();
  final _pricingModelController = TextEditingController();
  final _bioController = TextEditingController();
  bool _loading = false;
  String? _selectedCategory;
  String? _selectedSubcategory;

  @override
  void dispose() {
    _skillsController.dispose();
    _portfolioLinksController.dispose();
    _pricingModelController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final success = await VendorOnboardingService.submitServiceVendorApplication(
      skills: _skillsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      portfolioLinks: _portfolioLinksController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      serviceCategories: ['${_selectedCategory ?? ''}: ${_selectedSubcategory ?? ''}'],
      pricingModel: _pricingModelController.text.trim(),
      bio: _bioController.text.trim(),
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
          content: const Text('Your service vendor application has been submitted!'),
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
  Widget build(BuildContext context) {
    // Import serviceCategories from marketplace_home_screen.dart or duplicate here for now
    final Map<String, List<String>> serviceCategories = {
      'Services': [
        'Home Services', 'Transportation & Logistics', 'Freelance & Digital Services', 'Event Services', 'Health & Wellness Services'
      ],
      'Agriculture': [
        'Farming Tools & Equipment', 'Fertilizers & Pesticides', 'Seeds & Nurseries'
      ],
      'Artisanal & Handicrafts': [
        'Jewelry', 'Textiles & Fashion', 'Pottery & Ceramics', 'Cultural Artifacts & Home Decor', 'Handmade Furniture'
      ],
      'Food & Beverage': [
        'Catering Services', 'Event Services'
      ],
      'Construction & Building Materials': [
        'Professional Services'
      ],
      'Education & Learning': [
        'Tutoring & Private Lessons', 'Vocational & Skill Training', 'Online & E-Learning Platforms'
      ],
      'Automotive & Transportation': [
        'Repair & Maintenance Services'
      ],
      'Technology & Software': [
        'Tech Services & Repairs'
      ],
      'Finance & Business Services': [
        'Business Consulting & Legal Services'
      ],
      'Travel & Hospitality': [
        'Travel Agencies & Tour Operators', 'Transportation Services'
      ],
    };
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Text('Service Vendor Onboarding', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryGold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Text('Service Information', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _skillsController,
                      decoration: InputDecoration(labelText: 'Skills (comma separated)'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _portfolioLinksController,
                      decoration: InputDecoration(labelText: 'Portfolio Links (comma separated)'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Main Category'),
                      items: serviceCategories.keys.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
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
                          : serviceCategories[_selectedCategory]!.map((sub) => DropdownMenuItem(value: sub, child: Text(sub))).toList(),
                      onChanged: (val) => setState(() => _selectedSubcategory = val),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pricingModelController,
                      decoration: InputDecoration(labelText: 'Pricing Model'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(labelText: 'Bio'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      maxLines: 3,
                    ),
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
} 