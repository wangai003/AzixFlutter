import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../vendor/vendor_dashboard_screen.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  late Stream<List<Product>> _productsStream;
  String? _selectedCategory;
  String? _selectedSubcategory;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _productsStream = FirebaseFirestore.instance
        .collection('products')
        .where('vendorId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromJson(doc.data(), doc.id))
            .toList());
  }

  void _showAddEditDialog({Product? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final descController = TextEditingController(text: product?.description ?? '');
    final priceController = TextEditingController(text: product?.price.toString() ?? '');
    final inventoryController = TextEditingController(text: product?.inventory.toString() ?? '');
    final shippingController = TextEditingController(text: product?.shippingOptions.join(', ') ?? '');
    List<String> imageUrls = List<String>.from(product?.images ?? []);
    String? mainImageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
    List<String> otherImageUrls = imageUrls.length > 1 ? imageUrls.sublist(1) : [];
    final mainImageLinkController = TextEditingController();
    final otherImageLinkController = TextEditingController();
    bool uploading = false;
    String? errorText;
    // Structured categories
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
    _selectedCategory = product?.category;
    _selectedSubcategory = product?.subcategory;

    final mainImageFocusNode = FocusNode();
    final otherImageFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void addMainImageLink() {
            final val = mainImageLinkController.text.trim();
            if (val.isNotEmpty) {
              setState(() {
                mainImageUrl = val;
                mainImageLinkController.clear();
              });
            }
          }
          void addOtherImageLinks() {
            final val = otherImageLinkController.text.trim();
            if (val.isNotEmpty) {
              setState(() {
                final links = val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                otherImageUrls.addAll(links);
                otherImageLinkController.clear();
              });
            }
          }

          Future<void> pickAndUploadMainImage() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(source: ImageSource.gallery);
            if (picked == null) return;
            uploading = true;
            setState(() {});
            final ref = FirebaseStorage.instance.ref().child('product_images/${DateTime.now().millisecondsSinceEpoch}_${picked.name}');
            final uploadTask = await ref.putData(await picked.readAsBytes());
            final url = await uploadTask.ref.getDownloadURL();
            mainImageUrl = url;
            uploading = false;
            setState(() {});
          }
          Future<void> pickAndUploadOtherImages() async {
            final picker = ImagePicker();
            final picked = await picker.pickMultiImage();
            if (picked.isEmpty) return;
            uploading = true;
            setState(() {});
            for (final file in picked) {
              final ref = FirebaseStorage.instance.ref().child('product_images/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
              final uploadTask = await ref.putData(await file.readAsBytes());
              final url = await uploadTask.ref.getDownloadURL();
              otherImageUrls.add(url);
            }
            uploading = false;
            setState(() {});
          }

          return AlertDialog(
            title: Text(product == null ? 'Add Product' : 'Edit Product'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                  // Large product description field
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 5,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                  ),
                  TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
                  TextField(controller: inventoryController, decoration: const InputDecoration(labelText: 'Inventory'), keyboardType: TextInputType.number),
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
                  TextField(controller: shippingController, decoration: const InputDecoration(labelText: 'Shipping Options (comma separated)')),
                  const SizedBox(height: 12),
                  // Main image section
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Main Image:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: uploading ? null : () async {
                          await pickAndUploadMainImage();
                          setState(() {});
                        },
                        icon: const Icon(Icons.upload),
                        label: const Text('Upload'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: mainImageLinkController,
                          focusNode: mainImageFocusNode,
                          decoration: const InputDecoration(hintText: 'Paste image link'),
                          onSubmitted: (_) => addMainImageLink(),
                          onEditingComplete: addMainImageLink,
                          onChanged: (_) {},
                          onTapOutside: (_) => addMainImageLink(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_link),
                        tooltip: 'Add Link',
                        onPressed: addMainImageLink,
                      ),
                    ],
                  ),
                  if (mainImageUrl != null && mainImageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Image.network(mainImageUrl!, height: 120, fit: BoxFit.cover),
                    ),
                  // Other images section
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Other Images:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: uploading ? null : () async {
                          await pickAndUploadOtherImages();
                          setState(() {});
                        },
                        icon: const Icon(Icons.upload),
                        label: const Text('Upload'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: otherImageLinkController,
                          focusNode: otherImageFocusNode,
                          decoration: const InputDecoration(hintText: 'Paste image link(s), comma separated'),
                          onSubmitted: (_) => addOtherImageLinks(),
                          onEditingComplete: addOtherImageLinks,
                          onChanged: (_) {},
                          onTapOutside: (_) => addOtherImageLinks(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_link),
                        tooltip: 'Add Link(s)',
                        onPressed: addOtherImageLinks,
                      ),
                    ],
                  ),
                  if (otherImageUrls.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: otherImageUrls.length,
                        itemBuilder: (context, idx) => Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Image.network(otherImageUrls[idx], width: 70, height: 70, fit: BoxFit.cover),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red, size: 18),
                              onPressed: () {
                                otherImageUrls.removeAt(idx);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: uploading || (mainImageUrl == null && otherImageUrls.isEmpty)
                    ? null
                    : () async {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;
                        if (_selectedCategory == null || _selectedSubcategory == null) {
                          setState(() => errorText = 'Please select category and subcategory.');
                          return;
                        }
                        // Compose images: main first, then others
                        final List<String> allImages = [];
                        if (mainImageUrl != null && mainImageUrl!.isNotEmpty) allImages.add(mainImageUrl!);
                        allImages.addAll(otherImageUrls);
                        final data = Product(
                          id: product?.id ?? '',
                          vendorId: uid,
                          name: nameController.text.trim(),
                          description: descController.text.trim(),
                          images: allImages,
                          price: double.tryParse(priceController.text) ?? 0,
                          inventory: int.tryParse(inventoryController.text) ?? 0,
                          category: _selectedCategory!,
                          subcategory: _selectedSubcategory!,
                          shippingOptions: shippingController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                          createdAt: product?.createdAt ?? DateTime.now(),
                        );
                        final ref = FirebaseFirestore.instance.collection('products');
                        if (product == null) {
                          await ref.add(data.toJson());
                        } else {
                          await ref.doc(product.id).update(data.toJson());
                        }
                        if (mounted) Navigator.pop(context);
                      },
                child: Text(product == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteProduct(Product product) async {
    await FirebaseFirestore.instance.collection('products').doc(product.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Management')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _productsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snapshot.data!;
                if (products.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }
                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text('Category: ${product.category} | Subcategory: ${product.subcategory} | Price: ${product.price} | Inventory: ${product.inventory}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showAddEditDialog(product: product),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteProduct(product),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
} 