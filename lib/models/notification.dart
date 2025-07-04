class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'announcement', 'marketing', 'system', 'transaction'
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isRead;
  final String? userId; // null for broadcast notifications
  final Map<String, dynamic>? metadata;
  final String? actionUrl;
  final String? actionText;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.expiresAt,
    this.isRead = false,
    this.userId,
    this.metadata,
    this.actionUrl,
    this.actionText,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'system',
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is DateTime 
              ? map['createdAt'] 
              : DateTime.parse(map['createdAt']))
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null 
          ? (map['expiresAt'] is DateTime 
              ? map['expiresAt'] 
              : DateTime.parse(map['expiresAt']))
          : null,
      isRead: map['isRead'] ?? false,
      userId: map['userId'],
      metadata: map['metadata'],
      actionUrl: map['actionUrl'],
      actionText: map['actionText'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isRead': isRead,
      'userId': userId,
      'metadata': metadata,
      'actionUrl': actionUrl,
      'actionText': actionText,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isRead,
    String? userId,
    Map<String, dynamic>? metadata,
    String? actionUrl,
    String? actionText,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      userId: userId ?? this.userId,
      metadata: metadata ?? this.metadata,
      actionUrl: actionUrl ?? this.actionUrl,
      actionText: actionText ?? this.actionText,
    );
  }
} 