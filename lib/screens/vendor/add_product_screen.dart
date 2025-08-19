import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/marketplace_theme.dart';
import '../../models/product.dart';
import '../../widgets/image_upload_widget.dart';
import '../../utils/marketplace_categories.dart';

/// Complete add/edit product screen with full functionality
class AddProductScreen extends StatefulWidget {
  final Product? product;
  final String? productId;
  
  const AddProductScreen({
    Key? key,
    this.product,
    this.productId,
  }) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _inventoryController = TextEditingController();
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();
  final _dimensionsController = TextEditingController();
  
  String _selectedCategory = 'Retail & Consumer Goods';
  String _selectedCondition = 'New';
  List<String> _productImages = [];
  bool _isLoading = false;
  bool _isDigital = false;
  bool _freeShipping = false;
  
  final List<String> _categories = MarketplaceCategories.getGoodsCategories();
  
  final List<String> _conditions = [
    'New',
    'Like New',
    'Good',
    'Fair',
    'Used',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final product = widget.product!;
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = product.price.toString();
    _inventoryController.text = product.inventory.toString();
    _skuController.text = product.sku ?? '';
    _selectedCategory = product.category;
    _productImages = List.from(product.images);
    
    // Additional fields if they exist in metadata
    final metadata = product.metadata;
    _selectedCondition = metadata['condition'] ?? 'New';
    _isDigital = metadata['isDigital'] ?? false;
    _freeShipping = metadata['freeShipping'] ?? false;
    _weightController.text = metadata['weight']?.toString() ?? '';
    _dimensionsController.text = metadata['dimensions'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _inventoryController.dispose();
    _skuController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    
    return Scaffold(
      backgroundColor: MarketplaceTheme.gray50,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        backgroundColor: MarketplaceTheme.white,
        foregroundColor: MarketplaceTheme.gray900,
        elevation: 1,
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _deleteProduct,
              icon: const Icon(Icons.delete, color: MarketplaceTheme.error),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 16),
              _buildPricingSection(),
              const SizedBox(height: 16),
              _buildInventorySection(),
              const SizedBox(height: 16),
              _buildImagesSection(),
              const SizedBox(height: 16),
              _buildShippingSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(isEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection(
      title: 'Basic Information',
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'Product Name',
          hint: 'Enter a clear, descriptive name',
          validator: (value) => value?.isEmpty ?? true ? 'Product name is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descriptionController,
          label: 'Description',
          hint: 'Describe your product in detail',
          maxLines: 4,
          validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Category',
                value: _selectedCategory,
                items: _categories,
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown(
                label: 'Condition',
                value: _selectedCondition,
                items: _conditions,
                onChanged: (value) => setState(() => _selectedCondition = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _skuController,
          label: 'SKU (Optional)',
          hint: 'Product identifier',
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          title: 'Digital Product',
          subtitle: 'No physical shipping required',
          value: _isDigital,
          onChanged: (value) => setState(() => _isDigital = value),
        ),
      ],
    );
  }

  Widget _buildPricingSection() {
    return _buildSection(
      title: 'Pricing',
      children: [
        _buildTextField(
          controller: _priceController,
          label: 'Price (₳)',
          hint: '0.00',
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Price is required';
            if (double.tryParse(value!) == null) return 'Enter a valid price';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInventorySection() {
    return _buildSection(
      title: 'Inventory',
      children: [
        _buildTextField(
          controller: _inventoryController,
          label: 'Stock Quantity',
          hint: '0',
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Stock quantity is required';
            if (int.tryParse(value!) == null) return 'Enter a valid quantity';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildImagesSection() {
    return ImageUploadWidget(
      initialImages: _productImages,
      onImagesChanged: (images) {
        setState(() {
          _productImages = images;
        });
      },
      category: 'products',
      itemId: widget.productId,
      maxImages: 5,
      helpText: 'Upload high-quality images. First image will be the main product image.',
    );
  }

  // Old image upload methods removed - now using ImageUploadWidget

  Widget _buildShippingSection() {
    return _buildSection(
      title: 'Shipping & Dimensions',
      children: [
        _buildSwitchTile(
          title: 'Free Shipping',
          subtitle: 'Offer free shipping to customers',
          value: _freeShipping,
          onChanged: (value) => setState(() => _freeShipping = value),
        ),
        if (!_isDigital) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  hint: '0.0',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _dimensionsController,
                  label: 'Dimensions',
                  hint: 'L x W x H (cm)',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitProduct,
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
            : Text(
                isEditing ? 'Update Product' : 'Add Product',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: MarketplaceTheme.gray500,
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
            fontWeight: FontWeight.w500,
            fontSize: 14,
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: MarketplaceTheme.gray300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: MarketplaceTheme.gray300),
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
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: MarketplaceTheme.gray300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: MarketplaceTheme.gray300),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: MarketplaceTheme.primaryBlue,
      contentPadding: EdgeInsets.zero,
    );
  }

  // Image upload is now handled by ImageUploadWidget

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_productImages.isEmpty) {
      _showErrorSnackBar('Please add at least one product image');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final isEditing = widget.product != null;
      
      // Use the images from ImageUploadWidget
      List<String> imageUrls = List.from(_productImages);

      // Create product data
      final productData = {
        'vendorId': user.uid,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'inventory': int.parse(_inventoryController.text),
        'category': _selectedCategory,
        'images': imageUrls,
        'sku': _skuController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'condition': _selectedCondition,
          'isDigital': _isDigital,
          'freeShipping': _freeShipping,
          'weight': _weightController.text.isNotEmpty 
              ? double.tryParse(_weightController.text) 
              : null,
          'dimensions': _dimensionsController.text.trim(),
        },
      };

      if (!isEditing) {
        productData['createdAt'] = FieldValue.serverTimestamp();
        productData['status'] = 'active';
        productData['viewCount'] = 0;
        productData['favoriteCount'] = 0;
      }

      // Save to Firestore
      if (isEditing) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId!)
            .update(productData);
      } else {
        await FirebaseFirestore.instance
            .collection('products')
            .add(productData);
      }

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing 
                ? 'Product updated successfully!' 
                : 'Product added successfully!',
          ),
          backgroundColor: MarketplaceTheme.success,
        ),
      );

    } catch (e) {
      _showErrorSnackBar('Error saving product: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: MarketplaceTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId!)
            .delete();
        
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully!'),
            backgroundColor: MarketplaceTheme.success,
          ),
        );
      } catch (e) {
        _showErrorSnackBar('Error deleting product: ${e.toString()}');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MarketplaceTheme.error,
      ),
    );
  }
}
