import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Comprehensive real-time notification service
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _isInitialized = false;
  static Function(NotificationModel)? _onNotificationReceived;

  /// Initialize notification service
  static Future<void> initialize({
    Function(NotificationModel)? onNotificationReceived,
  }) async {
    if (_isInitialized) return;

    _onNotificationReceived = onNotificationReceived;

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();

    _isInitialized = true;
  }

  /// Request notification permissions
  static Future<bool> _requestPermissions() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      await android.requestNotificationsPermission();
    }

    final ios = _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (ios != null) {
      await ios.requestPermissions(alert: true, badge: true, sound: true);
    }

    return true;
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (_onNotificationReceived != null && response.payload != null) {
      // Parse notification data and handle navigation
      final data = response.payload!.split('|');
      if (data.length >= 3) {
        final notification = NotificationModel(
          id: data[0],
          userId: '', // Unknown user from notification tap
          type: NotificationType.values.firstWhere(
            (e) => e.toString() == data[1],
            orElse: () => NotificationType.general,
          ),
          title: data[2],
          message: data.length > 3 ? data[3] : '',
          createdAt: DateTime.now(),
        );
        _onNotificationReceived!(notification);
      }
    }
  }

  /// Show local notification
  static Future<void> showNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.general,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'marketplace_notifications',
      'Marketplace Notifications',
      channelDescription: 'Notifications for marketplace orders and messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      message,
      details,
      payload: payload,
    );
  }

  /// Create notification in Firestore
  static Future<String> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
    bool sendPushNotification = true,
  }) async {
    try {
      final notification = {
        'userId': userId,
        'type': type.toString(),
        'title': title,
        'message': message,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('notifications')
          .add(notification);

      // Send local notification if user is currently active
      if (sendPushNotification) {
        await showNotification(
          title: title,
          message: message,
          type: type,
          payload: '${docRef.id}|${type.toString()}|$title|$message',
        );
      }

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Send order notification to vendor
  static Future<void> sendOrderNotification({
    required String vendorId,
    required String orderId,
    required String customerName,
    required String productName,
    required double amount,
    OrderNotificationType orderType = OrderNotificationType.newOrder,
  }) async {
    String title, message;

    switch (orderType) {
      case OrderNotificationType.newOrder:
        title = '🎉 New Order Received!';
        message =
            '$customerName ordered $productName for ₳${amount.toStringAsFixed(2)}';
        break;
      case OrderNotificationType.orderCancelled:
        title = '❌ Order Cancelled';
        message = 'Order for $productName has been cancelled';
        break;
      case OrderNotificationType.paymentReceived:
        title = '💰 Payment Received';
        message =
            'Payment of ₳${amount.toStringAsFixed(2)} received for $productName';
        break;
      case OrderNotificationType.orderCompleted:
        title = '✅ Order Completed';
        message = 'Order for $productName has been marked as completed';
        break;
    }

    await createNotification(
      userId: vendorId,
      type: NotificationType.order,
      title: title,
      message: message,
      data: {
        'orderId': orderId,
        'orderType': orderType.toString(),
        'amount': amount,
        'productName': productName,
        'customerName': customerName,
      },
    );
  }

  /// Send order update to customer
  static Future<void> sendCustomerOrderUpdate({
    required String customerId,
    required String orderId,
    required String productName,
    required String vendorName,
    required OrderStatusType statusType,
    String? trackingNumber,
  }) async {
    String title, message;

    switch (statusType) {
      case OrderStatusType.confirmed:
        title = '✅ Order Confirmed';
        message = '$vendorName confirmed your order for $productName';
        break;
      case OrderStatusType.processing:
        title = '📦 Order Processing';
        message = 'Your order for $productName is being prepared';
        break;
      case OrderStatusType.shipped:
        title = '🚚 Order Shipped';
        message = 'Your order for $productName has been shipped';
        if (trackingNumber != null) {
          message += ' (Tracking: $trackingNumber)';
        }
        break;
      case OrderStatusType.delivered:
        title = '🎉 Order Delivered';
        message = 'Your order for $productName has been delivered!';
        break;
      case OrderStatusType.cancelled:
        title = '❌ Order Cancelled';
        message = 'Your order for $productName has been cancelled';
        break;
    }

    await createNotification(
      userId: customerId,
      type: NotificationType.order,
      title: title,
      message: message,
      data: {
        'orderId': orderId,
        'statusType': statusType.toString(),
        'productName': productName,
        'vendorName': vendorName,
        'trackingNumber': trackingNumber,
      },
    );
  }

  /// Send message notification
  static Future<void> sendMessageNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String conversationId,
  }) async {
    await createNotification(
      userId: recipientId,
      type: NotificationType.message,
      title: '💬 New Message from $senderName',
      message: message.length > 50 ? '${message.substring(0, 50)}...' : message,
      data: {
        'conversationId': conversationId,
        'senderName': senderName,
        'fullMessage': message,
      },
    );
  }

  /// Send vendor verification notification
  static Future<void> sendVendorVerificationNotification({
    required String vendorId,
    required bool isApproved,
    String? reason,
  }) async {
    final title = isApproved
        ? '🎉 Vendor Application Approved!'
        : '❌ Vendor Application Declined';

    final message = isApproved
        ? 'Congratulations! You can now start selling on our marketplace.'
        : 'Your vendor application was declined. ${reason ?? "Please review requirements and reapply."}';

    await createNotification(
      userId: vendorId,
      type: NotificationType.verification,
      title: title,
      message: message,
      data: {'isApproved': isApproved, 'reason': reason},
    );
  }

  /// Send promotional notification
  static Future<void> sendPromotionalNotification({
    required String userId,
    required String title,
    required String message,
    String? imageUrl,
    String? actionUrl,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.promotion,
      title: title,
      message: message,
      data: {'imageUrl': imageUrl, 'actionUrl': actionUrl},
    );
  }

  /// Get user notifications stream
  static Stream<List<NotificationModel>> getUserNotifications({
    required String userId,
    int limit = 50,
  }) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get unread notification count
  static Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {}
  }

  /// Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {}
  }

  /// Delete all notifications for user
  static Future<void> deleteAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {}
  }

  /// Send bulk notifications
  static Future<void> sendBulkNotifications({
    required List<String> userIds,
    required String title,
    required String message,
    NotificationType type = NotificationType.general,
    Map<String, dynamic> data = const {},
  }) async {
    final batch = _firestore.batch();

    for (final userId in userIds) {
      final notification = {
        'userId': userId,
        'type': type.toString(),
        'title': title,
        'message': message,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = _firestore.collection('notifications').doc();
      batch.set(docRef, notification);
    }

    await batch.commit();
  }

  /// Send raffle-specific notifications
  static Future<void> sendRaffleNotification({
    required String userId,
    required String raffleId,
    required String raffleTitle,
    required RaffleNotificationType notificationType,
    String? additionalMessage,
    Map<String, dynamic> data = const {},
  }) async {
    String title = '';
    String message = '';

    switch (notificationType) {
      case RaffleNotificationType.raffleCreated:
        title = '🎉 New Raffle Available!';
        message = 'Check out the new raffle: "$raffleTitle"';
        break;
      case RaffleNotificationType.raffleStarting:
        title = '🚀 Raffle Starting Soon!';
        message = '"$raffleTitle" is about to begin!';
        break;
      case RaffleNotificationType.raffleEnding:
        title = '⏰ Raffle Ending Soon!';
        message = '"$raffleTitle" ends soon. Enter now!';
        break;
      case RaffleNotificationType.entryConfirmed:
        title = '✅ Entry Confirmed';
        message = 'Your entry for "$raffleTitle" has been confirmed!';
        break;
      case RaffleNotificationType.winnerSelected:
        title = '🎊 Congratulations!';
        message = 'You won "$raffleTitle"! Check your prize details.';
        break;
      case RaffleNotificationType.prizeClaimed:
        title = '🎁 Prize Claimed';
        message =
            'Your prize from "$raffleTitle" has been claimed successfully.';
        break;
      case RaffleNotificationType.raffleCompleted:
        title = '🏁 Raffle Completed';
        message = '"$raffleTitle" has ended. Check the results!';
        break;
    }

    if (additionalMessage != null) {
      message += ' $additionalMessage';
    }

    await createNotification(
      userId: userId,
      type: NotificationType.raffle,
      title: title,
      message: message,
      data: {
        'raffleId': raffleId,
        'raffleTitle': raffleTitle,
        'notificationType': notificationType.toString(),
        ...data,
      },
    );
  }

  /// Send raffle reminder notifications
  static Future<void> sendRaffleReminder({
    required List<String> userIds,
    required String raffleId,
    required String raffleTitle,
    required RaffleReminderType reminderType,
  }) async {
    String title = '';
    String message = '';

    switch (reminderType) {
      case RaffleReminderType.startingSoon:
        title = '⏰ Raffle Starting Soon';
        message = '"$raffleTitle" starts in less than 24 hours!';
        break;
      case RaffleReminderType.endingSoon:
        title = '🚨 Raffle Ending Soon';
        message = '"$raffleTitle" ends in less than 24 hours. Don\'t miss out!';
        break;
      case RaffleReminderType.notEntered:
        title = '🎯 Don\'t Miss This Raffle!';
        message = 'You haven\'t entered "$raffleTitle" yet. Enter now!';
        break;
    }

    await sendBulkNotifications(
      userIds: userIds,
      title: title,
      message: message,
      type: NotificationType.raffle,
      data: {
        'raffleId': raffleId,
        'raffleTitle': raffleTitle,
        'reminderType': reminderType.toString(),
      },
    );
  }
}

/// Notification model
class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => NotificationType.general,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString(),
      'title': title,
      'message': message,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }
}

/// Notification types
enum NotificationType {
  general,
  order,
  message,
  payment,
  verification,
  promotion,
  system,
  raffle,
}

/// Order notification types
enum OrderNotificationType {
  newOrder,
  orderCancelled,
  paymentReceived,
  orderCompleted,
}

/// Order status types
enum OrderStatusType { confirmed, processing, shipped, delivered, cancelled }

/// Raffle notification types
enum RaffleNotificationType {
  raffleCreated,
  raffleStarting,
  raffleEnding,
  entryConfirmed,
  winnerSelected,
  prizeClaimed,
  raffleCompleted,
}

/// Raffle reminder types
enum RaffleReminderType { startingSoon, endingSoon, notEntered }
