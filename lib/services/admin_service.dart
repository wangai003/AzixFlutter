import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification.dart';
import '../models/announcement.dart';
import '../models/explore_content.dart';
import '../models/user_model.dart';
import '../models/vendor_application.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Notifications
  Future<String> createNotification(NotificationModel notification) async {
    try {
      final docRef = await _firestore.collection('notifications').add(notification.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  Future<List<NotificationModel>> getNotifications({String? userId}) async {
    try {
      Query query = _firestore.collection('notifications');
      
      if (userId != null) {
        query = query.where('userId', whereIn: [userId, null]); // Get user-specific and broadcast notifications
      } else {
        query = query.where('userId', isNull: true); // Only broadcast notifications
      }
      
      query = query.orderBy('createdAt', descending: true);
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return NotificationModel.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  Future<void> markNotificationAsRead(String notificationId, String userId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .collection('readBy')
          .doc(userId)
          .set({'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  // Announcements
  Future<String> createAnnouncement(AnnouncementModel announcement) async {
    try {
      final docRef = await _firestore.collection('announcements').add(announcement.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create announcement: $e');
    }
  }

  Future<List<AnnouncementModel>> getAnnouncements({bool activeOnly = true}) async {
    try {
      Query query = _firestore.collection('announcements');
      
      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }
      
      query = query.orderBy('priority', descending: true)
                  .orderBy('createdAt', descending: true);
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AnnouncementModel.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      throw Exception('Failed to get announcements: $e');
    }
  }

  Future<void> updateAnnouncement(String announcementId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('announcements').doc(announcementId).update(updates);
    } catch (e) {
      throw Exception('Failed to update announcement: $e');
    }
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      await _firestore.collection('announcements').doc(announcementId).delete();
    } catch (e) {
      throw Exception('Failed to delete announcement: $e');
    }
  }

  // Explore Content
  Future<String> createExploreContent(ExploreContentModel content) async {
    try {
      final docRef = await _firestore.collection('explore_content').add(content.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create explore content: $e');
    }
  }

  Future<List<ExploreContentModel>> getExploreContent({
    String? category,
    bool publishedOnly = true,
    bool featuredOnly = false,
  }) async {
    try {
      Query query = _firestore.collection('explore_content');
      
      if (publishedOnly) {
        query = query.where('isPublished', isEqualTo: true);
      }
      
      if (featuredOnly) {
        query = query.where('isFeatured', isEqualTo: true);
      }
      
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }
      
      query = query.orderBy('priority', descending: true)
                  .orderBy('createdAt', descending: true);
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ExploreContentModel.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      throw Exception('Failed to get explore content: $e');
    }
  }

  Future<void> updateExploreContent(String contentId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('explore_content').doc(contentId).update(updates);
    } catch (e) {
      throw Exception('Failed to update explore content: $e');
    }
  }

  Future<void> deleteExploreContent(String contentId) async {
    try {
      await _firestore.collection('explore_content').doc(contentId).delete();
    } catch (e) {
      throw Exception('Failed to delete explore content: $e');
    }
  }

  // User Management
  Future<List<UserModel>> getUsers({int limit = 50}) async {
    try {
              final snapshot = await _firestore
            .collection('USER')
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserModel.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('USER').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return UserModel.fromMap({...data, 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _firestore.collection('USER').doc(userId).update({'role': newRole});
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  Future<void> deactivateUser(String userId) async {
    try {
      await _firestore.collection('USER').doc(userId).update({'isActive': false});
    } catch (e) {
      throw Exception('Failed to deactivate user: $e');
    }
  }

  Future<void> activateUser(String userId) async {
    try {
      await _firestore.collection('USER').doc(userId).update({'isActive': true});
    } catch (e) {
      throw Exception('Failed to activate user: $e');
    }
  }

  // Analytics
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
              final usersSnapshot = await _firestore.collection('USER').get();
      final notificationsSnapshot = await _firestore.collection('notifications').get();
      final announcementsSnapshot = await _firestore.collection('announcements').get();
      final contentSnapshot = await _firestore.collection('explore_content').get();

      final totalUsers = usersSnapshot.docs.length;
      final activeUsers = usersSnapshot.docs.where((doc) => doc.data()['isActive'] == true).length;
      final usersWithWallets = usersSnapshot.docs.where((doc) => doc.data()['hasWallet'] == true).length;
      final adminUsers = usersSnapshot.docs.where((doc) => doc.data()['role'] == 'admin' || doc.data()['role'] == 'super_admin').length;

      return {
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'usersWithWallets': usersWithWallets,
        'adminUsers': adminUsers,
        'totalNotifications': notificationsSnapshot.docs.length,
        'totalAnnouncements': announcementsSnapshot.docs.length,
        'totalContent': contentSnapshot.docs.length,
        'publishedContent': contentSnapshot.docs.where((doc) => doc.data()['isPublished'] == true).length,
      };
    } catch (e) {
      throw Exception('Failed to get analytics: $e');
    }
  }

  // Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    try {
      final doc = await _firestore.collection('USER').doc(user.uid).get();
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>?;
        final role = userData?['role'] as String?;
        
        // Check if user has admin privileges
        return role == 'admin' || role == 'super_admin' || role == 'vendor';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get current user role
  Future<String> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'user';
    
    try {
      final doc = await _firestore.collection('USER').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['role'] ?? 'user';
      }
      return 'user';
    } catch (e) {
      return 'user';
    }
  }

  Future<void> likeArticle(String articleId, String userId) async {
    await _firestore.collection('explore_content').doc(articleId).update({
      'likes': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> unlikeArticle(String articleId, String userId) async {
    await _firestore.collection('explore_content').doc(articleId).update({
      'likes': FieldValue.arrayRemove([userId])
    });
  }

  Future<void> bookmarkArticle(String articleId, String userId) async {
    await _firestore.collection('explore_content').doc(articleId).update({
      'bookmarks': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> unbookmarkArticle(String articleId, String userId) async {
    await _firestore.collection('explore_content').doc(articleId).update({
      'bookmarks': FieldValue.arrayRemove([userId])
    });
  }

  /// Fetch vendor applications with optional filters.
  /// [status]: 'pending', 'approved', 'rejected', or null for all
  /// [type]: 'goods', 'service', or null for all
  /// [searchQuery]: userId or businessName (partial match, case-insensitive)
  static Future<List<VendorApplication>> fetchVendorApplications({String? status, String? type, String? searchQuery}) async {
    Query query = FirebaseFirestore.instance.collection('vendor_applications');
    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    if (type != null && type != 'all') {
      query = query.where('type', isEqualTo: type);
    }
    final snapshot = await query.orderBy('submittedAt', descending: true).get();
    var apps = snapshot.docs.map((doc) => VendorApplication.fromJson(doc.data() as Map<String, dynamic>, doc.id)).toList();
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      apps = apps.where((app) {
        final userMatch = app.uid.toLowerCase().contains(q);
        final businessMatch = app.goodsVendorData?.businessName.toLowerCase().contains(q) ?? false;
        return userMatch || businessMatch;
      }).toList();
    }
    return apps;
  }

  static Future<bool> approveVendorApplication(String applicationId) async {
    try {
      await FirebaseFirestore.instance.collection('vendor_applications').doc(applicationId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectionReason': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> rejectVendorApplication(String applicationId, String rejectionReason) async {
    try {
      await FirebaseFirestore.instance.collection('vendor_applications').doc(applicationId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'approvedAt': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }
} 