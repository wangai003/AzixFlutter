import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive review and rating system
class Review {
  final String id;
  final String reviewerId;
  final String revieweeId; // vendor being reviewed
  final String? orderId;
  final String? listingId;
  final ReviewType type;
  final double rating; // 1-5 stars
  final String title;
  final String content;
  final List<ReviewCriteria> criteriaRatings; // Detailed ratings
  final List<String> images; // Review images
  final ReviewStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ReviewResponse> responses; // Vendor responses
  final ReviewHelpfulness helpfulness;
  final List<String> tags; // helpful, detailed, verified, etc.
  final bool isVerifiedPurchase;
  final Map<String, dynamic> metadata;

  Review({
    required this.id,
    required this.reviewerId,
    required this.revieweeId,
    this.orderId,
    this.listingId,
    required this.type,
    required this.rating,
    required this.title,
    required this.content,
    this.criteriaRatings = const [],
    this.images = const [],
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.responses = const [],
    required this.helpfulness,
    this.tags = const [],
    this.isVerifiedPurchase = false,
    this.metadata = const {},
  });

  factory Review.fromJson(Map<String, dynamic> json, String id) {
    return Review(
      id: id,
      reviewerId: json['reviewerId'] ?? '',
      revieweeId: json['revieweeId'] ?? '',
      orderId: json['orderId'],
      listingId: json['listingId'],
      type: ReviewType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => ReviewType.listing,
      ),
      rating: (json['rating'] ?? 0.0).toDouble(),
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      criteriaRatings: (json['criteriaRatings'] as List<dynamic>?)
              ?.map((c) => ReviewCriteria.fromJson(c))
              .toList() ??
          [],
      images: List<String>.from(json['images'] ?? []),
      status: ReviewStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => ReviewStatus.pending,
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      responses: (json['responses'] as List<dynamic>?)
              ?.map((r) => ReviewResponse.fromJson(r))
              .toList() ??
          [],
      helpfulness: ReviewHelpfulness.fromJson(json['helpfulness'] ?? {}),
      tags: List<String>.from(json['tags'] ?? []),
      isVerifiedPurchase: json['isVerifiedPurchase'] ?? false,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewerId': reviewerId,
      'revieweeId': revieweeId,
      'orderId': orderId,
      'listingId': listingId,
      'type': type.toString(),
      'rating': rating,
      'title': title,
      'content': content,
      'criteriaRatings': criteriaRatings.map((c) => c.toJson()).toList(),
      'images': images,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'responses': responses.map((r) => r.toJson()).toList(),
      'helpfulness': helpfulness.toJson(),
      'tags': tags,
      'isVerifiedPurchase': isVerifiedPurchase,
      'metadata': metadata,
    };
  }

  bool get hasResponse => responses.isNotEmpty;
  bool get isPositive => rating >= 4.0;
  bool get isNegative => rating <= 2.0;
  int get helpfulnessScore => helpfulness.helpful - helpfulness.notHelpful;
}

enum ReviewType {
  listing,      // Review of a product/service
  vendor,       // Overall vendor review
  order,        // Order experience review
  delivery      // Delivery/shipping review
}

enum ReviewStatus {
  pending,      // Awaiting moderation
  approved,     // Approved and visible
  rejected,     // Rejected by moderation
  flagged,      // Flagged for review
  hidden        // Hidden by admin/vendor
}

class ReviewCriteria {
  final String name;
  final double rating;
  final String? comment;

  ReviewCriteria({
    required this.name,
    required this.rating,
    this.comment,
  });

  factory ReviewCriteria.fromJson(Map<String, dynamic> json) {
    return ReviewCriteria(
      name: json['name'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      comment: json['comment'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'rating': rating,
      'comment': comment,
    };
  }
}

class ReviewResponse {
  final String id;
  final String responderId; // Usually the vendor
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewResponse({
    required this.id,
    required this.responderId,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  factory ReviewResponse.fromJson(Map<String, dynamic> json) {
    return ReviewResponse(
      id: json['id'] ?? '',
      responderId: json['responderId'] ?? '',
      content: json['content'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'responderId': responderId,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

class ReviewHelpfulness {
  final int helpful;
  final int notHelpful;
  final List<String> helpfulUsers;
  final List<String> notHelpfulUsers;

  ReviewHelpfulness({
    this.helpful = 0,
    this.notHelpful = 0,
    this.helpfulUsers = const [],
    this.notHelpfulUsers = const [],
  });

  factory ReviewHelpfulness.fromJson(Map<String, dynamic> json) {
    return ReviewHelpfulness(
      helpful: json['helpful'] ?? 0,
      notHelpful: json['notHelpful'] ?? 0,
      helpfulUsers: List<String>.from(json['helpfulUsers'] ?? []),
      notHelpfulUsers: List<String>.from(json['notHelpfulUsers'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'helpful': helpful,
      'notHelpful': notHelpful,
      'helpfulUsers': helpfulUsers,
      'notHelpfulUsers': notHelpfulUsers,
    };
  }

  bool hasUserVoted(String userId) {
    return helpfulUsers.contains(userId) || notHelpfulUsers.contains(userId);
  }

  bool didUserFindHelpful(String userId) {
    return helpfulUsers.contains(userId);
  }
}

/// Comprehensive rating analytics for vendors and listings
class RatingAnalytics {
  final String entityId; // vendor or listing ID
  final EntityType entityType;
  final double overallRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // star -> count
  final Map<String, double> criteriaAverages; // criteria -> average rating
  final List<ReviewTrend> trends; // Rating trends over time
  final DateTime lastUpdated;

  RatingAnalytics({
    required this.entityId,
    required this.entityType,
    required this.overallRating,
    required this.totalReviews,
    required this.ratingDistribution,
    required this.criteriaAverages,
    required this.trends,
    required this.lastUpdated,
  });

  factory RatingAnalytics.fromJson(Map<String, dynamic> json, String id) {
    return RatingAnalytics(
      entityId: id,
      entityType: EntityType.values.firstWhere(
        (t) => t.toString() == json['entityType'],
        orElse: () => EntityType.vendor,
      ),
      overallRating: (json['overallRating'] ?? 0.0).toDouble(),
      totalReviews: json['totalReviews'] ?? 0,
      ratingDistribution: Map<int, int>.from(json['ratingDistribution'] ?? {}),
      criteriaAverages: Map<String, double>.from(
        (json['criteriaAverages'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble()))
      ),
      trends: (json['trends'] as List<dynamic>?)
              ?.map((t) => ReviewTrend.fromJson(t))
              .toList() ??
          [],
      lastUpdated: (json['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entityType': entityType.toString(),
      'overallRating': overallRating,
      'totalReviews': totalReviews,
      'ratingDistribution': ratingDistribution,
      'criteriaAverages': criteriaAverages,
      'trends': trends.map((t) => t.toJson()).toList(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  double get ratingPercentage => (overallRating / 5.0) * 100;
  
  String get ratingDescription {
    if (overallRating >= 4.5) return 'Excellent';
    if (overallRating >= 4.0) return 'Very Good';
    if (overallRating >= 3.5) return 'Good';
    if (overallRating >= 3.0) return 'Average';
    if (overallRating >= 2.0) return 'Poor';
    return 'Very Poor';
  }

  int getReviewCountForStars(int stars) {
    return ratingDistribution[stars] ?? 0;
  }

  double getPercentageForStars(int stars) {
    if (totalReviews == 0) return 0.0;
    return (getReviewCountForStars(stars) / totalReviews) * 100;
  }
}

enum EntityType { vendor, listing }

class ReviewTrend {
  final DateTime period;
  final double averageRating;
  final int reviewCount;

  ReviewTrend({
    required this.period,
    required this.averageRating,
    required this.reviewCount,
  });

  factory ReviewTrend.fromJson(Map<String, dynamic> json) {
    return ReviewTrend(
      period: (json['period'] as Timestamp?)?.toDate() ?? DateTime.now(),
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': Timestamp.fromDate(period),
      'averageRating': averageRating,
      'reviewCount': reviewCount,
    };
  }
}

/// Trust and safety system
class TrustScore {
  final String entityId;
  final EntityType entityType;
  final double score; // 0-100
  final TrustLevel level;
  final List<TrustFactor> factors;
  final DateTime calculatedAt;
  final DateTime expiresAt;

  TrustScore({
    required this.entityId,
    required this.entityType,
    required this.score,
    required this.level,
    required this.factors,
    required this.calculatedAt,
    required this.expiresAt,
  });

  factory TrustScore.fromJson(Map<String, dynamic> json, String id) {
    return TrustScore(
      entityId: id,
      entityType: EntityType.values.firstWhere(
        (t) => t.toString() == json['entityType'],
        orElse: () => EntityType.vendor,
      ),
      score: (json['score'] ?? 0.0).toDouble(),
      level: TrustLevel.values.firstWhere(
        (l) => l.toString() == json['level'],
        orElse: () => TrustLevel.bronze,
      ),
      factors: (json['factors'] as List<dynamic>?)
              ?.map((f) => TrustFactor.fromJson(f))
              .toList() ??
          [],
      calculatedAt: (json['calculatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate() ?? 
          DateTime.now().add(const Duration(days: 30)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entityType': entityType.toString(),
      'score': score,
      'level': level.toString(),
      'factors': factors.map((f) => f.toJson()).toList(),
      'calculatedAt': Timestamp.fromDate(calculatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isVerified => level != TrustLevel.unverified;
}

enum TrustLevel {
  unverified,   // No verification
  bronze,       // Basic verification
  silver,       // Enhanced verification
  gold,         // Premium verification
  platinum      // Top-tier verification
}

extension TrustLevelExtension on TrustLevel {
  String get displayName {
    switch (this) {
      case TrustLevel.unverified:
        return 'Unverified';
      case TrustLevel.bronze:
        return 'Bronze';
      case TrustLevel.silver:
        return 'Silver';
      case TrustLevel.gold:
        return 'Gold';
      case TrustLevel.platinum:
        return 'Platinum';
    }
  }

  String get description {
    switch (this) {
      case TrustLevel.unverified:
        return 'No verification completed';
      case TrustLevel.bronze:
        return 'Basic identity verified';
      case TrustLevel.silver:
        return 'Enhanced verification completed';
      case TrustLevel.gold:
        return 'Premium vendor with excellent track record';
      case TrustLevel.platinum:
        return 'Top-tier vendor with outstanding performance';
    }
  }

  Color get color {
    switch (this) {
      case TrustLevel.unverified:
        return const Color(0xFF9E9E9E);
      case TrustLevel.bronze:
        return const Color(0xFFCD7F32);
      case TrustLevel.silver:
        return const Color(0xFFC0C0C0);
      case TrustLevel.gold:
        return const Color(0xFFFFD700);
      case TrustLevel.platinum:
        return const Color(0xFFE5E4E2);
    }
  }
}

class TrustFactor {
  final String name;
  final double weight; // How much this factor contributes to trust score
  final double value; // Current value for this factor
  final double maxValue; // Maximum possible value
  final bool isPositive; // Whether higher values are better
  final String description;

  TrustFactor({
    required this.name,
    required this.weight,
    required this.value,
    required this.maxValue,
    this.isPositive = true,
    required this.description,
  });

  factory TrustFactor.fromJson(Map<String, dynamic> json) {
    return TrustFactor(
      name: json['name'] ?? '',
      weight: (json['weight'] ?? 0.0).toDouble(),
      value: (json['value'] ?? 0.0).toDouble(),
      maxValue: (json['maxValue'] ?? 0.0).toDouble(),
      isPositive: json['isPositive'] ?? true,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight': weight,
      'value': value,
      'maxValue': maxValue,
      'isPositive': isPositive,
      'description': description,
    };
  }

  double get normalizedValue {
    if (maxValue == 0) return 0.0;
    return (value / maxValue).clamp(0.0, 1.0);
  }

  double get contribution {
    return normalizedValue * weight;
  }
}

/// Safety reporting system
class SafetyReport {
  final String id;
  final String reporterId;
  final String reportedEntityId;
  final SafetyReportType reportType;
  final EntityType entityType;
  final SafetyReportReason reason;
  final String description;
  final List<String> evidence; // URLs to evidence files
  final SafetyReportStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Admin ID
  final String? resolution;
  final SafetyAction? actionTaken;

  SafetyReport({
    required this.id,
    required this.reporterId,
    required this.reportedEntityId,
    required this.reportType,
    required this.entityType,
    required this.reason,
    required this.description,
    this.evidence = const [],
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.resolution,
    this.actionTaken,
  });

  factory SafetyReport.fromJson(Map<String, dynamic> json, String id) {
    return SafetyReport(
      id: id,
      reporterId: json['reporterId'] ?? '',
      reportedEntityId: json['reportedEntityId'] ?? '',
      reportType: SafetyReportType.values.firstWhere(
        (t) => t.toString() == json['reportType'],
        orElse: () => SafetyReportType.inappropriate,
      ),
      entityType: EntityType.values.firstWhere(
        (t) => t.toString() == json['entityType'],
        orElse: () => EntityType.vendor,
      ),
      reason: SafetyReportReason.values.firstWhere(
        (r) => r.toString() == json['reason'],
        orElse: () => SafetyReportReason.other,
      ),
      description: json['description'] ?? '',
      evidence: List<String>.from(json['evidence'] ?? []),
      status: SafetyReportStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => SafetyReportStatus.pending,
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (json['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: json['reviewedBy'],
      resolution: json['resolution'],
      actionTaken: json['actionTaken'] != null 
          ? SafetyAction.values.firstWhere(
              (a) => a.toString() == json['actionTaken'],
              orElse: () => SafetyAction.none,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reporterId': reporterId,
      'reportedEntityId': reportedEntityId,
      'reportType': reportType.toString(),
      'entityType': entityType.toString(),
      'reason': reason.toString(),
      'description': description,
      'evidence': evidence,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'resolution': resolution,
      'actionTaken': actionTaken?.toString(),
    };
  }
}

enum SafetyReportType {
  inappropriate,    // Inappropriate content
  scam,            // Suspected scam
  fake,            // Fake listing/profile
  spam,            // Spam content
  harassment,      // Harassment
  copyright,       // Copyright violation
  dangerous        // Dangerous product/service
}

enum SafetyReportReason {
  misleading,      // Misleading information
  offensive,       // Offensive content
  fraud,           // Fraudulent activity
  unsafe,          // Unsafe product/service
  stolen,          // Stolen goods
  counterfeit,     // Counterfeit products
  prohibited,      // Prohibited items
  other           // Other reason
}

enum SafetyReportStatus {
  pending,         // Awaiting review
  investigating,   // Under investigation
  resolved,        // Issue resolved
  dismissed,       // Report dismissed
  escalated        // Escalated to authorities
}

enum SafetyAction {
  none,            // No action taken
  warning,         // Warning issued
  contentRemoved,  // Content removed
  accountSuspended, // Account suspended
  accountBanned,   // Account permanently banned
  reported         // Reported to authorities
}

/// Verification system for vendors
class Verification {
  final String id;
  final String vendorId;
  final VerificationType type;
  final VerificationStatus status;
  final Map<String, dynamic> data; // Verification data
  final List<String> documents; // Document URLs
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final DateTime? expiresAt;
  final String? reviewedBy;
  final String? notes;
  final List<VerificationStep> steps;

  Verification({
    required this.id,
    required this.vendorId,
    required this.type,
    required this.status,
    required this.data,
    this.documents = const [],
    required this.submittedAt,
    this.reviewedAt,
    this.expiresAt,
    this.reviewedBy,
    this.notes,
    this.steps = const [],
  });

  factory Verification.fromJson(Map<String, dynamic> json, String id) {
    return Verification(
      id: id,
      vendorId: json['vendorId'] ?? '',
      type: VerificationType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => VerificationType.identity,
      ),
      status: VerificationStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => VerificationStatus.pending,
      ),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      documents: List<String>.from(json['documents'] ?? []),
      submittedAt: (json['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (json['reviewedAt'] as Timestamp?)?.toDate(),
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate(),
      reviewedBy: json['reviewedBy'],
      notes: json['notes'],
      steps: (json['steps'] as List<dynamic>?)
              ?.map((s) => VerificationStep.fromJson(s))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendorId': vendorId,
      'type': type.toString(),
      'status': status.toString(),
      'data': data,
      'documents': documents,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'reviewedBy': reviewedBy,
      'notes': notes,
      'steps': steps.map((s) => s.toJson()).toList(),
    };
  }

  bool get isActive => status == VerificationStatus.verified && 
                      (expiresAt == null || DateTime.now().isBefore(expiresAt!));
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

enum VerificationType {
  identity,        // Government ID verification
  business,        // Business registration
  address,         // Address verification
  phone,           // Phone number verification
  email,           // Email verification
  bank,            // Bank account verification
  tax,             // Tax ID verification
  professional     // Professional credentials
}

enum VerificationStatus {
  pending,         // Awaiting verification
  inReview,        // Under review
  verified,        // Successfully verified
  rejected,        // Verification rejected
  expired          // Verification expired
}

class VerificationStep {
  final String name;
  final String description;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? notes;

  VerificationStep({
    required this.name,
    required this.description,
    this.isCompleted = false,
    this.completedAt,
    this.notes,
  });

  factory VerificationStep.fromJson(Map<String, dynamic> json) {
    return VerificationStep(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
      completedAt: (json['completedAt'] as Timestamp?)?.toDate(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notes': notes,
    };
  }
}

// Use Flutter's Color class from material.dart
