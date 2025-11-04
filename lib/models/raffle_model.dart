import 'package:cloud_firestore/cloud_firestore.dart';

/// Raffle status enumeration
enum RaffleStatus { draft, upcoming, active, paused, completed, cancelled }

/// Raffle entry requirements
enum EntryRequirement { free, purchase, referral, socialShare, walletBalance }

/// Prize claim status
enum PrizeClaimStatus { unclaimed, claimed, expired, disputed }

/// Raffle metadata model
class RaffleModel {
  final String id;
  final String title;
  final String description;
  final String? detailedDescription; // IPFS hash for extended content
  final String creatorId;
  final String creatorName;
  final String? imageUrl; // Main raffle image
  final List<String>? galleryImages; // Additional images (IPFS hashes)
  final Map<String, dynamic> entryRequirements;
  final Map<String, dynamic> prizeDetails;
  final int maxEntries;
  final int currentEntries;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? drawDate;
  final RaffleStatus status;
  final bool isPublic;
  final List<String>? allowedUserIds; // For private raffles
  final Map<String, dynamic>? metadata; // Additional custom fields
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ipfsHash; // IPFS hash for entire raffle metadata

  RaffleModel({
    required this.id,
    required this.title,
    required this.description,
    this.detailedDescription,
    required this.creatorId,
    required this.creatorName,
    this.imageUrl,
    this.galleryImages,
    required this.entryRequirements,
    required this.prizeDetails,
    required this.maxEntries,
    this.currentEntries = 0,
    required this.startDate,
    required this.endDate,
    this.drawDate,
    this.status = RaffleStatus.draft,
    this.isPublic = true,
    this.allowedUserIds,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.ipfsHash,
  });

  factory RaffleModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return RaffleModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      detailedDescription: map['detailedDescription'],
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? '',
      imageUrl: map['imageUrl'],
      galleryImages: map['galleryImages'] != null
          ? List<String>.from(map['galleryImages'])
          : null,
      entryRequirements: Map<String, dynamic>.from(
        map['entryRequirements'] ?? {},
      ),
      prizeDetails: Map<String, dynamic>.from(map['prizeDetails'] ?? {}),
      maxEntries: map['maxEntries'] ?? 0,
      currentEntries: map['currentEntries'] ?? 0,
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      drawDate: map['drawDate'] != null ? parseDate(map['drawDate']) : null,
      status: RaffleStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => RaffleStatus.draft,
      ),
      isPublic: map['isPublic'] ?? true,
      allowedUserIds: map['allowedUserIds'] != null
          ? List<String>.from(map['allowedUserIds'])
          : null,
      metadata: map['metadata'],
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      ipfsHash: map['ipfsHash'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'detailedDescription': detailedDescription,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'imageUrl': imageUrl,
      'galleryImages': galleryImages,
      'entryRequirements': entryRequirements,
      'prizeDetails': prizeDetails,
      'maxEntries': maxEntries,
      'currentEntries': currentEntries,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'drawDate': drawDate != null ? Timestamp.fromDate(drawDate!) : null,
      'status': status.toString(),
      'isPublic': isPublic,
      'allowedUserIds': allowedUserIds,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'ipfsHash': ipfsHash,
    };
  }

  RaffleModel copyWith({
    String? id,
    String? title,
    String? description,
    String? detailedDescription,
    String? creatorId,
    String? creatorName,
    String? imageUrl,
    List<String>? galleryImages,
    Map<String, dynamic>? entryRequirements,
    Map<String, dynamic>? prizeDetails,
    int? maxEntries,
    int? currentEntries,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? drawDate,
    RaffleStatus? status,
    bool? isPublic,
    List<String>? allowedUserIds,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ipfsHash,
  }) {
    return RaffleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      detailedDescription: detailedDescription ?? this.detailedDescription,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      imageUrl: imageUrl ?? this.imageUrl,
      galleryImages: galleryImages ?? this.galleryImages,
      entryRequirements: entryRequirements ?? this.entryRequirements,
      prizeDetails: prizeDetails ?? this.prizeDetails,
      maxEntries: maxEntries ?? this.maxEntries,
      currentEntries: currentEntries ?? this.currentEntries,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      drawDate: drawDate ?? this.drawDate,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
      allowedUserIds: allowedUserIds ?? this.allowedUserIds,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ipfsHash: ipfsHash ?? this.ipfsHash,
    );
  }

  bool get isActive =>
      status == RaffleStatus.active &&
      DateTime.now().isAfter(startDate) &&
      DateTime.now().isBefore(endDate);

  bool get isExpired => DateTime.now().isAfter(endDate);

  bool get canEnter => isActive && currentEntries < maxEntries;

  int get entriesRemaining => maxEntries - currentEntries;
}

/// Participant entry model
class RaffleEntryModel {
  final String id;
  final String raffleId;
  final String userId;
  final String userName;
  final String? userEmail;
  final DateTime entryDate;
  final Map<String, dynamic> verificationData; // Entry verification proof
  final String? referralCode; // If entered via referral
  final String? transactionId; // If entry required purchase
  final bool isValid;
  final String? invalidReason;
  final DateTime? verifiedAt;
  final Map<String, dynamic>? metadata;

  RaffleEntryModel({
    required this.id,
    required this.raffleId,
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.entryDate,
    required this.verificationData,
    this.referralCode,
    this.transactionId,
    this.isValid = true,
    this.invalidReason,
    this.verifiedAt,
    this.metadata,
  });

  factory RaffleEntryModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return RaffleEntryModel(
      id: id,
      raffleId: map['raffleId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'],
      entryDate: parseDate(map['entryDate']),
      verificationData: Map<String, dynamic>.from(
        map['verificationData'] ?? {},
      ),
      referralCode: map['referralCode'],
      transactionId: map['transactionId'],
      isValid: map['isValid'] ?? true,
      invalidReason: map['invalidReason'],
      verifiedAt: map['verifiedAt'] != null
          ? parseDate(map['verifiedAt'])
          : null,
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'raffleId': raffleId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'entryDate': Timestamp.fromDate(entryDate),
      'verificationData': verificationData,
      'referralCode': referralCode,
      'transactionId': transactionId,
      'isValid': isValid,
      'invalidReason': invalidReason,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'metadata': metadata,
    };
  }
}

/// Winner results model
class RaffleWinnerModel {
  final String id;
  final String raffleId;
  final String entryId;
  final String winnerUserId;
  final String winnerName;
  final String winnerEmail;
  final int winnerPosition; // 1st, 2nd, 3rd place, etc.
  final Map<String, dynamic> prizeDetails;
  final DateTime drawDate;
  final String drawMethod; // 'random', 'manual', 'algorithm'
  final Map<String, dynamic>? drawProof; // Cryptographic proof of fairness
  final PrizeClaimStatus claimStatus;
  final DateTime? claimedAt;
  final String? claimTransactionId;
  final DateTime? claimExpiryDate;
  final Map<String, dynamic>? metadata;

  RaffleWinnerModel({
    required this.id,
    required this.raffleId,
    required this.entryId,
    required this.winnerUserId,
    required this.winnerName,
    required this.winnerEmail,
    required this.winnerPosition,
    required this.prizeDetails,
    required this.drawDate,
    required this.drawMethod,
    this.drawProof,
    this.claimStatus = PrizeClaimStatus.unclaimed,
    this.claimedAt,
    this.claimTransactionId,
    this.claimExpiryDate,
    this.metadata,
  });

  factory RaffleWinnerModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return RaffleWinnerModel(
      id: id,
      raffleId: map['raffleId'] ?? '',
      entryId: map['entryId'] ?? '',
      winnerUserId: map['winnerUserId'] ?? '',
      winnerName: map['winnerName'] ?? '',
      winnerEmail: map['winnerEmail'] ?? '',
      winnerPosition: map['winnerPosition'] ?? 1,
      prizeDetails: Map<String, dynamic>.from(map['prizeDetails'] ?? {}),
      drawDate: parseDate(map['drawDate']),
      drawMethod: map['drawMethod'] ?? 'random',
      drawProof: map['drawProof'],
      claimStatus: PrizeClaimStatus.values.firstWhere(
        (e) => e.toString() == map['claimStatus'],
        orElse: () => PrizeClaimStatus.unclaimed,
      ),
      claimedAt: map['claimedAt'] != null ? parseDate(map['claimedAt']) : null,
      claimTransactionId: map['claimTransactionId'],
      claimExpiryDate: map['claimExpiryDate'] != null
          ? parseDate(map['claimExpiryDate'])
          : null,
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'raffleId': raffleId,
      'entryId': entryId,
      'winnerUserId': winnerUserId,
      'winnerName': winnerName,
      'winnerEmail': winnerEmail,
      'winnerPosition': winnerPosition,
      'prizeDetails': prizeDetails,
      'drawDate': Timestamp.fromDate(drawDate),
      'drawMethod': drawMethod,
      'drawProof': drawProof,
      'claimStatus': claimStatus.toString(),
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'claimTransactionId': claimTransactionId,
      'claimExpiryDate': claimExpiryDate != null
          ? Timestamp.fromDate(claimExpiryDate!)
          : null,
      'metadata': metadata,
    };
  }

  bool get isClaimed => claimStatus == PrizeClaimStatus.claimed;
  bool get isExpired =>
      claimExpiryDate != null && DateTime.now().isAfter(claimExpiryDate!);
  bool get canClaim => claimStatus == PrizeClaimStatus.unclaimed && !isExpired;
}
