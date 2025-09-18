import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

/// Comprehensive vendor verification and trust system
class VendorVerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit vendor verification application
  static Future<String> submitVerificationApplication({
    required String vendorId,
    required VerificationApplication application,
  }) async {
    try {
      final applicationData = {
        'vendorId': vendorId,
        'businessName': application.businessName,
        'businessType': application.businessType.toString(),
        'businessRegistrationNumber': application.businessRegistrationNumber,
        'taxNumber': application.taxNumber,
        'businessAddress': application.businessAddress.toJson(),
        'contactInfo': application.contactInfo.toJson(),
        'businessDocuments': application.businessDocuments,
        'identityDocuments': application.identityDocuments,
        'bankDetails': application.bankDetails?.toJson(),
        'businessDescription': application.businessDescription,
        'yearsInBusiness': application.yearsInBusiness,
        'expectedMonthlyVolume': application.expectedMonthlyVolume,
        'productCategories': application.productCategories,
        'website': application.website,
        'socialMediaLinks': application.socialMediaLinks,
        'references': application.references.map((ref) => ref.toJson()).toList(),
        'status': VerificationStatus.pending.toString(),
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('vendor_verifications')
          .add(applicationData);

      // Update vendor profile with verification status
      await _firestore
          .collection('vendor_profiles')
          .doc(vendorId)
          .update({
        'verificationStatus': VerificationStatus.pending.toString(),
        'verificationApplicationId': docRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to admin
      await _notifyAdminOfNewApplication(docRef.id, application.businessName);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to submit verification application: $e');
    }
  }

  /// Process verification application (Admin action)
  static Future<void> processVerificationApplication({
    required String applicationId,
    required VerificationDecision decision,
    required String adminId,
    String? notes,
  }) async {
    try {
      final applicationDoc = await _firestore
          .collection('vendor_verifications')
          .doc(applicationId)
          .get();

      if (!applicationDoc.exists) {
        throw Exception('Verification application not found');
      }

      final applicationData = applicationDoc.data()!;
      final vendorId = applicationData['vendorId'];
      final businessName = applicationData['businessName'];

      // Update application status
      await _firestore
          .collection('vendor_verifications')
          .doc(applicationId)
          .update({
        'status': decision.status.toString(),
        'decision': {
          'adminId': adminId,
          'status': decision.status.toString(),
          'notes': decision.notes,
          'reviewedAt': FieldValue.serverTimestamp(),
          'verificationLevel': decision.verificationLevel?.toString(),
          'expiryDate': decision.expiryDate != null 
              ? Timestamp.fromDate(decision.expiryDate!)
              : null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update vendor profile
      final vendorUpdate = {
        'verificationStatus': decision.status.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (decision.status == VerificationStatus.approved) {
        vendorUpdate['verificationLevel'] = decision.verificationLevel.toString();
        vendorUpdate['verificationDate'] = FieldValue.serverTimestamp();
        if (decision.expiryDate != null) {
          vendorUpdate['verificationExpiryDate'] = Timestamp.fromDate(decision.expiryDate!);
        }
        
        // Calculate initial trust score
        final trustScore = await _calculateInitialTrustScore(vendorId);
        vendorUpdate['trustScore'] = trustScore.toJson();
      }

      await _firestore
          .collection('vendor_profiles')
          .doc(vendorId)
          .update(vendorUpdate);

      // Send notification to vendor
      await NotificationService.sendVendorVerificationNotification(
        vendorId: vendorId,
        isApproved: decision.status == VerificationStatus.approved,
        reason: decision.notes,
      );

      // If approved, grant additional privileges
      if (decision.status == VerificationStatus.approved) {
        await _grantVerifiedVendorPrivileges(vendorId);
      }

    } catch (e) {
      throw Exception('Failed to process verification application: $e');
    }
  }

  /// Calculate initial trust score for newly verified vendor
  static Future<TrustScore> _calculateInitialTrustScore(String vendorId) async {
    try {
      final vendorDoc = await _firestore
          .collection('vendor_profiles')
          .doc(vendorId)
          .get();

      if (!vendorDoc.exists) {
        throw Exception('Vendor profile not found');
      }

      final vendorData = vendorDoc.data()!;
      double score = 50.0; // Base score for verification

      // Business registration bonus
      if (vendorData['businessRegistrationNumber'] != null) {
        score += 10.0;
      }

      // Tax number bonus
      if (vendorData['taxNumber'] != null) {
        score += 10.0;
      }

      // Years in business bonus
      final yearsInBusiness = vendorData['yearsInBusiness'] ?? 0;
      score += (yearsInBusiness * 2.0).clamp(0.0, 20.0);

      // Website bonus
      if (vendorData['website'] != null && vendorData['website'].isNotEmpty) {
        score += 5.0;
      }

      // Social media presence
      final socialLinks = vendorData['socialMediaLinks'] as List? ?? [];
      score += (socialLinks.length * 2.0).clamp(0.0, 10.0);

      // References bonus
      final references = vendorData['references'] as List? ?? [];
      score += (references.length * 5.0).clamp(0.0, 15.0);

      return TrustScore(
        score: score.clamp(0.0, 100.0),
        lastCalculated: DateTime.now(),
        factors: {
          'verification': 50.0,
          'businessRegistration': vendorData['businessRegistrationNumber'] != null ? 10.0 : 0.0,
          'taxCompliance': vendorData['taxNumber'] != null ? 10.0 : 0.0,
          'experience': (yearsInBusiness * 2.0).clamp(0.0, 20.0),
          'onlinePresence': vendorData['website'] != null ? 5.0 : 0.0,
          'socialMedia': (socialLinks.length * 2.0).clamp(0.0, 10.0),
          'references': (references.length * 5.0).clamp(0.0, 15.0),
        },
        level: _getTrustLevel(score),
      );
    } catch (e) {
      // Return default trust score on error
      return TrustScore(
        score: 50.0,
        lastCalculated: DateTime.now(),
        factors: {'verification': 50.0},
        level: TrustLevel.bronze,
      );
    }
  }

  /// Update trust score based on vendor performance
  static Future<void> updateTrustScore({
    required String vendorId,
    required TrustScoreUpdate update,
  }) async {
    try {
      final vendorDoc = await _firestore
          .collection('vendor_profiles')
          .doc(vendorId)
          .get();

      if (!vendorDoc.exists) return;

      final vendorData = vendorDoc.data()!;
      final currentTrustScore = vendorData['trustScore'] as Map<String, dynamic>? ?? {};
      
      double currentScore = (currentTrustScore['score'] ?? 50.0).toDouble();
      Map<String, dynamic> factors = Map<String, dynamic>.from(
        currentTrustScore['factors'] ?? {}
      );

      // Apply update
      switch (update.type) {
        case TrustScoreUpdateType.orderCompleted:
          factors['orderCompletion'] = (factors['orderCompletion'] ?? 0.0) + 0.5;
          break;
        case TrustScoreUpdateType.positiveReview:
          factors['reviews'] = (factors['reviews'] ?? 0.0) + 1.0;
          break;
        case TrustScoreUpdateType.negativeReview:
          factors['reviews'] = (factors['reviews'] ?? 0.0) - 2.0;
          break;
        case TrustScoreUpdateType.disputeResolved:
          factors['disputes'] = (factors['disputes'] ?? 0.0) + 2.0;
          break;
        case TrustScoreUpdateType.disputeLost:
          factors['disputes'] = (factors['disputes'] ?? 0.0) - 5.0;
          break;
        case TrustScoreUpdateType.policyViolation:
          factors['compliance'] = (factors['compliance'] ?? 0.0) - 10.0;
          break;
        case TrustScoreUpdateType.responseTime:
          factors['responsiveness'] = (factors['responsiveness'] ?? 0.0) + 0.2;
          break;
      }

      // Recalculate total score
      final newScore = factors.values
          .cast<double>()
          .reduce((a, b) => a + b)
          .clamp(0.0, 100.0);

      final updatedTrustScore = TrustScore(
        score: newScore,
        lastCalculated: DateTime.now(),
        factors: factors,
        level: _getTrustLevel(newScore),
      );

      await _firestore
          .collection('vendor_profiles')
          .doc(vendorId)
          .update({
        'trustScore': updatedTrustScore.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Record trust score history
      await _firestore
          .collection('trust_score_history')
          .add({
        'vendorId': vendorId,
        'previousScore': currentScore,
        'newScore': newScore,
        'updateType': update.type.toString(),
        'reason': update.reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
    }
  }

  /// Get trust level based on score
  static TrustLevel _getTrustLevel(double score) {
    if (score >= 90) return TrustLevel.platinum;
    if (score >= 80) return TrustLevel.gold;
    if (score >= 70) return TrustLevel.silver;
    if (score >= 60) return TrustLevel.bronze;
    return TrustLevel.basic;
  }

  /// Grant privileges to verified vendors
  static Future<void> _grantVerifiedVendorPrivileges(String vendorId) async {
    try {
      await _firestore
          .collection('vendor_profiles')
          .doc(vendorId)
          .update({
        'privileges': {
          'canPromoteListings': true,
          'canUseAdvancedAnalytics': true,
          'prioritySupport': true,
          'canCreateBundles': true,
          'higherListingLimit': 500,
          'canUseCustomBranding': true,
          'earlyAccessFeatures': true,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    }
  }

  /// Notify admin of new verification application
  static Future<void> _notifyAdminOfNewApplication(
    String applicationId,
    String businessName,
  ) async {
    try {
      // Get all admin users
      final adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminQuery.docs) {
        await NotificationService.createNotification(
          userId: adminDoc.id,
          type: NotificationType.system,
          title: '📋 New Vendor Verification Application',
          message: '$businessName has submitted a verification application for review.',
          data: {
            'applicationId': applicationId,
            'businessName': businessName,
            'type': 'vendor_verification',
          },
        );
      }
    } catch (e) {
    }
  }

  /// Get vendor verification status
  static Future<VendorVerificationInfo?> getVendorVerificationInfo(
    String vendorId,
  ) async {
    try {
      final vendorDoc = await _firestore
          .collection('vendor_profiles')
          .doc(vendorId)
          .get();

      if (!vendorDoc.exists) return null;

      final vendorData = vendorDoc.data()!;
      
      final verificationStatus = VerificationStatus.values.firstWhere(
        (status) => status.toString() == vendorData['verificationStatus'],
        orElse: () => VerificationStatus.unverified,
      );

      final verificationLevel = vendorData['verificationLevel'] != null
          ? VerificationLevel.values.firstWhere(
              (level) => level.toString() == vendorData['verificationLevel'],
              orElse: () => VerificationLevel.basic,
            )
          : null;

      final trustScoreData = vendorData['trustScore'] as Map<String, dynamic>?;
      final trustScore = trustScoreData != null
          ? TrustScore.fromJson(trustScoreData)
          : null;

      return VendorVerificationInfo(
        vendorId: vendorId,
        status: verificationStatus,
        level: verificationLevel,
        verificationDate: vendorData['verificationDate'] != null
            ? (vendorData['verificationDate'] as Timestamp).toDate()
            : null,
        expiryDate: vendorData['verificationExpiryDate'] != null
            ? (vendorData['verificationExpiryDate'] as Timestamp).toDate()
            : null,
        trustScore: trustScore,
        applicationId: vendorData['verificationApplicationId'],
      );
    } catch (e) {
      return null;
    }
  }

  /// Get verification applications for admin review
  static Stream<List<VerificationApplicationSummary>> getVerificationApplications({
    VerificationStatus? statusFilter,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('vendor_verifications')
        .orderBy('submittedAt', descending: true)
        .limit(limit);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.toString());
    }

    return query.snapshots().map((snapshot) => 
        snapshot.docs.map((doc) => 
            VerificationApplicationSummary.fromFirestore(doc)
        ).toList()
    );
  }

  /// Check if vendor verification is expired
  static Future<bool> isVerificationExpired(String vendorId) async {
    try {
      final info = await getVendorVerificationInfo(vendorId);
      if (info?.expiryDate == null) return false;
      
      return DateTime.now().isAfter(info!.expiryDate!);
    } catch (e) {
      return false;
    }
  }

  /// Renew vendor verification
  static Future<void> renewVerification(String vendorId) async {
    try {
      final newExpiryDate = DateTime.now().add(const Duration(days: 365));
      
      await _firestore
          .collection('vendor_profiles')
          .doc(vendorId)
          .update({
        'verificationExpiryDate': Timestamp.fromDate(newExpiryDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.createNotification(
        userId: vendorId,
        type: NotificationType.verification,
        title: '✅ Verification Renewed',
        message: 'Your vendor verification has been renewed until ${newExpiryDate.year}.',
        data: {
          'newExpiryDate': newExpiryDate.toIso8601String(),
        },
      );
    } catch (e) {
      throw Exception('Failed to renew verification: $e');
    }
  }
}

/// Verification status enum
enum VerificationStatus {
  unverified,
  pending,
  approved,
  rejected,
  expired,
  suspended,
}

/// Verification level enum
enum VerificationLevel {
  basic,
  standard,
  premium,
  enterprise,
}

/// Business type enum
enum BusinessType {
  individual,
  soleProprietorship,
  partnership,
  corporation,
  llc,
  nonprofit,
  other,
}

/// Trust level enum
enum TrustLevel {
  basic,
  bronze,
  silver,
  gold,
  platinum,
}

/// Trust score update type enum
enum TrustScoreUpdateType {
  orderCompleted,
  positiveReview,
  negativeReview,
  disputeResolved,
  disputeLost,
  policyViolation,
  responseTime,
}

/// Verification application model
class VerificationApplication {
  final String businessName;
  final BusinessType businessType;
  final String? businessRegistrationNumber;
  final String? taxNumber;
  final BusinessAddress businessAddress;
  final ContactInfo contactInfo;
  final List<String> businessDocuments;
  final List<String> identityDocuments;
  final BankDetails? bankDetails;
  final String businessDescription;
  final int yearsInBusiness;
  final double expectedMonthlyVolume;
  final List<String> productCategories;
  final String? website;
  final Map<String, String> socialMediaLinks;
  final List<BusinessReference> references;

  VerificationApplication({
    required this.businessName,
    required this.businessType,
    this.businessRegistrationNumber,
    this.taxNumber,
    required this.businessAddress,
    required this.contactInfo,
    this.businessDocuments = const [],
    this.identityDocuments = const [],
    this.bankDetails,
    required this.businessDescription,
    required this.yearsInBusiness,
    required this.expectedMonthlyVolume,
    this.productCategories = const [],
    this.website,
    this.socialMediaLinks = const {},
    this.references = const [],
  });
}

/// Business address model
class BusinessAddress {
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  BusinessAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  Map<String, dynamic> toJson() => {
    'street': street,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'country': country,
  };
}

/// Contact info model
class ContactInfo {
  final String fullName;
  final String email;
  final String phone;
  final String? alternatePhone;

  ContactInfo({
    required this.fullName,
    required this.email,
    required this.phone,
    this.alternatePhone,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'alternatePhone': alternatePhone,
  };
}

/// Bank details model
class BankDetails {
  final String bankName;
  final String accountNumber;
  final String routingNumber;
  final String accountHolderName;

  BankDetails({
    required this.bankName,
    required this.accountNumber,
    required this.routingNumber,
    required this.accountHolderName,
  });

  Map<String, dynamic> toJson() => {
    'bankName': bankName,
    'accountNumber': accountNumber,
    'routingNumber': routingNumber,
    'accountHolderName': accountHolderName,
  };
}

/// Business reference model
class BusinessReference {
  final String name;
  final String company;
  final String email;
  final String phone;
  final String relationship;

  BusinessReference({
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.relationship,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'company': company,
    'email': email,
    'phone': phone,
    'relationship': relationship,
  };
}

/// Verification decision model
class VerificationDecision {
  final VerificationStatus status;
  final String? notes;
  final VerificationLevel? verificationLevel;
  final DateTime? expiryDate;

  VerificationDecision({
    required this.status,
    this.notes,
    this.verificationLevel,
    this.expiryDate,
  });
}

/// Trust score model
class TrustScore {
  final double score;
  final DateTime lastCalculated;
  final Map<String, dynamic> factors;
  final TrustLevel level;

  TrustScore({
    required this.score,
    required this.lastCalculated,
    required this.factors,
    required this.level,
  });

  Map<String, dynamic> toJson() => {
    'score': score,
    'lastCalculated': Timestamp.fromDate(lastCalculated),
    'factors': factors,
    'level': level.toString(),
  };

  factory TrustScore.fromJson(Map<String, dynamic> json) => TrustScore(
    score: (json['score'] ?? 0.0).toDouble(),
    lastCalculated: (json['lastCalculated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    factors: Map<String, dynamic>.from(json['factors'] ?? {}),
    level: TrustLevel.values.firstWhere(
      (level) => level.toString() == json['level'],
      orElse: () => TrustLevel.basic,
    ),
  );
}

/// Trust score update model
class TrustScoreUpdate {
  final TrustScoreUpdateType type;
  final String? reason;

  TrustScoreUpdate({
    required this.type,
    this.reason,
  });
}

/// Vendor verification info model
class VendorVerificationInfo {
  final String vendorId;
  final VerificationStatus status;
  final VerificationLevel? level;
  final DateTime? verificationDate;
  final DateTime? expiryDate;
  final TrustScore? trustScore;
  final String? applicationId;

  VendorVerificationInfo({
    required this.vendorId,
    required this.status,
    this.level,
    this.verificationDate,
    this.expiryDate,
    this.trustScore,
    this.applicationId,
  });
}

/// Verification application summary model
class VerificationApplicationSummary {
  final String id;
  final String vendorId;
  final String businessName;
  final BusinessType businessType;
  final VerificationStatus status;
  final DateTime submittedAt;

  VerificationApplicationSummary({
    required this.id,
    required this.vendorId,
    required this.businessName,
    required this.businessType,
    required this.status,
    required this.submittedAt,
  });

  factory VerificationApplicationSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VerificationApplicationSummary(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      businessName: data['businessName'] ?? '',
      businessType: BusinessType.values.firstWhere(
        (type) => type.toString() == data['businessType'],
        orElse: () => BusinessType.individual,
      ),
      status: VerificationStatus.values.firstWhere(
        (status) => status.toString() == data['status'],
        orElse: () => VerificationStatus.pending,
      ),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
