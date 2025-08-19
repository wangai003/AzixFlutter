import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'review_system.dart';

/// Comprehensive vendor profile system
class VendorProfile {
  final String id;
  final String userId; // Associated user account
  final VendorType type;
  final VendorStatus status;
  final BusinessInfo businessInfo;
  final ContactInfo contactInfo;
  final List<VendorCategory> categories;
  final String description;
  final String story; // Vendor story/background
  final List<String> images; // Profile images
  final String? logoUrl;
  final String? bannerUrl;
  final SocialMedia socialMedia;
  final OperatingHours operatingHours;
  final List<ServiceArea> serviceAreas;
  final VendorPolicies policies;
  final VendorAnalytics analytics;
  final List<VendorAchievement> achievements;
  final List<Verification> verifications;
  final TrustScore? trustScore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastActiveAt;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> metadata;

  VendorProfile({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.businessInfo,
    required this.contactInfo,
    required this.categories,
    required this.description,
    required this.story,
    this.images = const [],
    this.logoUrl,
    this.bannerUrl,
    required this.socialMedia,
    required this.operatingHours,
    required this.serviceAreas,
    required this.policies,
    required this.analytics,
    this.achievements = const [],
    this.verifications = const [],
    this.trustScore,
    required this.createdAt,
    required this.updatedAt,
    this.lastActiveAt,
    this.settings = const {},
    this.metadata = const {},
  });

  factory VendorProfile.fromJson(Map<String, dynamic> json, String id) {
    return VendorProfile(
      id: id,
      userId: json['userId'] ?? '',
      type: VendorType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => VendorType.individual,
      ),
      status: VendorStatus.values.firstWhere(
        (s) => s.toString() == json['status'],
        orElse: () => VendorStatus.pending,
      ),
      businessInfo: BusinessInfo.fromJson(json['businessInfo'] ?? {}),
      contactInfo: ContactInfo.fromJson(json['contactInfo'] ?? {}),
      categories: (json['categories'] as List<dynamic>?)
              ?.map((c) => VendorCategory.fromJson(c))
              .toList() ??
          [],
      description: json['description'] ?? '',
      story: json['story'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      logoUrl: json['logoUrl'],
      bannerUrl: json['bannerUrl'],
      socialMedia: SocialMedia.fromJson(json['socialMedia'] ?? {}),
      operatingHours: OperatingHours.fromJson(json['operatingHours'] ?? {}),
      serviceAreas: (json['serviceAreas'] as List<dynamic>?)
              ?.map((s) => ServiceArea.fromJson(s))
              .toList() ??
          [],
      policies: VendorPolicies.fromJson(json['policies'] ?? {}),
      analytics: VendorAnalytics.fromJson(json['analytics'] ?? {}),
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((a) => VendorAchievement.fromJson(a))
              .toList() ??
          [],
      verifications: (json['verifications'] as List<dynamic>?)
              ?.map((v) => Verification.fromJson(v, v['id'] ?? ''))
              .toList() ??
          [],
      trustScore: json['trustScore'] != null 
          ? TrustScore.fromJson(json['trustScore'], id)
          : null,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (json['lastActiveAt'] as Timestamp?)?.toDate(),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type.toString(),
      'status': status.toString(),
      'businessInfo': businessInfo.toJson(),
      'contactInfo': contactInfo.toJson(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'description': description,
      'story': story,
      'images': images,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'socialMedia': socialMedia.toJson(),
      'operatingHours': operatingHours.toJson(),
      'serviceAreas': serviceAreas.map((s) => s.toJson()).toList(),
      'policies': policies.toJson(),
      'analytics': analytics.toJson(),
      'achievements': achievements.map((a) => a.toJson()).toList(),
      'verifications': verifications.map((v) => v.toJson()).toList(),
      'trustScore': trustScore?.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'settings': settings,
      'metadata': metadata,
    };
  }

  bool get isActive => status == VendorStatus.active;
  bool get isVerified => verifications.any((v) => v.isActive);
  bool get isOnline => lastActiveAt != null && 
                      DateTime.now().difference(lastActiveAt!).inMinutes < 30;
  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;
  bool get hasBanner => bannerUrl != null && bannerUrl!.isNotEmpty;
  
  String get displayName => businessInfo.businessName.isNotEmpty 
      ? businessInfo.businessName 
      : contactInfo.fullName;
      
  Duration? get membershipDuration => DateTime.now().difference(createdAt);
  
  List<Verification> get activeVerifications => 
      verifications.where((v) => v.isActive).toList();
}

enum VendorType {
  individual,   // Individual seller
  business,     // Registered business
  enterprise,   // Large enterprise
  freelancer,   // Freelance service provider
  agency        // Service agency
}

enum VendorStatus {
  pending,      // Registration pending approval
  active,       // Active vendor
  suspended,    // Temporarily suspended
  banned,       // Permanently banned
  deactivated   // Self-deactivated
}

extension VendorStatusExtension on VendorStatus {
  String get displayName {
    switch (this) {
      case VendorStatus.pending:
        return 'Pending Approval';
      case VendorStatus.active:
        return 'Active';
      case VendorStatus.suspended:
        return 'Suspended';
      case VendorStatus.banned:
        return 'Banned';
      case VendorStatus.deactivated:
        return 'Deactivated';
    }
  }

  Color get color {
    switch (this) {
      case VendorStatus.pending:
        return const Color(0xFFFF9800);
      case VendorStatus.active:
        return const Color(0xFF4CAF50);
      case VendorStatus.suspended:
        return const Color(0xFFF44336);
      case VendorStatus.banned:
        return const Color(0xFF000000);
      case VendorStatus.deactivated:
        return const Color(0xFF9E9E9E);
    }
  }
}

class BusinessInfo {
  final String businessName;
  final String? registrationNumber;
  final String? taxId;
  final BusinessType type;
  final String? industry;
  final DateTime? establishedDate;
  final String? website;
  final BusinessAddress? address;
  final List<String> licenses; // Business license URLs
  final List<String> certifications; // Certification URLs

  BusinessInfo({
    required this.businessName,
    this.registrationNumber,
    this.taxId,
    required this.type,
    this.industry,
    this.establishedDate,
    this.website,
    this.address,
    this.licenses = const [],
    this.certifications = const [],
  });

  factory BusinessInfo.fromJson(Map<String, dynamic> json) {
    return BusinessInfo(
      businessName: json['businessName'] ?? '',
      registrationNumber: json['registrationNumber'],
      taxId: json['taxId'],
      type: BusinessType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => BusinessType.individual,
      ),
      industry: json['industry'],
      establishedDate: (json['establishedDate'] as Timestamp?)?.toDate(),
      website: json['website'],
      address: json['address'] != null 
          ? BusinessAddress.fromJson(json['address'])
          : null,
      licenses: List<String>.from(json['licenses'] ?? []),
      certifications: List<String>.from(json['certifications'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'registrationNumber': registrationNumber,
      'taxId': taxId,
      'type': type.toString(),
      'industry': industry,
      'establishedDate': establishedDate != null ? Timestamp.fromDate(establishedDate!) : null,
      'website': website,
      'address': address?.toJson(),
      'licenses': licenses,
      'certifications': certifications,
    };
  }

  bool get hasBusinessRegistration => registrationNumber != null && registrationNumber!.isNotEmpty;
  bool get hasTaxId => taxId != null && taxId!.isNotEmpty;
  bool get hasWebsite => website != null && website!.isNotEmpty;
}

enum BusinessType {
  individual,       // Individual/sole proprietor
  partnership,      // Partnership
  corporation,      // Corporation
  llc,             // Limited Liability Company
  nonprofit,       // Non-profit organization
  government       // Government entity
}

class BusinessAddress {
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final double? latitude;
  final double? longitude;

  BusinessAddress({
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    this.latitude,
    this.longitude,
  });

  factory BusinessAddress.fromJson(Map<String, dynamic> json) {
    return BusinessAddress(
      addressLine1: json['addressLine1'] ?? '',
      addressLine2: json['addressLine2'],
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      postalCode: json['postalCode'] ?? '',
      country: json['country'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  String get formattedAddress {
    final parts = [
      addressLine1,
      if (addressLine2?.isNotEmpty == true) addressLine2!,
      '$city, $state $postalCode',
      country,
    ];
    return parts.join('\n');
  }
}

class ContactInfo {
  final String fullName;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String email;
  final String? alternateEmail;
  final PreferredContact preferredContact;
  final List<String> languages; // Spoken languages
  final String? timezone;

  ContactInfo({
    required this.fullName,
    this.phoneNumber,
    this.whatsappNumber,
    required this.email,
    this.alternateEmail,
    required this.preferredContact,
    this.languages = const [],
    this.timezone,
  });

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'],
      whatsappNumber: json['whatsappNumber'],
      email: json['email'] ?? '',
      alternateEmail: json['alternateEmail'],
      preferredContact: PreferredContact.values.firstWhere(
        (p) => p.toString() == json['preferredContact'],
        orElse: () => PreferredContact.platform,
      ),
      languages: List<String>.from(json['languages'] ?? []),
      timezone: json['timezone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'whatsappNumber': whatsappNumber,
      'email': email,
      'alternateEmail': alternateEmail,
      'preferredContact': preferredContact.toString(),
      'languages': languages,
      'timezone': timezone,
    };
  }

  bool get hasPhone => phoneNumber != null && phoneNumber!.isNotEmpty;
  bool get hasWhatsApp => whatsappNumber != null && whatsappNumber!.isNotEmpty;
}

enum PreferredContact {
  platform,     // Through platform messaging
  email,        // Email communication
  phone,        // Phone calls
  whatsapp      // WhatsApp
}

class VendorCategory {
  final String id;
  final String name;
  final String? subcategory;
  final bool isPrimary;
  final int experienceYears;
  final List<String> specializations;
  final String? description;

  VendorCategory({
    required this.id,
    required this.name,
    this.subcategory,
    this.isPrimary = false,
    this.experienceYears = 0,
    this.specializations = const [],
    this.description,
  });

  factory VendorCategory.fromJson(Map<String, dynamic> json) {
    return VendorCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      subcategory: json['subcategory'],
      isPrimary: json['isPrimary'] ?? false,
      experienceYears: json['experienceYears'] ?? 0,
      specializations: List<String>.from(json['specializations'] ?? []),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subcategory': subcategory,
      'isPrimary': isPrimary,
      'experienceYears': experienceYears,
      'specializations': specializations,
      'description': description,
    };
  }

  String get fullCategoryName {
    if (subcategory != null && subcategory!.isNotEmpty) {
      return '$name > $subcategory';
    }
    return name;
  }
}

class SocialMedia {
  final String? facebook;
  final String? instagram;
  final String? twitter;
  final String? linkedin;
  final String? youtube;
  final String? tiktok;
  final Map<String, String> other; // Platform -> URL

  SocialMedia({
    this.facebook,
    this.instagram,
    this.twitter,
    this.linkedin,
    this.youtube,
    this.tiktok,
    this.other = const {},
  });

  factory SocialMedia.fromJson(Map<String, dynamic> json) {
    return SocialMedia(
      facebook: json['facebook'],
      instagram: json['instagram'],
      twitter: json['twitter'],
      linkedin: json['linkedin'],
      youtube: json['youtube'],
      tiktok: json['tiktok'],
      other: Map<String, String>.from(json['other'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facebook': facebook,
      'instagram': instagram,
      'twitter': twitter,
      'linkedin': linkedin,
      'youtube': youtube,
      'tiktok': tiktok,
      'other': other,
    };
  }

  List<SocialLink> get allLinks {
    final links = <SocialLink>[];
    if (facebook?.isNotEmpty == true) links.add(SocialLink('Facebook', facebook!));
    if (instagram?.isNotEmpty == true) links.add(SocialLink('Instagram', instagram!));
    if (twitter?.isNotEmpty == true) links.add(SocialLink('Twitter', twitter!));
    if (linkedin?.isNotEmpty == true) links.add(SocialLink('LinkedIn', linkedin!));
    if (youtube?.isNotEmpty == true) links.add(SocialLink('YouTube', youtube!));
    if (tiktok?.isNotEmpty == true) links.add(SocialLink('TikTok', tiktok!));
    other.forEach((platform, url) {
      if (url.isNotEmpty) links.add(SocialLink(platform, url));
    });
    return links;
  }
}

class SocialLink {
  final String platform;
  final String url;

  SocialLink(this.platform, this.url);
}

class OperatingHours {
  final Map<String, DaySchedule> schedule; // Day of week -> schedule
  final String? timezone;
  final bool isAlwaysOpen;
  final bool isTemporarilyClosed;
  final String? closureReason;
  final DateTime? closureUntil;

  OperatingHours({
    required this.schedule,
    this.timezone,
    this.isAlwaysOpen = false,
    this.isTemporarilyClosed = false,
    this.closureReason,
    this.closureUntil,
  });

  factory OperatingHours.fromJson(Map<String, dynamic> json) {
    return OperatingHours(
      schedule: (json['schedule'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, DaySchedule.fromJson(v))
      ) ?? {},
      timezone: json['timezone'],
      isAlwaysOpen: json['isAlwaysOpen'] ?? false,
      isTemporarilyClosed: json['isTemporarilyClosed'] ?? false,
      closureReason: json['closureReason'],
      closureUntil: (json['closureUntil'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule': schedule.map((k, v) => MapEntry(k, v.toJson())),
      'timezone': timezone,
      'isAlwaysOpen': isAlwaysOpen,
      'isTemporarilyClosed': isTemporarilyClosed,
      'closureReason': closureReason,
      'closureUntil': closureUntil != null ? Timestamp.fromDate(closureUntil!) : null,
    };
  }

  bool isOpenNow() {
    if (isTemporarilyClosed) return false;
    if (isAlwaysOpen) return true;
    
    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);
    final todaySchedule = schedule[dayName];
    
    if (todaySchedule == null || !todaySchedule.isOpen) return false;
    
    final currentTime = now.hour * 60 + now.minute;
    return todaySchedule.isTimeInRange(currentTime);
  }

  String _getDayName(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[weekday - 1];
  }
}

class DaySchedule {
  final bool isOpen;
  final List<TimeSlot> timeSlots;

  DaySchedule({
    this.isOpen = false,
    this.timeSlots = const [],
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      isOpen: json['isOpen'] ?? false,
      timeSlots: (json['timeSlots'] as List<dynamic>?)
              ?.map((t) => TimeSlot.fromJson(t))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isOpen': isOpen,
      'timeSlots': timeSlots.map((t) => t.toJson()).toList(),
    };
  }

  bool isTimeInRange(int currentMinutes) {
    if (!isOpen) return false;
    return timeSlots.any((slot) => slot.contains(currentMinutes));
  }
}

class TimeSlot {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  TimeSlot({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startHour: json['startHour'] ?? 0,
      startMinute: json['startMinute'] ?? 0,
      endHour: json['endHour'] ?? 0,
      endMinute: json['endMinute'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  bool contains(int minutes) {
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    
    if (start <= end) {
      // Same day
      return minutes >= start && minutes <= end;
    } else {
      // Overnight
      return minutes >= start || minutes <= end;
    }
  }

  String get formattedTime {
    final startTime = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
    final endTime = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    return '$startTime - $endTime';
  }
}

class ServiceArea {
  final String id;
  final String name;
  final ServiceAreaType type;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final List<String> locations; // Specific locations served
  final double? additionalCost; // Extra cost for this area
  final String? notes;

  ServiceArea({
    required this.id,
    required this.name,
    required this.type,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.locations = const [],
    this.additionalCost,
    this.notes,
  });

  factory ServiceArea.fromJson(Map<String, dynamic> json) {
    return ServiceArea(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: ServiceAreaType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => ServiceAreaType.city,
      ),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusKm: (json['radiusKm'] as num?)?.toDouble(),
      locations: List<String>.from(json['locations'] ?? []),
      additionalCost: (json['additionalCost'] as num?)?.toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'locations': locations,
      'additionalCost': additionalCost,
      'notes': notes,
    };
  }
}

enum ServiceAreaType {
  city,         // Entire city
  region,       // Regional area
  radius,       // Radius around a point
  custom,       // Custom polygon area
  nationwide,   // Entire country
  worldwide     // Global service
}

class VendorPolicies {
  final String? returnPolicy;
  final String? shippingPolicy;
  final String? privacyPolicy;
  final String? termsOfService;
  final String? cancellationPolicy;
  final String? refundPolicy;
  final bool acceptsReturns;
  final int returnDays; // Days allowed for returns
  final bool offersWarranty;
  final int warrantyDays; // Warranty period in days
  final String? paymentTerms;

  VendorPolicies({
    this.returnPolicy,
    this.shippingPolicy,
    this.privacyPolicy,
    this.termsOfService,
    this.cancellationPolicy,
    this.refundPolicy,
    this.acceptsReturns = false,
    this.returnDays = 0,
    this.offersWarranty = false,
    this.warrantyDays = 0,
    this.paymentTerms,
  });

  factory VendorPolicies.fromJson(Map<String, dynamic> json) {
    return VendorPolicies(
      returnPolicy: json['returnPolicy'],
      shippingPolicy: json['shippingPolicy'],
      privacyPolicy: json['privacyPolicy'],
      termsOfService: json['termsOfService'],
      cancellationPolicy: json['cancellationPolicy'],
      refundPolicy: json['refundPolicy'],
      acceptsReturns: json['acceptsReturns'] ?? false,
      returnDays: json['returnDays'] ?? 0,
      offersWarranty: json['offersWarranty'] ?? false,
      warrantyDays: json['warrantyDays'] ?? 0,
      paymentTerms: json['paymentTerms'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'returnPolicy': returnPolicy,
      'shippingPolicy': shippingPolicy,
      'privacyPolicy': privacyPolicy,
      'termsOfService': termsOfService,
      'cancellationPolicy': cancellationPolicy,
      'refundPolicy': refundPolicy,
      'acceptsReturns': acceptsReturns,
      'returnDays': returnDays,
      'offersWarranty': offersWarranty,
      'warrantyDays': warrantyDays,
      'paymentTerms': paymentTerms,
    };
  }
}

class VendorAnalytics {
  final int totalListings;
  final int activeListings;
  final int totalOrders;
  final int completedOrders;
  final double totalRevenue;
  final double averageOrderValue;
  final double rating;
  final int reviewCount;
  final int profileViews;
  final int followers;
  final DateTime? firstSaleDate;
  final DateTime? lastSaleDate;
  final double responseRate; // Message response rate
  final double averageResponseTime; // In minutes
  final Map<String, int> topCategories; // Category -> order count
  final Map<String, double> monthlyRevenue; // Month -> revenue

  VendorAnalytics({
    this.totalListings = 0,
    this.activeListings = 0,
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.totalRevenue = 0.0,
    this.averageOrderValue = 0.0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.profileViews = 0,
    this.followers = 0,
    this.firstSaleDate,
    this.lastSaleDate,
    this.responseRate = 0.0,
    this.averageResponseTime = 0.0,
    this.topCategories = const {},
    this.monthlyRevenue = const {},
  });

  factory VendorAnalytics.fromJson(Map<String, dynamic> json) {
    return VendorAnalytics(
      totalListings: json['totalListings'] ?? 0,
      activeListings: json['activeListings'] ?? 0,
      totalOrders: json['totalOrders'] ?? 0,
      completedOrders: json['completedOrders'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0.0).toDouble(),
      averageOrderValue: (json['averageOrderValue'] ?? 0.0).toDouble(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      profileViews: json['profileViews'] ?? 0,
      followers: json['followers'] ?? 0,
      firstSaleDate: (json['firstSaleDate'] as Timestamp?)?.toDate(),
      lastSaleDate: (json['lastSaleDate'] as Timestamp?)?.toDate(),
      responseRate: (json['responseRate'] ?? 0.0).toDouble(),
      averageResponseTime: (json['averageResponseTime'] ?? 0.0).toDouble(),
      topCategories: Map<String, int>.from(json['topCategories'] ?? {}),
      monthlyRevenue: Map<String, double>.from(
        (json['monthlyRevenue'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble()))
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalListings': totalListings,
      'activeListings': activeListings,
      'totalOrders': totalOrders,
      'completedOrders': completedOrders,
      'totalRevenue': totalRevenue,
      'averageOrderValue': averageOrderValue,
      'rating': rating,
      'reviewCount': reviewCount,
      'profileViews': profileViews,
      'followers': followers,
      'firstSaleDate': firstSaleDate != null ? Timestamp.fromDate(firstSaleDate!) : null,
      'lastSaleDate': lastSaleDate != null ? Timestamp.fromDate(lastSaleDate!) : null,
      'responseRate': responseRate,
      'averageResponseTime': averageResponseTime,
      'topCategories': topCategories,
      'monthlyRevenue': monthlyRevenue,
    };
  }

  double get orderCompletionRate {
    if (totalOrders == 0) return 0.0;
    return (completedOrders / totalOrders) * 100;
  }

  String get membershipDuration {
    if (firstSaleDate == null) return 'New Vendor';
    final duration = DateTime.now().difference(firstSaleDate!);
    if (duration.inDays < 30) return '${duration.inDays} days';
    if (duration.inDays < 365) return '${(duration.inDays / 30).round()} months';
    return '${(duration.inDays / 365).round()} years';
  }
}

class VendorAchievement {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final AchievementType type;
  final DateTime earnedAt;
  final Map<String, dynamic> criteria; // Achievement criteria met

  VendorAchievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.type,
    required this.earnedAt,
    this.criteria = const {},
  });

  factory VendorAchievement.fromJson(Map<String, dynamic> json) {
    return VendorAchievement(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      type: AchievementType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => AchievementType.milestone,
      ),
      earnedAt: (json['earnedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      criteria: Map<String, dynamic>.from(json['criteria'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'type': type.toString(),
      'earnedAt': Timestamp.fromDate(earnedAt),
      'criteria': criteria,
    };
  }
}

enum AchievementType {
  milestone,    // Sales/order milestones
  quality,      // Quality achievements (high ratings)
  speed,        // Fast delivery/response
  volume,       // High volume seller
  loyalty,      // Customer loyalty achievements
  innovation,   // Innovation awards
  special       // Special achievements
}

// Use Flutter's Color class from material.dart
