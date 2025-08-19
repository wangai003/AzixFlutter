import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'vendor_verification_service.dart';

/// Comprehensive dispute resolution and escrow system
class DisputeResolutionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new dispute
  static Future<String> createDispute({
    required String orderId,
    required String complainantId,
    required String respondentId,
    required DisputeType type,
    required String reason,
    required String description,
    List<String> evidenceFiles = const [],
    double? requestedAmount,
  }) async {
    try {
      // Check if dispute already exists for this order
      final existingDispute = await _firestore
          .collection('disputes')
          .where('orderId', isEqualTo: orderId)
          .where('status', whereIn: [
            DisputeStatus.open.toString(),
            DisputeStatus.inProgress.toString(),
            DisputeStatus.awaitingResponse.toString(),
          ])
          .get();

      if (existingDispute.docs.isNotEmpty) {
        throw Exception('A dispute already exists for this order');
      }

      final disputeData = {
        'orderId': orderId,
        'complainantId': complainantId,
        'respondentId': respondentId,
        'type': type.toString(),
        'reason': reason,
        'description': description,
        'evidenceFiles': evidenceFiles,
        'requestedAmount': requestedAmount,
        'status': DisputeStatus.open.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'priority': _calculateDisputePriority(type, requestedAmount),
        'timeline': [
          {
            'action': DisputeAction.created.toString(),
            'actorId': complainantId,
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Dispute created',
          }
        ],
      };

      final disputeRef = await _firestore
          .collection('disputes')
          .add(disputeData);

      // Update order status
      await _firestore
          .collection('orders')
          .doc(orderId)
          .update({
        'disputeId': disputeRef.id,
        'status': 'disputed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Initialize escrow if needed
      if (type == DisputeType.paymentIssue || type == DisputeType.productNotReceived) {
        await _initializeEscrow(disputeRef.id, orderId);
      }

      // Send notifications
      await _sendDisputeNotifications(disputeRef.id, complainantId, respondentId, type);

      return disputeRef.id;
    } catch (e) {
      throw Exception('Failed to create dispute: $e');
    }
  }

  /// Respond to a dispute
  static Future<void> respondToDispute({
    required String disputeId,
    required String respondentId,
    required String response,
    List<String> evidenceFiles = const [],
    DisputeResolution? proposedResolution,
  }) async {
    try {
      final disputeDoc = await _firestore
          .collection('disputes')
          .doc(disputeId)
          .get();

      if (!disputeDoc.exists) {
        throw Exception('Dispute not found');
      }

      final disputeData = disputeDoc.data()!;
      
      if (disputeData['respondentId'] != respondentId) {
        throw Exception('Unauthorized to respond to this dispute');
      }

      final response_data = {
        'respondentResponse': {
          'response': response,
          'evidenceFiles': evidenceFiles,
          'proposedResolution': proposedResolution?.toJson(),
          'respondedAt': FieldValue.serverTimestamp(),
        },
        'status': DisputeStatus.awaitingMediation.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'timeline': FieldValue.arrayUnion([
          {
            'action': DisputeAction.responded.toString(),
            'actorId': respondentId,
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Respondent provided response',
          }
        ]),
      };

      await _firestore
          .collection('disputes')
          .doc(disputeId)
          .update(response_data);

      // Notify complainant and admin
      await _notifyOfDisputeResponse(disputeId, disputeData['complainantId']);

      // Auto-assign mediator if available
      await _autoAssignMediator(disputeId);

    } catch (e) {
      throw Exception('Failed to respond to dispute: $e');
    }
  }

  /// Assign mediator to dispute
  static Future<void> assignMediator({
    required String disputeId,
    required String mediatorId,
    required String assignedBy,
  }) async {
    try {
      await _firestore
          .collection('disputes')
          .doc(disputeId)
          .update({
        'mediatorId': mediatorId,
        'assignedBy': assignedBy,
        'mediationStartedAt': FieldValue.serverTimestamp(),
        'status': DisputeStatus.inMediation.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'timeline': FieldValue.arrayUnion([
          {
            'action': DisputeAction.mediatorAssigned.toString(),
            'actorId': assignedBy,
            'mediatorId': mediatorId,
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Mediator assigned to dispute',
          }
        ]),
      });

      // Notify all parties
      await _notifyOfMediatorAssignment(disputeId, mediatorId);

    } catch (e) {
      throw Exception('Failed to assign mediator: $e');
    }
  }

  /// Mediate dispute
  static Future<void> mediateDispute({
    required String disputeId,
    required String mediatorId,
    required String mediationNotes,
    required DisputeResolution resolution,
  }) async {
    try {
      final disputeDoc = await _firestore
          .collection('disputes')
          .doc(disputeId)
          .get();

      if (!disputeDoc.exists) {
        throw Exception('Dispute not found');
      }

      final disputeData = disputeDoc.data()!;
      
      if (disputeData['mediatorId'] != mediatorId) {
        throw Exception('Unauthorized to mediate this dispute');
      }

      final mediationData = {
        'mediation': {
          'mediatorId': mediatorId,
          'notes': mediationNotes,
          'resolution': resolution.toJson(),
          'mediatedAt': FieldValue.serverTimestamp(),
        },
        'resolution': resolution.toJson(),
        'status': DisputeStatus.resolved.toString(),
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'timeline': FieldValue.arrayUnion([
          {
            'action': DisputeAction.resolved.toString(),
            'actorId': mediatorId,
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Dispute resolved through mediation',
          }
        ]),
      };

      await _firestore
          .collection('disputes')
          .doc(disputeId)
          .update(mediationData);

      // Execute resolution
      await _executeResolution(disputeId, resolution);

      // Update trust scores
      await _updateTrustScoresAfterDispute(
        disputeData['complainantId'],
        disputeData['respondentId'],
        resolution,
      );

      // Notify all parties
      await _notifyOfDisputeResolution(disputeId, resolution);

    } catch (e) {
      throw Exception('Failed to mediate dispute: $e');
    }
  }

  /// Execute dispute resolution
  static Future<void> _executeResolution(
    String disputeId,
    DisputeResolution resolution,
  ) async {
    try {
      switch (resolution.type) {
        case ResolutionType.fullRefund:
          await _processRefund(disputeId, resolution.amount ?? 0);
          break;
        case ResolutionType.partialRefund:
          await _processRefund(disputeId, resolution.amount ?? 0);
          break;
        case ResolutionType.replacement:
          await _processReplacement(disputeId);
          break;
        case ResolutionType.storeCredit:
          await _processStoreCredit(disputeId, resolution.amount ?? 0);
          break;
        case ResolutionType.noAction:
          // No financial action needed
          break;
        case ResolutionType.vendorWarning:
          await _issueVendorWarning(disputeId);
          break;
        case ResolutionType.vendorSuspension:
          await _suspendVendor(disputeId, resolution.suspensionDays ?? 30);
          break;
      }
    } catch (e) {
      print('Error executing resolution: $e');
    }
  }

  /// Initialize escrow for dispute
  static Future<void> _initializeEscrow(String disputeId, String orderId) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final amount = orderData['totalAmount'] ?? 0.0;

      final escrowData = {
        'disputeId': disputeId,
        'orderId': orderId,
        'amount': amount,
        'status': EscrowStatus.held.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'buyerId': orderData['customerId'],
        'vendorId': orderData['vendorId'],
      };

      await _firestore.collection('escrow').add(escrowData);
    } catch (e) {
      print('Error initializing escrow: $e');
    }
  }

  /// Release escrow funds
  static Future<void> releaseEscrow({
    required String disputeId,
    required String recipient, // 'buyer' or 'vendor'
    double? amount,
  }) async {
    try {
      final escrowQuery = await _firestore
          .collection('escrow')
          .where('disputeId', isEqualTo: disputeId)
          .get();

      if (escrowQuery.docs.isEmpty) return;

      final escrowDoc = escrowQuery.docs.first;
      final escrowData = escrowDoc.data();
      final releaseAmount = amount ?? escrowData['amount'];

      await escrowDoc.reference.update({
        'status': EscrowStatus.released.toString(),
        'releasedTo': recipient,
        'releasedAmount': releaseAmount,
        'releasedAt': FieldValue.serverTimestamp(),
      });

      // Process the actual payment release
      await _processEscrowRelease(escrowData, recipient, releaseAmount);

    } catch (e) {
      print('Error releasing escrow: $e');
    }
  }

  /// Process escrow release
  static Future<void> _processEscrowRelease(
    Map<String, dynamic> escrowData,
    String recipient,
    double amount,
  ) async {
    try {
      // In a real implementation, this would integrate with payment providers
      // to actually transfer the funds
      
      final recipientId = recipient == 'buyer' 
          ? escrowData['buyerId'] 
          : escrowData['vendorId'];

      // Record the transaction
      await _firestore.collection('escrow_releases').add({
        'escrowId': escrowData['id'],
        'disputeId': escrowData['disputeId'],
        'recipientId': recipientId,
        'recipient': recipient,
        'amount': amount,
        'processedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      // Send notification
      await NotificationService.createNotification(
        userId: recipientId,
        type: NotificationType.payment,
        title: '💰 Escrow Funds Released',
        message: 'Dispute resolution: ₳${amount.toStringAsFixed(2)} has been released to you.',
        data: {
          'disputeId': escrowData['disputeId'],
          'amount': amount,
          'type': 'escrow_release',
        },
      );
    } catch (e) {
      print('Error processing escrow release: $e');
    }
  }

  /// Process refund
  static Future<void> _processRefund(String disputeId, double amount) async {
    await releaseEscrow(disputeId: disputeId, recipient: 'buyer', amount: amount);
  }

  /// Process replacement
  static Future<void> _processReplacement(String disputeId) async {
    // Implementation would depend on business logic
    // For now, just record the action
    await _firestore.collection('dispute_actions').add({
      'disputeId': disputeId,
      'action': 'replacement_ordered',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Process store credit
  static Future<void> _processStoreCredit(String disputeId, double amount) async {
    try {
      final disputeDoc = await _firestore.collection('disputes').doc(disputeId).get();
      if (!disputeDoc.exists) return;

      final disputeData = disputeDoc.data()!;
      final customerId = disputeData['complainantId'];

      // Add store credit to customer account
      await _firestore.collection('store_credits').add({
        'userId': customerId,
        'amount': amount,
        'reason': 'Dispute resolution',
        'disputeId': disputeId,
        'expiryDate': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 365))
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      await NotificationService.createNotification(
        userId: customerId,
        type: NotificationType.payment,
        title: '🎁 Store Credit Issued',
        message: 'You\'ve received ₳${amount.toStringAsFixed(2)} in store credit.',
        data: {
          'amount': amount,
          'disputeId': disputeId,
        },
      );
    } catch (e) {
      print('Error processing store credit: $e');
    }
  }

  /// Issue vendor warning
  static Future<void> _issueVendorWarning(String disputeId) async {
    try {
      final disputeDoc = await _firestore.collection('disputes').doc(disputeId).get();
      if (!disputeDoc.exists) return;

      final disputeData = disputeDoc.data()!;
      final vendorId = disputeData['respondentId'];

      await _firestore.collection('vendor_warnings').add({
        'vendorId': vendorId,
        'disputeId': disputeId,
        'reason': 'Dispute resolution',
        'issuedAt': FieldValue.serverTimestamp(),
        'severity': 'medium',
      });

      // Update trust score
      await VendorVerificationService.updateTrustScore(
        vendorId: vendorId,
        update: TrustScoreUpdate(
          type: TrustScoreUpdateType.policyViolation,
          reason: 'Warning issued due to dispute',
        ),
      );

      await NotificationService.createNotification(
        userId: vendorId,
        type: NotificationType.system,
        title: '⚠️ Warning Issued',
        message: 'A warning has been issued to your account due to dispute resolution.',
        data: {'disputeId': disputeId},
      );
    } catch (e) {
      print('Error issuing vendor warning: $e');
    }
  }

  /// Suspend vendor
  static Future<void> _suspendVendor(String disputeId, int days) async {
    try {
      final disputeDoc = await _firestore.collection('disputes').doc(disputeId).get();
      if (!disputeDoc.exists) return;

      final disputeData = disputeDoc.data()!;
      final vendorId = disputeData['respondentId'];

      final suspensionEnd = DateTime.now().add(Duration(days: days));

      await _firestore.collection('vendor_profiles').doc(vendorId).update({
        'isSuspended': true,
        'suspensionStart': FieldValue.serverTimestamp(),
        'suspensionEnd': Timestamp.fromDate(suspensionEnd),
        'suspensionReason': 'Dispute resolution',
        'disputeId': disputeId,
      });

      await NotificationService.createNotification(
        userId: vendorId,
        type: NotificationType.system,
        title: '🚫 Account Suspended',
        message: 'Your vendor account has been suspended for $days days due to dispute resolution.',
        data: {
          'disputeId': disputeId,
          'suspensionDays': days,
          'suspensionEnd': suspensionEnd.toIso8601String(),
        },
      );
    } catch (e) {
      print('Error suspending vendor: $e');
    }
  }

  /// Update trust scores after dispute
  static Future<void> _updateTrustScoresAfterDispute(
    String complainantId,
    String respondentId,
    DisputeResolution resolution,
  ) async {
    try {
      // Update respondent (usually vendor) trust score
      TrustScoreUpdateType updateType;
      
      switch (resolution.favoredParty) {
        case 'complainant':
          updateType = TrustScoreUpdateType.disputeLost;
          break;
        case 'respondent':
          updateType = TrustScoreUpdateType.disputeResolved;
          break;
        default:
          updateType = TrustScoreUpdateType.disputeResolved;
      }

      await VendorVerificationService.updateTrustScore(
        vendorId: respondentId,
        update: TrustScoreUpdate(
          type: updateType,
          reason: 'Dispute resolution outcome',
        ),
      );
    } catch (e) {
      print('Error updating trust scores: $e');
    }
  }

  /// Calculate dispute priority
  static String _calculateDisputePriority(DisputeType type, double? amount) {
    if (amount != null && amount > 1000) return 'high';
    if (type == DisputeType.fraud || type == DisputeType.safety) return 'high';
    if (type == DisputeType.paymentIssue) return 'medium';
    return 'low';
  }

  /// Auto-assign mediator
  static Future<void> _autoAssignMediator(String disputeId) async {
    try {
      // Get available mediators
      final mediatorsQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'mediator')
          .where('isAvailable', isEqualTo: true)
          .limit(1)
          .get();

      if (mediatorsQuery.docs.isNotEmpty) {
        final mediator = mediatorsQuery.docs.first;
        await assignMediator(
          disputeId: disputeId,
          mediatorId: mediator.id,
          assignedBy: 'system',
        );
      }
    } catch (e) {
      print('Error auto-assigning mediator: $e');
    }
  }

  /// Send dispute notifications
  static Future<void> _sendDisputeNotifications(
    String disputeId,
    String complainantId,
    String respondentId,
    DisputeType type,
  ) async {
    try {
      // Notify respondent
      await NotificationService.createNotification(
        userId: respondentId,
        type: NotificationType.system,
        title: '⚖️ New Dispute Filed',
        message: 'A dispute has been filed against one of your orders.',
        data: {
          'disputeId': disputeId,
          'type': type.toString(),
        },
      );

      // Notify admin/mediators
      await _notifyAdminOfNewDispute(disputeId, type);
    } catch (e) {
      print('Error sending dispute notifications: $e');
    }
  }

  /// Notify admin of new dispute
  static Future<void> _notifyAdminOfNewDispute(
    String disputeId,
    DisputeType type,
  ) async {
    try {
      final adminQuery = await _firestore
          .collection('users')
          .where('role', whereIn: ['admin', 'mediator'])
          .get();

      for (final adminDoc in adminQuery.docs) {
        await NotificationService.createNotification(
          userId: adminDoc.id,
          type: NotificationType.system,
          title: '🚨 New Dispute Requires Attention',
          message: 'A new ${type.toString().split('.').last} dispute has been filed.',
          data: {
            'disputeId': disputeId,
            'type': type.toString(),
            'priority': _calculateDisputePriority(type, null),
          },
        );
      }
    } catch (e) {
      print('Error notifying admin: $e');
    }
  }

  /// Notify of dispute response
  static Future<void> _notifyOfDisputeResponse(
    String disputeId,
    String complainantId,
  ) async {
    try {
      await NotificationService.createNotification(
        userId: complainantId,
        type: NotificationType.system,
        title: '📝 Dispute Response Received',
        message: 'The other party has responded to your dispute.',
        data: {'disputeId': disputeId},
      );
    } catch (e) {
      print('Error notifying of dispute response: $e');
    }
  }

  /// Notify of mediator assignment
  static Future<void> _notifyOfMediatorAssignment(
    String disputeId,
    String mediatorId,
  ) async {
    try {
      final disputeDoc = await _firestore.collection('disputes').doc(disputeId).get();
      if (!disputeDoc.exists) return;

      final disputeData = disputeDoc.data()!;

      // Notify complainant
      await NotificationService.createNotification(
        userId: disputeData['complainantId'],
        type: NotificationType.system,
        title: '👨‍⚖️ Mediator Assigned',
        message: 'A mediator has been assigned to your dispute.',
        data: {'disputeId': disputeId, 'mediatorId': mediatorId},
      );

      // Notify respondent
      await NotificationService.createNotification(
        userId: disputeData['respondentId'],
        type: NotificationType.system,
        title: '👨‍⚖️ Mediator Assigned',
        message: 'A mediator has been assigned to the dispute.',
        data: {'disputeId': disputeId, 'mediatorId': mediatorId},
      );

      // Notify mediator
      await NotificationService.createNotification(
        userId: mediatorId,
        type: NotificationType.system,
        title: '⚖️ New Dispute Assignment',
        message: 'You have been assigned to mediate a dispute.',
        data: {'disputeId': disputeId},
      );
    } catch (e) {
      print('Error notifying of mediator assignment: $e');
    }
  }

  /// Notify of dispute resolution
  static Future<void> _notifyOfDisputeResolution(
    String disputeId,
    DisputeResolution resolution,
  ) async {
    try {
      final disputeDoc = await _firestore.collection('disputes').doc(disputeId).get();
      if (!disputeDoc.exists) return;

      final disputeData = disputeDoc.data()!;

      // Notify both parties
      final message = 'Your dispute has been resolved: ${resolution.description}';

      await NotificationService.createNotification(
        userId: disputeData['complainantId'],
        type: NotificationType.system,
        title: '✅ Dispute Resolved',
        message: message,
        data: {'disputeId': disputeId, 'resolution': resolution.toJson()},
      );

      await NotificationService.createNotification(
        userId: disputeData['respondentId'],
        type: NotificationType.system,
        title: '✅ Dispute Resolved',
        message: message,
        data: {'disputeId': disputeId, 'resolution': resolution.toJson()},
      );
    } catch (e) {
      print('Error notifying of dispute resolution: $e');
    }
  }

  /// Get disputes for user
  static Stream<List<DisputeSummary>> getUserDisputes(String userId) {
    return _firestore
        .collection('disputes')
        .where('complainantId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DisputeSummary.fromFirestore(doc))
            .toList());
  }

  /// Get disputes for vendor
  static Stream<List<DisputeSummary>> getVendorDisputes(String vendorId) {
    return _firestore
        .collection('disputes')
        .where('respondentId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DisputeSummary.fromFirestore(doc))
            .toList());
  }

  /// Get all disputes for admin
  static Stream<List<DisputeSummary>> getAllDisputes({
    DisputeStatus? statusFilter,
    String? priorityFilter,
  }) {
    Query query = _firestore
        .collection('disputes')
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.toString());
    }

    if (priorityFilter != null) {
      query = query.where('priority', isEqualTo: priorityFilter);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => DisputeSummary.fromFirestore(doc))
        .toList());
  }
}

/// Dispute type enum
enum DisputeType {
  productNotReceived,
  productDamaged,
  productNotAsDescribed,
  serviceNotProvided,
  serviceIncomplete,
  paymentIssue,
  refundRequest,
  fraud,
  safety,
  other,
}

/// Dispute status enum
enum DisputeStatus {
  open,
  awaitingResponse,
  awaitingMediation,
  inMediation,
  inProgress,
  resolved,
  closed,
  escalated,
}

/// Dispute action enum
enum DisputeAction {
  created,
  responded,
  mediatorAssigned,
  evidenceAdded,
  resolved,
  escalated,
  closed,
}

/// Resolution type enum
enum ResolutionType {
  fullRefund,
  partialRefund,
  replacement,
  storeCredit,
  noAction,
  vendorWarning,
  vendorSuspension,
}

/// Escrow status enum
enum EscrowStatus {
  held,
  released,
  disputed,
  expired,
}

/// Dispute resolution model
class DisputeResolution {
  final ResolutionType type;
  final String description;
  final double? amount;
  final String? favoredParty; // 'complainant', 'respondent', or 'neutral'
  final int? suspensionDays;
  final Map<String, dynamic> additionalTerms;

  DisputeResolution({
    required this.type,
    required this.description,
    this.amount,
    this.favoredParty,
    this.suspensionDays,
    this.additionalTerms = const {},
  });

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'description': description,
    'amount': amount,
    'favoredParty': favoredParty,
    'suspensionDays': suspensionDays,
    'additionalTerms': additionalTerms,
  };

  factory DisputeResolution.fromJson(Map<String, dynamic> json) => DisputeResolution(
    type: ResolutionType.values.firstWhere(
      (type) => type.toString() == json['type'],
      orElse: () => ResolutionType.noAction,
    ),
    description: json['description'] ?? '',
    amount: json['amount']?.toDouble(),
    favoredParty: json['favoredParty'],
    suspensionDays: json['suspensionDays'],
    additionalTerms: Map<String, dynamic>.from(json['additionalTerms'] ?? {}),
  );
}

/// Dispute summary model
class DisputeSummary {
  final String id;
  final String orderId;
  final String complainantId;
  final String respondentId;
  final DisputeType type;
  final String reason;
  final DisputeStatus status;
  final String priority;
  final DateTime createdAt;
  final String? mediatorId;

  DisputeSummary({
    required this.id,
    required this.orderId,
    required this.complainantId,
    required this.respondentId,
    required this.type,
    required this.reason,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.mediatorId,
  });

  factory DisputeSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DisputeSummary(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      complainantId: data['complainantId'] ?? '',
      respondentId: data['respondentId'] ?? '',
      type: DisputeType.values.firstWhere(
        (type) => type.toString() == data['type'],
        orElse: () => DisputeType.other,
      ),
      reason: data['reason'] ?? '',
      status: DisputeStatus.values.firstWhere(
        (status) => status.toString() == data['status'],
        orElse: () => DisputeStatus.open,
      ),
      priority: data['priority'] ?? 'low',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mediatorId: data['mediatorId'],
    );
  }
}
