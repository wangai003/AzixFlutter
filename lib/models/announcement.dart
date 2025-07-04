class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final int priority; // 1-5, higher number = higher priority
  final String? actionUrl;
  final String? actionText;
  final String createdBy; // admin ID
  final List<String>? targetAudience; // user IDs or 'all' for everyone

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.priority = 1,
    this.actionUrl,
    this.actionText,
    required this.createdBy,
    this.targetAudience,
  });

  factory AnnouncementModel.fromMap(Map<String, dynamic> map) {
    return AnnouncementModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
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
      isActive: map['isActive'] ?? true,
      priority: map['priority'] ?? 1,
      actionUrl: map['actionUrl'],
      actionText: map['actionText'],
      createdBy: map['createdBy'] ?? '',
      targetAudience: map['targetAudience'] != null 
          ? List<String>.from(map['targetAudience'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isActive': isActive,
      'priority': priority,
      'actionUrl': actionUrl,
      'actionText': actionText,
      'createdBy': createdBy,
      'targetAudience': targetAudience,
    };
  }

  AnnouncementModel copyWith({
    String? id,
    String? title,
    String? content,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    int? priority,
    String? actionUrl,
    String? actionText,
    String? createdBy,
    List<String>? targetAudience,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      actionUrl: actionUrl ?? this.actionUrl,
      actionText: actionText ?? this.actionText,
      createdBy: createdBy ?? this.createdBy,
      targetAudience: targetAudience ?? this.targetAudience,
    );
  }
} 