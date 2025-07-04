class ExploreContentModel {
  final String id;
  final String title;
  final String description;
  final String category; // 'news', 'tutorials', 'events', 'projects'
  final String? imageUrl;
  final String? content; // Full article content
  final DateTime createdAt;
  final DateTime? publishDate;
  final DateTime? expiryDate;
  final bool isPublished;
  final bool isFeatured;
  final int priority;
  final String createdBy; // admin ID
  final Map<String, dynamic>? metadata;
  final List<String>? tags;
  final String? externalUrl;
  final int? readCount;
  final int? likeCount;
  final List<String> likes;
  final List<String> bookmarks;

  ExploreContentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.imageUrl,
    this.content,
    required this.createdAt,
    this.publishDate,
    this.expiryDate,
    this.isPublished = false,
    this.isFeatured = false,
    this.priority = 1,
    required this.createdBy,
    this.metadata,
    this.tags,
    this.externalUrl,
    this.readCount = 0,
    this.likeCount = 0,
    this.likes = const [],
    this.bookmarks = const [],
  });

  factory ExploreContentModel.fromMap(Map<String, dynamic> map) {
    return ExploreContentModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'news',
      imageUrl: map['imageUrl'],
      content: map['content'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is DateTime 
              ? map['createdAt'] 
              : DateTime.parse(map['createdAt']))
          : DateTime.now(),
      publishDate: map['publishDate'] != null 
          ? (map['publishDate'] is DateTime 
              ? map['publishDate'] 
              : DateTime.parse(map['publishDate']))
          : null,
      expiryDate: map['expiryDate'] != null 
          ? (map['expiryDate'] is DateTime 
              ? map['expiryDate'] 
              : DateTime.parse(map['expiryDate']))
          : null,
      isPublished: map['isPublished'] ?? false,
      isFeatured: map['isFeatured'] ?? false,
      priority: map['priority'] ?? 1,
      createdBy: map['createdBy'] ?? '',
      metadata: map['metadata'],
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      externalUrl: map['externalUrl'],
      readCount: map['readCount'] ?? 0,
      likeCount: map['likeCount'] ?? 0,
      likes: map['likes'] != null ? List<String>.from(map['likes']) : [],
      bookmarks: map['bookmarks'] != null ? List<String>.from(map['bookmarks']) : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'publishDate': publishDate?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'isPublished': isPublished,
      'isFeatured': isFeatured,
      'priority': priority,
      'createdBy': createdBy,
      'metadata': metadata,
      'tags': tags,
      'externalUrl': externalUrl,
      'readCount': readCount,
      'likeCount': likeCount,
      'likes': likes,
      'bookmarks': bookmarks,
    };
  }

  ExploreContentModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    String? content,
    DateTime? createdAt,
    DateTime? publishDate,
    DateTime? expiryDate,
    bool? isPublished,
    bool? isFeatured,
    int? priority,
    String? createdBy,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    String? externalUrl,
    int? readCount,
    int? likeCount,
    List<String>? likes,
    List<String>? bookmarks,
  }) {
    return ExploreContentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      publishDate: publishDate ?? this.publishDate,
      expiryDate: expiryDate ?? this.expiryDate,
      isPublished: isPublished ?? this.isPublished,
      isFeatured: isFeatured ?? this.isFeatured,
      priority: priority ?? this.priority,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      externalUrl: externalUrl ?? this.externalUrl,
      readCount: readCount ?? this.readCount,
      likeCount: likeCount ?? this.likeCount,
      likes: likes ?? this.likes,
      bookmarks: bookmarks ?? this.bookmarks,
    );
  }

  int get likeTotal => likes.length;
  int get bookmarkTotal => bookmarks.length;
  bool isLikedBy(String userId) => likes.contains(userId);
  bool isBookmarkedBy(String userId) => bookmarks.contains(userId);
} 