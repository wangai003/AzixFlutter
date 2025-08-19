import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../theme/marketplace_theme.dart';
import '../services/image_upload_service.dart';
import '../utils/responsive_layout.dart';

/// Reusable image upload widget with drag & drop support
class ImageUploadWidget extends StatefulWidget {
  final List<String> initialImages;
  final Function(List<String>) onImagesChanged;
  final int maxImages;
  final String category;
  final String? itemId;
  final bool allowMultiple;
  final String? helpText;
  
  const ImageUploadWidget({
    Key? key,
    this.initialImages = const [],
    required this.onImagesChanged,
    this.maxImages = 5,
    required this.category,
    this.itemId,
    this.allowMultiple = true,
    this.helpText,
  }) : super(key: key);

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  List<String> _images = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  final TextEditingController _urlController = TextEditingController();
  bool _showUrlInput = false;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MarketplaceTheme.gray300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library, color: MarketplaceTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Images',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_images.length}/${widget.maxImages}',
                style: TextStyle(
                  color: MarketplaceTheme.gray600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          if (widget.helpText != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.helpText!,
              style: TextStyle(
                color: MarketplaceTheme.gray600,
                fontSize: 12,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Upload Progress
          if (_isUploading) ...[
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: MarketplaceTheme.gray200,
              valueColor: AlwaysStoppedAnimation<Color>(MarketplaceTheme.primaryBlue),
            ),
            const SizedBox(height: 8),
            Text(
              _uploadStatus,
              style: TextStyle(
                color: MarketplaceTheme.gray600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Image Grid
          _buildImageGrid(),
          
          const SizedBox(height: 16),
          
          // Upload Options
          if (_images.length < widget.maxImages && !_isUploading) ...[
            _buildUploadMethods(),
            if (_showUrlInput) ...[
              const SizedBox(height: 12),
              _buildUrlInput(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_images.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _images.length + (_images.length < widget.maxImages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _images.length) {
          return _buildAddImageTile();
        }
        return _buildImageTile(_images[index], index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: MarketplaceTheme.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: MarketplaceTheme.gray300,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 32,
              color: MarketplaceTheme.gray400,
            ),
            const SizedBox(height: 8),
            Text(
              'Add product images',
              style: TextStyle(
                color: MarketplaceTheme.gray600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile(String imageUrl, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MarketplaceTheme.gray300),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: MarketplaceTheme.gray200,
                  child: const Icon(Icons.error),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: MarketplaceTheme.gray200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
          
          // Primary badge
          if (index == 0)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: MarketplaceTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'PRIMARY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          // Delete button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: MarketplaceTheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageTile() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        decoration: BoxDecoration(
          color: MarketplaceTheme.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: MarketplaceTheme.gray300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: MarketplaceTheme.primaryBlue,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                color: MarketplaceTheme.primaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadMethods() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _showUrlInput = !_showUrlInput),
            icon: const Icon(Icons.link, size: 18),
            label: Text(
              _showUrlInput ? 'Hide URL Input' : 'Add Image URL',
              style: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showUrlInput 
                  ? MarketplaceTheme.primaryBlue
                  : MarketplaceTheme.primaryBlue.withOpacity(0.1),
              foregroundColor: _showUrlInput 
                  ? Colors.white
                  : MarketplaceTheme.primaryBlue,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveLayout.isMobile(context) ? 8 : 12,
              ),
            ),
          ),
        ),
        
        SizedBox(width: ResponsiveLayout.getResponsiveSpacing(context, 12)),
        
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(
              'Upload File',
              style: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: MarketplaceTheme.primaryGreen,
              side: BorderSide(color: MarketplaceTheme.primaryGreen),
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveLayout.isMobile(context) ? 8 : 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrlInput() {
    return Container(
      padding: EdgeInsets.all(ResponsiveLayout.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Image URL',
            style: MarketplaceTheme.titleLarge.copyWith(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
            ),
          ),
          
          SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 8)),
          
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'https://example.com/image.jpg',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
              ),
              prefixIcon: const Icon(Icons.link, color: MarketplaceTheme.primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: MarketplaceTheme.primaryBlue),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.getResponsivePadding(context),
                vertical: 12,
              ),
            ),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            ),
            onSubmitted: (_) => _addImageFromUrl(),
          ),
          
          SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 12)),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _urlController.text.trim().isNotEmpty ? _addImageFromUrl : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    'Add Image',
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MarketplaceTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveLayout.isMobile(context) ? 8 : 12,
                    ),
                  ),
                ),
              ),
              
              SizedBox(width: ResponsiveLayout.getResponsiveSpacing(context, 8)),
              
              OutlinedButton.icon(
                onPressed: () {
                  _urlController.clear();
                  setState(() => _showUrlInput = false);
                },
                icon: const Icon(Icons.close, size: 18),
                label: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveLayout.isMobile(context) ? 8 : 12,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 8)),
          
          Text(
            'Tip: Use high-quality images with URLs ending in .jpg, .png, or .webp',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 11),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      setState(() => _isUploading = true);
      
      List<Uint8List> imageBytes;
      if (widget.allowMultiple) {
        final remainingSlots = widget.maxImages - _images.length;
        imageBytes = await ImageUploadService.pickImagesFromGallery(
          maxImages: remainingSlots,
        );
      } else {
        final singleImage = await ImageUploadService.pickImageFromGallery();
        imageBytes = singleImage != null ? [singleImage] : [];
      }
      
      if (imageBytes.isNotEmpty) {
        await _uploadImages(imageBytes);
      }
    } catch (e) {
      _showErrorSnackBar('Error picking images: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      setState(() => _isUploading = true);
      
      final imageBytes = await ImageUploadService.takePhoto();
      if (imageBytes != null) {
        await _uploadImages([imageBytes]);
      }
    } catch (e) {
      _showErrorSnackBar('Error taking photo: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadImages(List<Uint8List> imageBytes) async {
    try {
      final uploadedUrls = await ImageUploadService.uploadMultipleImages(
        imageBytes: imageBytes,
        category: widget.category,
        itemId: widget.itemId,
        onProgress: (current, total, progress) {
          setState(() {
            _uploadProgress = (current + progress) / total;
            _uploadStatus = 'Uploading ${current + 1} of $total...';
          });
        },
      );

      setState(() {
        _images.addAll(uploadedUrls);
        _uploadProgress = 1.0;
        _uploadStatus = 'Upload complete';
      });

      widget.onImagesChanged(_images);
      
      // Clear progress after a delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _uploadProgress = 0.0;
            _uploadStatus = '';
          });
        }
      });
    } catch (e) {
      _showErrorSnackBar('Upload failed: $e');
    }
  }

  void _removeImage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Image'),
        content: const Text('Are you sure you want to remove this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                final removedImage = _images.removeAt(index);
                // Optionally delete from Firebase Storage
                ImageUploadService.deleteImage(removedImage);
              });
              widget.onImagesChanged(_images);
            },
            style: ElevatedButton.styleFrom(backgroundColor: MarketplaceTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _addImageFromUrl() {
    final url = _urlController.text.trim();
    
    if (url.isEmpty) {
      _showErrorSnackBar('Please enter a valid image URL');
      return;
    }
    
    if (!_isValidImageUrl(url)) {
      _showErrorSnackBar('Please enter a valid image URL (must end with .jpg, .jpeg, .png, .gif, or .webp)');
      return;
    }
    
    if (_images.contains(url)) {
      _showErrorSnackBar('This image URL has already been added');
      return;
    }
    
    if (_images.length >= widget.maxImages) {
      _showErrorSnackBar('Maximum number of images reached');
      return;
    }
    
    setState(() {
      _images.add(url);
      _urlController.clear();
      _showUrlInput = false;
    });
    
    widget.onImagesChanged(_images);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image URL added successfully'),
        backgroundColor: MarketplaceTheme.primaryGreen,
      ),
    );
  }
  
  bool _isValidImageUrl(String url) {
    // Basic URL validation
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
      return false;
    }
    
    // Check for common image extensions
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.endsWith('.jpg') ||
           lowercaseUrl.endsWith('.jpeg') ||
           lowercaseUrl.endsWith('.png') ||
           lowercaseUrl.endsWith('.gif') ||
           lowercaseUrl.endsWith('.webp') ||
           lowercaseUrl.contains('image') ||
           lowercaseUrl.contains('img') ||
           lowercaseUrl.contains('photo');
  }
  
  bool get _canAddMoreImages => _images.length < widget.maxImages && !_isUploading;

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MarketplaceTheme.error,
      ),
    );
  }
}
