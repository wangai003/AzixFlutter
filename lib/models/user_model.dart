import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String role; // 'user', 'admin', 'super_admin'
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final bool isEmailVerified;
  final Map<String, dynamic>? preferences;
  final String? stellarPublicKey;
  final bool hasWallet;
  final List<String>? notificationSettings;
  final Map<String, dynamic>? profile;
  final String? referralCode;
  final String? referredBy;
  final List<String>? referrals;
  final int? referralCount;
  final String akofaTag;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.role = 'user',
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.isEmailVerified = false,
    this.preferences,
    this.stellarPublicKey,
    this.hasWallet = false,
    this.notificationSettings,
    this.profile,
    this.referralCode,
    this.referredBy,
    this.referrals,
    this.referralCount,
    required this.akofaTag,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'user',
      createdAt: parseDate(map['createdAt']),
      lastLoginAt: map['lastLoginAt'] != null
          ? parseDate(map['lastLoginAt'])
          : null,
      isActive: map['isActive'] ?? true,
      isEmailVerified: map['isEmailVerified'] ?? false,
      preferences: map['preferences'],
      stellarPublicKey: map['stellarPublicKey'],
      hasWallet: map['hasWallet'] ?? false,
      notificationSettings: map['notificationSettings'] != null
          ? List<String>.from(map['notificationSettings'])
          : null,
      profile: map['profile'],
      referralCode: map['referralCode'],
      referredBy: map['referredBy'],
      referrals: map['referrals'] != null
          ? List<String>.from(map['referrals'])
          : null,
      referralCount: map['referralCount'],
      akofaTag: map['akofaTag'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'isEmailVerified': isEmailVerified,
      'preferences': preferences,
      'stellarPublicKey': stellarPublicKey,
      'hasWallet': hasWallet,
      'notificationSettings': notificationSettings,
      'profile': profile,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'referrals': referrals,
      'referralCount': referralCount,
      'akofaTag': akofaTag,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? role,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    bool? isEmailVerified,
    Map<String, dynamic>? preferences,
    String? stellarPublicKey,
    bool? hasWallet,
    List<String>? notificationSettings,
    Map<String, dynamic>? profile,
    String? referralCode,
    String? referredBy,
    List<String>? referrals,
    int? referralCount,
    String? akofaTag,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      preferences: preferences ?? this.preferences,
      stellarPublicKey: stellarPublicKey ?? this.stellarPublicKey,
      hasWallet: hasWallet ?? this.hasWallet,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      profile: profile ?? this.profile,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      referrals: referrals ?? this.referrals,
      referralCount: referralCount ?? this.referralCount,
      akofaTag: akofaTag ?? this.akofaTag,
    );
  }

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';
}
