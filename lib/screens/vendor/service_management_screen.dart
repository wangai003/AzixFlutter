import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../vendor/vendor_dashboard_screen.dart';

class ServiceManagementScreen extends StatefulWidget {
  const ServiceManagementScreen({Key? key}) : super(key: key);

  @override
  State<ServiceManagementScreen> createState() => _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen> {
  late Stream<List<Service>> _servicesStream;
  String? _selectedCategory;
  String? _selectedSubcategory;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _servicesStream = FirebaseFirestore.instance
        .collection('services')
        .where('vendorId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Service.fromJson(doc.data(), doc.id))
            .toList());
  }

  void _showAddEditDialog({Service? service}) {
    final titleController = TextEditingController(text: service?.title ?? '');
    final descController = TextEditingController(text: service?.description ?? '');
    final requirementsController = TextEditingController(text: service?.requirements.join(', ') ?? '');
    final deliveryTimeController = TextEditingController(text: service?.deliveryTime.toString() ?? '');
    List<String> imageUrls = List<String>.from(service?.images ?? []);
    String? mainImageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
    List<String> otherImageUrls = imageUrls.length > 1 ? imageUrls.sublist(1) : [];
    final mainImageLinkController = TextEditingController();
    final otherImageLinkController = TextEditingController();
    bool uploading = false;
    // Multiple packages
    List<ServicePackage> packages = List<ServicePackage>.from(service?.packages ?? []);
    // Validation state
    String? errorText;
    // Structured categories
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
    _selectedCategory = service?.category;
    _selectedSubcategory = service?.subcategory;

    final mainImageFocusNode = FocusNode();
    final otherImageFocusNode = FocusNode();

    Future<void> pickAndUploadMainImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      uploading = true;
      setState(() {});
      final ref = FirebaseStorage.instance.ref().child('service_images/${DateTime.now().millisecondsSinceEpoch}_${picked.name}');
      final uploadTask = await ref.putData(await picked.readAsBytes());
      final url = await uploadTask.ref.getDownloadURL();
      mainImageUrl = url;
      uploading = false;
      setState(() {});
    }
    Future<void> pickAndUploadOtherImages() async {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage();
      if (picked == null || picked.isEmpty) return;
      uploading = true;
      setState(() {});
      for (final file in picked) {
        final ref = FirebaseStorage.instance.ref().child('service_images/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
        final uploadTask = await ref.putData(await file.readAsBytes());
        final url = await uploadTask.ref.getDownloadURL();
        otherImageUrls.add(url);
      }
      uploading = false;
      setState(() {});
    }

    void addOrEditPackage({ServicePackage? pkg, int? index}) {
      final nameController = TextEditingController(text: pkg?.name ?? '');
      final priceController = TextEditingController(text: pkg?.price.toString() ?? '');
      final descController = TextEditingController(text: pkg?.description ?? '');
      final deliveryController = TextEditingController(text: pkg?.deliveryTime.toString() ?? '');
      String? pkgError;
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setPkgState) => AlertDialog(
            title: Text(pkg == null ? 'Add Package' : 'Edit Package'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Package Name')),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Package Price'), keyboardType: TextInputType.number),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Package Description')),
                TextField(controller: deliveryController, decoration: const InputDecoration(labelText: 'Delivery Time (days)'), keyboardType: TextInputType.number),
                if (pkgError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(pkgError ?? '', style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final price = double.tryParse(priceController.text) ?? -1;
                  final desc = descController.text.trim();
                  final delivery = int.tryParse(deliveryController.text) ?? -1;
                  if (name.isEmpty || price < 0 || desc.isEmpty || delivery <= 0) {
                    setPkgState(() => pkgError = 'All fields required. Price and delivery must be positive.');
                    return;
                  }
                  final newPkg = ServicePackage(
                    name: name,
                    price: price,
                    description: desc,
                    deliveryTime: delivery,
                  );
                  if (index != null) {
                    packages[index] = newPkg;
                  } else {
                    packages.add(newPkg);
                  }
                  Navigator.pop(context);
                  setState(() {});
                },
                child: Text(pkg == null ? 'Add' : 'Save'),
              ),
            ],
          ),
        ),
      );
    }

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
          return AlertDialog(
            title: Text(service == null ? 'Add Service' : 'Edit Service'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 5,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                  ),
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
                  TextField(controller: requirementsController, decoration: const InputDecoration(labelText: 'Requirements (comma separated)')),
                  TextField(controller: deliveryTimeController, decoration: const InputDecoration(labelText: 'Delivery Time (days)'), keyboardType: TextInputType.number),
                  const Divider(),
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
                      child: Image.network(
                        mainImageUrl!, 
                        height: 120, 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
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
                              child: Image.network(
                                otherImageUrls[idx], 
                                width: 70, 
                                height: 70, 
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.error, color: Colors.red, size: 20),
                                ),
                              ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Service Packages', style: TextStyle(fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: () => addOrEditPackage(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  if (packages.isEmpty)
                    const Text('Add at least one package.', style: TextStyle(color: Colors.red)),
                  if (packages.isNotEmpty)
                    Column(
                      children: packages.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final pkg = entry.value;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(pkg.name),
                            subtitle: Text('Price: ${pkg.price} | Delivery: ${pkg.deliveryTime} days'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => addOrEditPackage(pkg: pkg, index: idx),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    packages.removeAt(idx);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                            subtitleTextStyle: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: uploading ? null : () async {
                          await pickAndUploadMainImage();
                          setState(() {});
                        },
                        icon: const Icon(Icons.upload),
                        label: const Text('Upload Main Image'),
                      ),
                      if (uploading) ...[
                        const SizedBox(width: 12),
                        const CircularProgressIndicator(),
                      ]
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (mainImageUrl != null && mainImageUrl!.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 1,
                        itemBuilder: (context, idx) => Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Image.network(
                                mainImageUrl!, 
                                width: 70, 
                                height: 70, 
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.error, color: Colors.red, size: 20),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red, size: 18),
                              onPressed: () {
                                mainImageUrl = null;
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
                        // Validation
                        if (titleController.text.trim().isEmpty ||
                            descController.text.trim().isEmpty ||
                            _selectedCategory == null ||
                            _selectedSubcategory == null ||
                            (int.tryParse(deliveryTimeController.text) ?? 0) <= 0 ||
                            packages.isEmpty) {
                          setState(() => errorText = 'Please fill all required fields and add at least one valid package.');
                          return;
                        }
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;
                        // Compose images: main first, then others
                        final List<String> allImages = [];
                        if (mainImageUrl != null && mainImageUrl!.isNotEmpty) allImages.add(mainImageUrl!);
                        allImages.addAll(otherImageUrls);
                        final data = Service(
                          id: service?.id ?? '',
                          vendorId: uid,
                          title: titleController.text.trim(),
                          description: descController.text.trim(),
                          images: allImages,
                          packages: packages,
                          deliveryTime: int.tryParse(deliveryTimeController.text) ?? 0,
                          category: _selectedCategory!,
                          subcategory: _selectedSubcategory!,
                          requirements: requirementsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                          createdAt: service?.createdAt ?? DateTime.now(),
                        );
                        final ref = FirebaseFirestore.instance.collection('services');
                        if (service == null) {
                          await ref.add(data.toJson());
                        } else {
                          await ref.doc(service.id).update(data.toJson());
                        }
                        if (mounted) Navigator.pop(context);
                      },
                child: Text(service == null ? 'Add' : 'Save'),
              ),
            ],
          ); // End AlertDialog
        }, // End StatefulBuilder builder
      ), // End StatefulBuilder
    ); // End showDialog
  }

  void _deleteService(Service service) async {
    await FirebaseFirestore.instance.collection('services').doc(service.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Management')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Service>>(
              stream: _servicesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final services = snapshot.data!;
                if (services.isEmpty) {
                  return const Center(child: Text('No services found.'));
                }
                return ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return ListTile(
                      title: Text(service.title),
                      subtitle: Text('Category: ${service.category} | Subcategory: ${service.subcategory} | Delivery: ${service.deliveryTime} days'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showAddEditDialog(service: service),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteService(service),
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