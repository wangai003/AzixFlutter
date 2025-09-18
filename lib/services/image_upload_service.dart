import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Comprehensive image upload service for Firebase Storage
class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();
  static const Uuid _uuid = Uuid();

  /// Upload multiple images with progress tracking
  static Future<List<String>> uploadMultipleImages({
    required List<Uint8List> imageBytes,
    required String category, // 'products', 'services', 'vendors', 'profiles'
    String? itemId,
    Function(int current, int total, double progress)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final List<String> downloadUrls = [];
    
    for (int i = 0; i < imageBytes.length; i++) {
      try {
        onProgress?.call(i, imageBytes.length, 0.0);
        
        final url = await _uploadSingleImage(
          imageBytes[i],
          category,
          itemId ?? _uuid.v4(),
          i,
          (progress) => onProgress?.call(i, imageBytes.length, progress),
        );
        
        downloadUrls.add(url);
        onProgress?.call(i + 1, imageBytes.length, 1.0);
      } catch (e) {
        // Continue with other images even if one fails
      }
    }
    
    return downloadUrls;
  }

  /// Upload single image
  static Future<String> uploadSingleImage(
    Uint8List imageBytes,
    String category,
    String itemId, {
    int index = 0,
    Function(double progress)? onProgress,
  }) async {
    return await _uploadSingleImage(imageBytes, category, itemId, index, onProgress);
  }

  /// Internal method for uploading single image
  static Future<String> _uploadSingleImage(
    Uint8List imageBytes,
    String category,
    String itemId,
    int index,
    Function(double progress)? onProgress,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Create unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${itemId}_${index}_$timestamp.jpg';
    
    // Create storage reference
    final storageRef = _storage.ref()
        .child('marketplace')
        .child(category)
        .child(user.uid)
        .child(filename);

    // Create upload task
    final uploadTask = storageRef.putData(
      imageBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': user.uid,
          'category': category,
          'itemId': itemId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    // Track upload progress
    uploadTask.snapshotEvents.listen((taskSnapshot) {
      final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
      onProgress?.call(progress);
    });

    // Wait for upload completion
    final snapshot = await uploadTask;
    
    // Get download URL
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Pick images from gallery with multiple selection
  static Future<List<Uint8List>> pickImagesFromGallery({
    int maxImages = 5,
    int maxSizeKB = 1024, // 1MB default
  }) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return [];

      // Limit number of images
      final limitedFiles = pickedFiles.take(maxImages).toList();
      
      final List<Uint8List> imageBytesList = [];
      
      for (final file in limitedFiles) {
        final bytes = await file.readAsBytes();
        
        // Check file size
        if (bytes.length > maxSizeKB * 1024) {
          throw Exception('Image too large. Maximum size: ${maxSizeKB}KB');
        }
        
        imageBytesList.add(bytes);
      }
      
      return imageBytesList;
    } catch (e) {
      throw Exception('Error picking images: $e');
    }
  }

  /// Pick single image from gallery
  static Future<Uint8List?> pickImageFromGallery({
    int maxSizeKB = 1024,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final bytes = await pickedFile.readAsBytes();
      
      // Check file size
      if (bytes.length > maxSizeKB * 1024) {
        throw Exception('Image too large. Maximum size: ${maxSizeKB}KB');
      }
      
      return bytes;
    } catch (e) {
      throw Exception('Error picking image: $e');
    }
  }

  /// Pick image from camera
  static Future<Uint8List?> takePhoto({
    int maxSizeKB = 1024,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final bytes = await pickedFile.readAsBytes();
      
      // Check file size
      if (bytes.length > maxSizeKB * 1024) {
        throw Exception('Image too large. Maximum size: ${maxSizeKB}KB');
      }
      
      return bytes;
    } catch (e) {
      throw Exception('Error taking photo: $e');
    }
  }

  /// Delete image from Firebase Storage
  static Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Don't throw error for delete failures
    }
  }

  /// Delete multiple images
  static Future<void> deleteImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImage(url);
    }
  }

  /// Get image metadata
  static Future<FullMetadata?> getImageMetadata(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      return await ref.getMetadata();
    } catch (e) {
      return null;
    }
  }

  /// Compress image bytes (basic compression)
  static Uint8List compressImage(Uint8List bytes, {int quality = 85}) {
    // For web, we'll use the browser's built-in compression
    // For mobile, you might want to use packages like image or flutter_image_compress
    return bytes; // Placeholder - implement actual compression if needed
  }

  /// Generate optimized image sizes
  static Future<Map<String, String>> uploadImageVariants({
    required Uint8List originalBytes,
    required String category,
    required String itemId,
    int index = 0,
    Function(double progress)? onProgress,
  }) async {
    final Map<String, String> variants = {};
    
    // Upload original
    final originalUrl = await _uploadSingleImage(
      originalBytes,
      '$category/original',
      itemId,
      index,
      (progress) => onProgress?.call(progress * 0.4),
    );
    variants['original'] = originalUrl;
    
    // For now, we'll just upload the original
    // In a full implementation, you'd create thumbnail and medium variants
    variants['thumbnail'] = originalUrl;
    variants['medium'] = originalUrl;
    
    onProgress?.call(1.0);
    return variants;
  }

  /// Validate image before upload
  static String? validateImage(Uint8List bytes, {
    int maxSizeKB = 1024,
    List<String> allowedTypes = const ['jpg', 'jpeg', 'png', 'webp'],
  }) {
    // Check file size
    if (bytes.length > maxSizeKB * 1024) {
      return 'Image too large. Maximum size: ${maxSizeKB}KB';
    }
    
    // Check minimum size
    if (bytes.length < 1024) {
      return 'Image too small. Minimum size: 1KB';
    }
    
    // Basic file type check (you might want to implement more sophisticated checks)
    // This is a basic implementation - for production, use proper image validation
    
    return null; // Valid
  }

  /// Get storage usage for user
  static Future<int> getUserStorageUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      // This is a placeholder - Firebase Storage doesn't directly provide usage info
      // You'd need to track this in Firestore or implement a Cloud Function
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Clean up old/unused images
  static Future<void> cleanupUnusedImages(String category, List<String> activeImageUrls) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final categoryRef = _storage.ref()
          .child('marketplace')
          .child(category)
          .child(user.uid);

      final listResult = await categoryRef.listAll();
      
      for (final item in listResult.items) {
        final downloadUrl = await item.getDownloadURL();
        
        if (!activeImageUrls.contains(downloadUrl)) {
          await item.delete();
        }
      }
    } catch (e) {
    }
  }
}

/// Image upload progress model
class ImageUploadProgress {
  final int currentIndex;
  final int totalImages;
  final double currentImageProgress;
  final String? currentImageName;
  final bool isComplete;

  ImageUploadProgress({
    required this.currentIndex,
    required this.totalImages,
    required this.currentImageProgress,
    this.currentImageName,
    this.isComplete = false,
  });

  double get overallProgress {
    if (totalImages == 0) return 0.0;
    return (currentIndex + currentImageProgress) / totalImages;
  }

  String get progressText {
    if (isComplete) return 'Upload complete';
    return 'Uploading ${currentIndex + 1} of $totalImages...';
  }
}

/// Upload result model
class ImageUploadResult {
  final List<String> successUrls;
  final List<String> failedImages;
  final Duration uploadDuration;

  ImageUploadResult({
    required this.successUrls,
    required this.failedImages,
    required this.uploadDuration,
  });

  bool get hasFailures => failedImages.isNotEmpty;
  bool get allSuccessful => failedImages.isEmpty && successUrls.isNotEmpty;
  int get totalUploaded => successUrls.length;
}
