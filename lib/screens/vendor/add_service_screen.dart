import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';
import '../../models/service.dart';
import '../../utils/marketplace_categories.dart';

/// Complete add/edit service screen 
class AddServiceScreen extends StatefulWidget {
  final Service? service;
  final String? serviceId;
  
  const AddServiceScreen({
    Key? key,
    this.service,
    this.serviceId,
  }) : super(key: key);

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = 'Freelance & Digital Services';
  List<ServicePackage> _packages = [];
  bool _isLoading = false;
  
  final List<String> _categories = MarketplaceCategories.getServiceCategories();

  @override
  void initState() {
    super.initState();
    if (widget.service != null) {
      _populateFields();
    } else {
      _addPackage(); // Start with one package
    }
  }

  void _populateFields() {
    final service = widget.service!;
    _titleController.text = service.title;
    _descriptionController.text = service.description;
    _selectedCategory = service.category;
    _packages = List.from(service.packages);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;
    
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Service' : 'Add Service'),
        backgroundColor: MarketplaceTheme.white,
        foregroundColor: MarketplaceTheme.gray900,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 16),
              _buildPackagesSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(isEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Service Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Service Title',
              hintText: 'Enter a clear service title',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Title is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Describe your service in detail',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedCategory = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              const Text(
                'Service Packages',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _addPackage,
                icon: Icon(Icons.add, color: MarketplaceTheme.primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._packages.asMap().entries.map((entry) {
            final index = entry.key;
            final package = entry.value;
            return _buildPackageCard(package, index);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPackageCard(ServicePackage package, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MarketplaceTheme.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MarketplaceTheme.gray200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Package ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_packages.length > 1)
                IconButton(
                  onPressed: () => _removePackage(index),
                  icon: Icon(Icons.delete, color: MarketplaceTheme.error),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: package.name,
            decoration: const InputDecoration(
              labelText: 'Package Name',
              hintText: 'e.g., Basic, Standard, Premium',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => package.name = value,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: package.description,
            decoration: const InputDecoration(
              labelText: 'Package Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (value) => package.description = value,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: package.price.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Price (₳)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => package.price = double.tryParse(value) ?? 0.0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: package.deliveryTime.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Delivery (days)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => package.deliveryTime = int.tryParse(value) ?? 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitService,
        style: ElevatedButton.styleFrom(
          backgroundColor: MarketplaceTheme.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                isEditing ? 'Update Service' : 'Add Service',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  void _addPackage() {
    setState(() {
      _packages.add(ServicePackage(
        name: '',
        description: '',
        price: 0.0,
        deliveryTime: 1,
      ));
    });
  }

  void _removePackage(int index) {
    setState(() {
      _packages.removeAt(index);
    });
  }

  Future<void> _submitService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one package')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final isEditing = widget.service != null;

      final serviceData = {
        'vendorId': user.uid,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'packages': _packages.map((p) => {
          'name': p.name,
          'description': p.description,
          'price': p.price,
          'deliveryTime': p.deliveryTime,
        }).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'images': [], // TODO: Add image upload
      };

      if (!isEditing) {
        serviceData['createdAt'] = FieldValue.serverTimestamp();
        serviceData['status'] = 'active';
        serviceData['viewCount'] = 0;
        serviceData['favoriteCount'] = 0;
      }

      if (isEditing) {
        await FirebaseFirestore.instance
            .collection('services')
            .doc(widget.serviceId!)
            .update(serviceData);
      } else {
        await FirebaseFirestore.instance
            .collection('services')
            .add(serviceData);
      }

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing 
                ? 'Service updated successfully!' 
                : 'Service added successfully!',
          ),
          backgroundColor: MarketplaceTheme.success,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving service: ${e.toString()}'),
          backgroundColor: MarketplaceTheme.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
