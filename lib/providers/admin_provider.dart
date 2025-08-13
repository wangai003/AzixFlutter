import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../models/notification.dart';
import '../models/announcement.dart';
import '../models/explore_content.dart';
import '../models/user_model.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();
  
  // State variables
  bool _isLoading = false;
  String? _error;
  bool _isAdmin = false;
  String _userRole = 'user';
  
  // Data lists
  List<NotificationModel> _notifications = [];
  List<AnnouncementModel> _announcements = [];
  List<ExploreContentModel> _exploreContent = [];
  List<UserModel> _users = [];
  Map<String, dynamic> _analytics = {};
  
  // Constructor - automatically initialize admin status
  AdminProvider() {
    // Initialize admin status when provider is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeAdminStatus();
    });
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _isAdmin;
  String get userRole => _userRole;
  List<NotificationModel> get notifications => _notifications;
  List<AnnouncementModel> get announcements => _announcements;
  List<ExploreContentModel> get exploreContent => _exploreContent;
  List<UserModel> get users => _users;
  Map<String, dynamic> get analytics => _analytics;
  int get unreadNotificationCount => _notifications.where((n) => !n.isRead).length;

  // Initialize admin status
  Future<void> initializeAdminStatus() async {
    _setLoading(true);
    try {
      _isAdmin = await _adminService.isCurrentUserAdmin();
      _userRole = await _adminService.getCurrentUserRole();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to initialize admin status: $e');
      _setLoading(false);
    }
  }

  // Force refresh admin status (useful for testing role changes)
  Future<void> refreshAdminStatus() async {
    await initializeAdminStatus();
  }

  // Notifications
  Future<void> createNotification(NotificationModel notification) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _adminService.createNotification(notification);
      await loadNotifications();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to create notification: $e');
      _setLoading(false);
    }
  }

  Future<void> loadNotifications({String? userId}) async {
    _setLoading(true);
    try {
      _notifications = await _adminService.getNotifications(userId: userId);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load notifications: $e');
      _setLoading(false);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    _setLoading(true);
    try {
      await _adminService.deleteNotification(notificationId);
      await loadNotifications();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to delete notification: $e');
      _setLoading(false);
    }
  }

  // Announcements
  Future<void> createAnnouncement(AnnouncementModel announcement) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _adminService.createAnnouncement(announcement);
      await loadAnnouncements();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to create announcement: $e');
      _setLoading(false);
    }
  }

  Future<void> loadAnnouncements({bool activeOnly = true}) async {
    _setLoading(true);
    try {
      _announcements = await _adminService.getAnnouncements(activeOnly: activeOnly);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load announcements: $e');
      _setLoading(false);
    }
  }

  Future<void> updateAnnouncement(String announcementId, Map<String, dynamic> updates) async {
    _setLoading(true);
    try {
      await _adminService.updateAnnouncement(announcementId, updates);
      await loadAnnouncements();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to update announcement: $e');
      _setLoading(false);
    }
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    _setLoading(true);
    try {
      await _adminService.deleteAnnouncement(announcementId);
      await loadAnnouncements();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to delete announcement: $e');
      _setLoading(false);
    }
  }

  // Explore Content
  Future<void> createExploreContent(ExploreContentModel content) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _adminService.createExploreContent(content);
      await loadExploreContent();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to create explore content: $e');
      _setLoading(false);
    }
  }

  Future<void> loadExploreContent({
    String? category,
    bool publishedOnly = true,
    bool featuredOnly = false,
  }) async {
    _setLoading(true);
    try {
      _exploreContent = await _adminService.getExploreContent(
        category: category,
        publishedOnly: publishedOnly,
        featuredOnly: featuredOnly,
      );
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load explore content: $e');
      _setLoading(false);
    }
  }

  Future<void> updateExploreContent(String contentId, Map<String, dynamic> updates) async {
    _setLoading(true);
    try {
      await _adminService.updateExploreContent(contentId, updates);
      await loadExploreContent();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to update explore content: $e');
      _setLoading(false);
    }
  }

  Future<void> deleteExploreContent(String contentId) async {
    _setLoading(true);
    try {
      await _adminService.deleteExploreContent(contentId);
      await loadExploreContent();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to delete explore content: $e');
      _setLoading(false);
    }
  }

  // User Management
  Future<void> loadUsers({int limit = 50}) async {
    _setLoading(true);
    try {
      _users = await _adminService.getUsers(limit: limit);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load users: $e');
      _setLoading(false);
    }
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    _setLoading(true);
    try {
      await _adminService.updateUserRole(userId, newRole);
      await loadUsers();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to update user role: $e');
      _setLoading(false);
    }
  }

  Future<void> deactivateUser(String userId) async {
    _setLoading(true);
    try {
      await _adminService.deactivateUser(userId);
      await loadUsers();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to deactivate user: $e');
      _setLoading(false);
    }
  }

  Future<void> activateUser(String userId) async {
    _setLoading(true);
    try {
      await _adminService.activateUser(userId);
      await loadUsers();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to activate user: $e');
      _setLoading(false);
    }
  }

  // Analytics
  Future<void> loadAnalytics() async {
    _setLoading(true);
    try {
      _analytics = await _adminService.getAnalytics();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load analytics: $e');
      _setLoading(false);
    }
  }

  // Utility methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Check permissions
  bool canManageUsers() {
    return _isAdmin && (_userRole == 'admin' || _userRole == 'super_admin');
  }

  bool canManageContent() {
    return _isAdmin;
  }

  bool canManageNotifications() {
    return _isAdmin;
  }

  bool canViewAnalytics() {
    return _isAdmin;
  }

  bool isSuperAdmin() {
    return _isAdmin && _userRole == 'super_admin';
  }

  Future<void> markNotificationAsRead(NotificationModel notification, String userId) async {
    try {
      await _adminService.markNotificationAsRead(notification.id, userId);
      // Optionally update local state
      _notifications = _notifications.map((n) =>
        n.id == notification.id ? n.copyWith(isRead: true) : n
      ).toList();
      notifyListeners();
    } catch (e) {
      _setError('Failed to mark notification as read: $e');
    }
  }

  Future<void> likeArticle(String articleId, String userId) async {
    await _adminService.likeArticle(articleId, userId);
    await loadExploreContent(publishedOnly: true);
  }

  Future<void> unlikeArticle(String articleId, String userId) async {
    await _adminService.unlikeArticle(articleId, userId);
    await loadExploreContent(publishedOnly: true);
  }

  Future<void> bookmarkArticle(String articleId, String userId) async {
    await _adminService.bookmarkArticle(articleId, userId);
    await loadExploreContent(publishedOnly: true);
  }

  Future<void> unbookmarkArticle(String articleId, String userId) async {
    await _adminService.unbookmarkArticle(articleId, userId);
    await loadExploreContent(publishedOnly: true);
  }
} 