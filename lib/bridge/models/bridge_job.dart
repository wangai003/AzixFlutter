import 'route_models.dart' as bridge_models;

/// Status of a bridge job
enum BridgeJobStatus {
  pending,      // Job created, waiting to start
  inProgress,  // Route execution in progress
  waitingForUser, // Waiting for user to sign transaction
  completed,   // Route completed successfully
  failed,      // Route failed
  cancelled,   // User cancelled
}

/// Status of a route step
enum StepStatus {
  pending,
  waitingForSignature,
  signed,
  submitted,
  confirmed,
  failed,
}

/// Bridge job model for tracking route execution
class BridgeJob {
  final String id;
  final bridge_models.BridgeRoute route;
  final bridge_models.QuoteRequest quoteRequest;
  final BridgeJobStatus status;
  final int currentStepIndex;
  final List<StepExecution> steps;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? error;
  final Map<String, dynamic>? metadata;

  BridgeJob({
    required this.id,
    required this.route,
    required this.quoteRequest,
    required this.status,
    required this.currentStepIndex,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
    this.error,
    this.metadata,
  });

  factory BridgeJob.fromJson(Map<String, dynamic> json) {
    return BridgeJob(
      id: json['id'] as String,
      route: bridge_models.BridgeRoute.fromJson(json['route'] as Map<String, dynamic>),
      quoteRequest: bridge_models.QuoteRequest(
        fromChain: json['quoteRequest']['fromChain'] as String,
        toChain: json['quoteRequest']['toChain'] as String,
        fromToken: json['quoteRequest']['fromToken'] as String,
        toToken: json['quoteRequest']['toToken'] as String,
        fromAmount: json['quoteRequest']['fromAmount'] as String,
        fromAddress: json['quoteRequest']['fromAddress'] as String,
        toAddress: json['quoteRequest']['toAddress'] as String,
      ),
      status: BridgeJobStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => BridgeJobStatus.pending,
      ),
      currentStepIndex: json['currentStepIndex'] as int,
      steps: (json['steps'] as List<dynamic>)
          .map((step) => StepExecution.fromJson(step as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route': {
        'id': route.id,
        'steps': route.steps.map((s) => {
          'id': s.id,
          'type': s.type,
          'tool': s.tool,
        }).toList(),
        'estimate': {
          'fromAmount': route.estimate.fromAmount,
          'toAmount': route.estimate.toAmount,
        },
      },
      'quoteRequest': quoteRequest.toJson(),
      'status': status.toString(),
      'currentStepIndex': currentStepIndex,
      'steps': steps.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'error': error,
      'metadata': metadata,
    };
  }

  BridgeJob copyWith({
    String? id,
    bridge_models.BridgeRoute? route,
    bridge_models.QuoteRequest? quoteRequest,
    BridgeJobStatus? status,
    int? currentStepIndex,
    List<StepExecution>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return BridgeJob(
      id: id ?? this.id,
      route: route ?? this.route,
      quoteRequest: quoteRequest ?? this.quoteRequest,
      status: status ?? this.status,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Execution state for a single route step
class StepExecution {
  final String stepId;
  final StepStatus status;
  final String? txHash;
  final String? chain;
  final DateTime? signedAt;
  final DateTime? submittedAt;
  final DateTime? confirmedAt;
  final String? error;
  final Map<String, dynamic>? metadata;

  StepExecution({
    required this.stepId,
    required this.status,
    this.txHash,
    this.chain,
    this.signedAt,
    this.submittedAt,
    this.confirmedAt,
    this.error,
    this.metadata,
  });

  factory StepExecution.fromJson(Map<String, dynamic> json) {
    return StepExecution(
      stepId: json['stepId'] as String,
      status: StepStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => StepStatus.pending,
      ),
      txHash: json['txHash'] as String?,
      chain: json['chain'] as String?,
      signedAt: json['signedAt'] != null
          ? DateTime.parse(json['signedAt'] as String)
          : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.parse(json['confirmedAt'] as String)
          : null,
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepId': stepId,
      'status': status.toString(),
      'txHash': txHash,
      'chain': chain,
      'signedAt': signedAt?.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'confirmedAt': confirmedAt?.toIso8601String(),
      'error': error,
      'metadata': metadata,
    };
  }

  StepExecution copyWith({
    String? stepId,
    StepStatus? status,
    String? txHash,
    String? chain,
    DateTime? signedAt,
    DateTime? submittedAt,
    DateTime? confirmedAt,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return StepExecution(
      stepId: stepId ?? this.stepId,
      status: status ?? this.status,
      txHash: txHash ?? this.txHash,
      chain: chain ?? this.chain,
      signedAt: signedAt ?? this.signedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }
}

