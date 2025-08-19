import 'package:cloud_firestore/cloud_firestore.dart';

/// Advanced messaging system for buyer-vendor communication
class Conversation {
  final String id;
  final List<String> participants;
  final String? orderId; // Associated order if applicable
  final String? listingId; // Associated listing if applicable
  final ConversationType type;
  final ConversationStatus status;
  final Message? lastMessage;
  final Map<String, int> unreadCounts; // userId -> unread count
  final Map<String, DateTime> lastSeenAt; // userId -> last seen timestamp
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags; // For categorization
  final Map<String, dynamic> metadata;

  Conversation({
    required this.id,
    required this.participants,
    this.orderId,
    this.listingId,
    required this.type,
    required this.status,
    this.lastMessage,
    required this.unreadCounts,
    required this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.metadata = const {},
  });

  factory Conversation.fromJson(Map<String, dynamic> json, String id) {
    return Conversation(
      id: id,
      participants: List<String>.from(json['participants'] ?? []),
      orderId: json['orderId'],
      listingId: json['listingId'],
      type: ConversationType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => ConversationType.inquiry,
      ),
      status: ConversationStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => ConversationStatus.active,
      ),
      lastMessage: json['lastMessage'] != null 
          ? Message.fromJson(json['lastMessage'], 'last')
          : null,
      unreadCounts: Map<String, int>.from(json['unreadCounts'] ?? {}),
      lastSeenAt: (json['lastSeenAt'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as Timestamp).toDate())
      ) ?? {},
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: List<String>.from(json['tags'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participants': participants,
      'orderId': orderId,
      'listingId': listingId,
      'type': type.toString(),
      'status': status.toString(),
      'lastMessage': lastMessage?.toJson(),
      'unreadCounts': unreadCounts,
      'lastSeenAt': lastSeenAt.map(
        (k, v) => MapEntry(k, Timestamp.fromDate(v))
      ),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'tags': tags,
      'metadata': metadata,
    };
  }

  bool hasUnreadMessages(String userId) {
    return (unreadCounts[userId] ?? 0) > 0;
  }

  String getOtherParticipant(String currentUserId) {
    return participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
  }
}

enum ConversationType {
  inquiry,      // General inquiry about listing
  negotiation,  // Price/terms negotiation
  order,        // Order-related communication
  support,      // Customer support
  dispute       // Dispute resolution
}

enum ConversationStatus {
  active,       // Active conversation
  archived,     // Archived by user
  blocked,      // One user blocked the other
  resolved,     // Issue resolved (for support/disputes)
  closed        // Conversation closed
}

class Message {
  final String id;
  final String senderId;
  final String conversationId;
  final MessageType type;
  final String content;
  final List<MessageAttachment> attachments;
  final String? replyToMessageId;
  final Message? quotedMessage;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final Map<String, dynamic> metadata;

  Message({
    required this.id,
    required this.senderId,
    required this.conversationId,
    required this.type,
    required this.content,
    this.attachments = const [],
    this.replyToMessageId,
    this.quotedMessage,
    required this.status,
    required this.createdAt,
    this.editedAt,
    this.deliveredAt,
    this.readAt,
    this.metadata = const {},
  });

  factory Message.fromJson(Map<String, dynamic> json, String id) {
    return Message(
      id: id,
      senderId: json['senderId'] ?? '',
      conversationId: json['conversationId'] ?? '',
      type: MessageType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'] ?? '',
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((a) => MessageAttachment.fromJson(a))
              .toList() ??
          [],
      replyToMessageId: json['replyToMessageId'],
      quotedMessage: json['quotedMessage'] != null 
          ? Message.fromJson(json['quotedMessage'], 'quoted')
          : null,
      status: MessageStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedAt: (json['editedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (json['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (json['readAt'] as Timestamp?)?.toDate(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'conversationId': conversationId,
      'type': type.toString(),
      'content': content,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'replyToMessageId': replyToMessageId,
      'quotedMessage': quotedMessage?.toJson(),
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'metadata': metadata,
    };
  }

  bool get isRead => readAt != null;
  bool get isDelivered => deliveredAt != null;
  bool get isEdited => editedAt != null;
  bool get hasAttachments => attachments.isNotEmpty;
}

enum MessageType {
  text,         // Plain text message
  image,        // Image message
  file,         // File attachment
  audio,        // Audio message
  system,       // System message (order updates, etc.)
  offer,        // Price offer/counter-offer
  quickReply    // Quick reply/template response
}

enum MessageStatus {
  sending,      // Message being sent
  sent,         // Message sent successfully
  delivered,    // Message delivered to recipient
  read,         // Message read by recipient
  failed        // Message failed to send
}

class MessageAttachment {
  final String id;
  final AttachmentType type;
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String? mimeType;
  final Map<String, dynamic>? dimensions; // For images/videos
  final String? thumbnailUrl;
  final DateTime uploadedAt;

  MessageAttachment({
    required this.id,
    required this.type,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    this.mimeType,
    this.dimensions,
    this.thumbnailUrl,
    required this.uploadedAt,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] ?? '',
      type: AttachmentType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => AttachmentType.file,
      ),
      fileName: json['fileName'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      mimeType: json['mimeType'],
      dimensions: json['dimensions'] != null 
          ? Map<String, dynamic>.from(json['dimensions'])
          : null,
      thumbnailUrl: json['thumbnailUrl'],
      uploadedAt: (json['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'dimensions': dimensions,
      'thumbnailUrl': thumbnailUrl,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  bool get isImage => type == AttachmentType.image;
  bool get isVideo => type == AttachmentType.video;
  bool get isAudio => type == AttachmentType.audio;
  bool get isDocument => type == AttachmentType.document;

  String get formattedFileSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

enum AttachmentType {
  image,
  video,
  audio,
  document,
  file
}

/// Message templates for quick responses
class MessageTemplate {
  final String id;
  final String title;
  final String content;
  final TemplateCategory category;
  final List<String> tags;
  final bool isActive;
  final String createdBy; // vendor who created it
  final DateTime createdAt;
  final int usageCount;

  MessageTemplate({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.tags = const [],
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    this.usageCount = 0,
  });

  factory MessageTemplate.fromJson(Map<String, dynamic> json, String id) {
    return MessageTemplate(
      id: id,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: TemplateCategory.values.firstWhere(
        (c) => c.toString() == json['category'],
        orElse: () => TemplateCategory.general,
      ),
      tags: List<String>.from(json['tags'] ?? []),
      isActive: json['isActive'] ?? true,
      createdBy: json['createdBy'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usageCount: json['usageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'category': category.toString(),
      'tags': tags,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'usageCount': usageCount,
    };
  }
}

enum TemplateCategory {
  greeting,     // Welcome messages
  inquiry,      // Responding to inquiries
  negotiation,  // Price negotiations
  order,        // Order confirmations/updates
  delivery,     // Delivery notifications
  support,      // Support responses
  closing,      // Conversation closers
  general       // General responses
}

/// Auto-responses and chatbot functionality
class AutoResponse {
  final String id;
  final String vendorId;
  final List<String> triggers; // Keywords that trigger this response
  final String response;
  final AutoResponseType type;
  final bool isActive;
  final TimeRange? activeHours; // When this auto-response is active
  final int priority; // Higher priority responses are used first
  final DateTime createdAt;
  final DateTime updatedAt;
  final int usageCount;

  AutoResponse({
    required this.id,
    required this.vendorId,
    required this.triggers,
    required this.response,
    required this.type,
    this.isActive = true,
    this.activeHours,
    this.priority = 0,
    required this.createdAt,
    required this.updatedAt,
    this.usageCount = 0,
  });

  factory AutoResponse.fromJson(Map<String, dynamic> json, String id) {
    return AutoResponse(
      id: id,
      vendorId: json['vendorId'] ?? '',
      triggers: List<String>.from(json['triggers'] ?? []),
      response: json['response'] ?? '',
      type: AutoResponseType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => AutoResponseType.keyword,
      ),
      isActive: json['isActive'] ?? true,
      activeHours: json['activeHours'] != null 
          ? TimeRange.fromJson(json['activeHours'])
          : null,
      priority: json['priority'] ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usageCount: json['usageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendorId': vendorId,
      'triggers': triggers,
      'response': response,
      'type': type.toString(),
      'isActive': isActive,
      'activeHours': activeHours?.toJson(),
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'usageCount': usageCount,
    };
  }

  bool isTriggeredBy(String message) {
    final lowercaseMessage = message.toLowerCase();
    return triggers.any((trigger) => 
        lowercaseMessage.contains(trigger.toLowerCase()));
  }

  bool isActiveNow() {
    if (!isActive) return false;
    if (activeHours == null) return true;
    return activeHours!.isCurrentTimeInRange();
  }
}

enum AutoResponseType {
  keyword,      // Triggered by keywords
  greeting,     // Auto greeting for new conversations
  offline,      // Out of office message
  busy,         // Busy message
  faq          // FAQ responses
}

class TimeRange {
  final int startHour; // 0-23
  final int startMinute; // 0-59
  final int endHour; // 0-23
  final int endMinute; // 0-59
  final List<int> daysOfWeek; // 1-7 (Monday-Sunday)

  TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.daysOfWeek,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      startHour: json['startHour'] ?? 0,
      startMinute: json['startMinute'] ?? 0,
      endHour: json['endHour'] ?? 23,
      endMinute: json['endMinute'] ?? 59,
      daysOfWeek: List<int>.from(json['daysOfWeek'] ?? [1, 2, 3, 4, 5, 6, 7]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'daysOfWeek': daysOfWeek,
    };
  }

  bool isCurrentTimeInRange() {
    final now = DateTime.now();
    final currentDay = now.weekday;
    
    if (!daysOfWeek.contains(currentDay)) return false;
    
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    
    if (startMinutes <= endMinutes) {
      // Same day range
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight range
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }
}

/// Messaging analytics for vendors
class MessagingAnalytics {
  final String vendorId;
  final DateTime date;
  final int totalConversations;
  final int newConversations;
  final int totalMessages;
  final int sentMessages;
  final int receivedMessages;
  final double averageResponseTime; // in minutes
  final double responseRate; // percentage of messages responded to
  final int conversionsFromMessages; // orders from conversations
  final Map<String, int> messageTypeBreakdown;
  final Map<String, int> conversationSourceBreakdown;

  MessagingAnalytics({
    required this.vendorId,
    required this.date,
    required this.totalConversations,
    required this.newConversations,
    required this.totalMessages,
    required this.sentMessages,
    required this.receivedMessages,
    required this.averageResponseTime,
    required this.responseRate,
    required this.conversionsFromMessages,
    required this.messageTypeBreakdown,
    required this.conversationSourceBreakdown,
  });

  factory MessagingAnalytics.fromJson(Map<String, dynamic> json, String id) {
    return MessagingAnalytics(
      vendorId: json['vendorId'] ?? '',
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalConversations: json['totalConversations'] ?? 0,
      newConversations: json['newConversations'] ?? 0,
      totalMessages: json['totalMessages'] ?? 0,
      sentMessages: json['sentMessages'] ?? 0,
      receivedMessages: json['receivedMessages'] ?? 0,
      averageResponseTime: (json['averageResponseTime'] ?? 0.0).toDouble(),
      responseRate: (json['responseRate'] ?? 0.0).toDouble(),
      conversionsFromMessages: json['conversionsFromMessages'] ?? 0,
      messageTypeBreakdown: Map<String, int>.from(json['messageTypeBreakdown'] ?? {}),
      conversationSourceBreakdown: Map<String, int>.from(json['conversationSourceBreakdown'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendorId': vendorId,
      'date': Timestamp.fromDate(date),
      'totalConversations': totalConversations,
      'newConversations': newConversations,
      'totalMessages': totalMessages,
      'sentMessages': sentMessages,
      'receivedMessages': receivedMessages,
      'averageResponseTime': averageResponseTime,
      'responseRate': responseRate,
      'conversionsFromMessages': conversionsFromMessages,
      'messageTypeBreakdown': messageTypeBreakdown,
      'conversationSourceBreakdown': conversationSourceBreakdown,
    };
  }

  String get formattedResponseTime {
    if (averageResponseTime < 60) {
      return '${averageResponseTime.toStringAsFixed(1)} min';
    } else {
      final hours = (averageResponseTime / 60).toStringAsFixed(1);
      return '${hours} hrs';
    }
  }
}
