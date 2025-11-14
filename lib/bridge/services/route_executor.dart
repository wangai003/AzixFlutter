import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../bridge_config.dart';
import '../models/bridge_job.dart';
import '../models/route_models.dart' as bridge_models;
import '../services/lifi_client.dart';
import '../services/job_store.dart';
import '../crypto/stellar_signer.dart';
import '../crypto/evm_signer.dart';

/// Route executor for handling multi-step bridge routes
class RouteExecutor {
  final LifiClient _lifiClient;
  final JobStore _jobStore;
  final StellarSigner _stellarSigner;
  final EvmSigner _evmSigner;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Timer? _pollingTimer;
  final Map<String, StreamController<BridgeJob>> _jobControllers = {};

  RouteExecutor({
    required LifiClient lifiClient,
    required JobStore jobStore,
    required StellarSigner stellarSigner,
    required EvmSigner evmSigner,
  })  : _lifiClient = lifiClient,
        _jobStore = jobStore,
        _stellarSigner = stellarSigner,
        _evmSigner = evmSigner;

  /// Execute a route (start the bridge process)
  Future<BridgeJob> executeRoute(bridge_models.BridgeRoute route, bridge_models.QuoteRequest quoteRequest) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Create job
    final job = BridgeJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      route: route,
      quoteRequest: quoteRequest,
      status: BridgeJobStatus.pending,
      currentStepIndex: 0,
      steps: route.steps
          .map((step) => StepExecution(
                stepId: step.id,
                status: StepStatus.pending,
              ))
          .toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save job
    await _jobStore.saveJob(job);

    // Start execution
    _startExecution(job);

    return job;
  }

  /// Start route execution
  Future<void> _startExecution(BridgeJob job) async {
    try {
      // Update status
      final updatedJob = job.copyWith(
        status: BridgeJobStatus.inProgress,
        updatedAt: DateTime.now(),
      );
      await _jobStore.saveJob(updatedJob);
      _notifyJobUpdate(updatedJob);

      // Process first step
      await _processStep(updatedJob, 0);
    } catch (e) {
      print('❌ Error starting route execution: $e');
      await _markJobFailed(job, e.toString());
    }
  }

  /// Process a single step
  Future<void> _processStep(BridgeJob job, int stepIndex) async {
    try {
      if (stepIndex >= job.route.steps.length) {
        // All steps completed
        await _markJobCompleted(job);
        return;
      }

      final step = job.route.steps[stepIndex];
      final stepExecution = job.steps[stepIndex];

      // Check if step requires user signing
      if (step.requiresStellarSigning() || step.requiresEvmSigning()) {
        // Mark as waiting for user
        final updatedJob = job.copyWith(
          status: BridgeJobStatus.waitingForUser,
          currentStepIndex: stepIndex,
          steps: [
            ...job.steps.take(stepIndex),
            stepExecution.copyWith(status: StepStatus.waitingForSignature),
            ...job.steps.skip(stepIndex + 1),
          ],
          updatedAt: DateTime.now(),
        );
        await _jobStore.saveJob(updatedJob);
        _notifyJobUpdate(updatedJob);
        return; // Wait for user to sign
      }

      // Auto-execute step (if no signing required)
      await _executeStep(job, stepIndex);
    } catch (e) {
      print('❌ Error processing step: $e');
      await _markJobFailed(job, e.toString());
    }
  }

  /// Execute a step (sign and submit transaction)
  Future<void> _executeStep(BridgeJob job, int stepIndex) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final step = job.route.steps[stepIndex];
      final stepExecution = job.steps[stepIndex];

      // Prepare transaction request
      final txRequest = await _lifiClient.prepareStep(job.route, stepIndex);
      
      if (txRequest == null) {
        // No transaction needed, move to next step
        await _advanceToNextStep(job, stepIndex);
        return;
      }

      String? txHash;

      // Sign and submit based on type
      if (step.requiresStellarSigning()) {
        if (txRequest.type == 'stellar_xdr' && txRequest.xdr != null) {
          // Sign existing XDR
          txHash = await _stellarSigner.signAndSubmitXdr(
            txRequest.xdr!,
            user.uid,
          );
        } else if (txRequest.type == 'stellar_construct') {
          // Construct and sign Payment XDR
          final depositAddress = txRequest.additionalData?['depositAddress'] as String?;
          final amount = txRequest.additionalData?['amount'] as String?;
          final assetCode = txRequest.additionalData?['asset'] as String?;
          
          if (depositAddress != null && amount != null && assetCode != null) {
            txHash = await _stellarSigner.constructAndSignPaymentXdr(
              userId: user.uid,
              depositAddress: depositAddress,
              amount: amount,
              assetCode: assetCode,
            );
          }
        }
      } else if (step.requiresEvmSigning()) {
        // Sign EVM transaction
        if (!_evmSigner.isConnected) {
          await _evmSigner.connect();
        }
        
        // Switch chain if needed
        if (txRequest.chainId != null) {
          await _evmSigner.switchChain(txRequest.chainId!);
        }
        
        txHash = await _evmSigner.signAndSendTransaction(txRequest);
      }

      if (txHash == null) {
        throw Exception('Failed to get transaction hash');
      }

      // Update step execution
      final updatedStepExecution = stepExecution.copyWith(
        status: StepStatus.submitted,
        txHash: txHash,
        chain: step.action.from.chainId,
        submittedAt: DateTime.now(),
      );

      final updatedJob = job.copyWith(
        status: BridgeJobStatus.inProgress,
        steps: [
          ...job.steps.take(stepIndex),
          updatedStepExecution,
          ...job.steps.skip(stepIndex + 1),
        ],
        updatedAt: DateTime.now(),
      );

      await _jobStore.saveJob(updatedJob);
      _notifyJobUpdate(updatedJob);

      // Start polling for confirmation
      _pollForStepConfirmation(updatedJob, stepIndex);
    } catch (e) {
      print('❌ Error executing step: $e');
      await _markStepFailed(job, stepIndex, e.toString());
    }
  }

  /// Poll for step confirmation
  void _pollForStepConfirmation(BridgeJob job, int stepIndex) {
    Timer.periodic(BridgeConfig.routePollingInterval, (timer) async {
      try {
        final status = await _lifiClient.getStatus(job.route.id);
        
        // Check if step is confirmed
        final stepStatus = status['steps']?[stepIndex];
        if (stepStatus != null && stepStatus['status'] == 'DONE') {
          timer.cancel();
          
          // Mark step as confirmed
          final updatedStepExecution = job.steps[stepIndex].copyWith(
            status: StepStatus.confirmed,
            confirmedAt: DateTime.now(),
          );

          final updatedJob = job.copyWith(
            steps: [
              ...job.steps.take(stepIndex),
              updatedStepExecution,
              ...job.steps.skip(stepIndex + 1),
            ],
            updatedAt: DateTime.now(),
          );

          await _jobStore.saveJob(updatedJob);
          _notifyJobUpdate(updatedJob);

          // Move to next step
          await _advanceToNextStep(updatedJob, stepIndex);
        }
      } catch (e) {
        print('❌ Error polling step status: $e');
        timer.cancel();
        await _markStepFailed(job, stepIndex, e.toString());
      }
    });
  }

  /// Advance to next step
  Future<void> _advanceToNextStep(BridgeJob job, int currentStepIndex) async {
    final nextStepIndex = currentStepIndex + 1;
    
    if (nextStepIndex >= job.route.steps.length) {
      // All steps completed
      await _markJobCompleted(job);
    } else {
      // Process next step
      await _processStep(job, nextStepIndex);
    }
  }

  /// Mark job as completed
  Future<void> _markJobCompleted(BridgeJob job) async {
    final updatedJob = job.copyWith(
      status: BridgeJobStatus.completed,
      updatedAt: DateTime.now(),
    );
    await _jobStore.saveJob(updatedJob);
    _notifyJobUpdate(updatedJob);
  }

  /// Mark job as failed
  Future<void> _markJobFailed(BridgeJob job, String error) async {
    final updatedJob = job.copyWith(
      status: BridgeJobStatus.failed,
      error: error,
      updatedAt: DateTime.now(),
    );
    await _jobStore.saveJob(updatedJob);
    _notifyJobUpdate(updatedJob);
  }

  /// Mark step as failed
  Future<void> _markStepFailed(
    BridgeJob job,
    int stepIndex,
    String error,
  ) async {
    final updatedStepExecution = job.steps[stepIndex].copyWith(
      status: StepStatus.failed,
      error: error,
    );

    final updatedJob = job.copyWith(
      steps: [
        ...job.steps.take(stepIndex),
        updatedStepExecution,
        ...job.steps.skip(stepIndex + 1),
      ],
      updatedAt: DateTime.now(),
    );

    await _jobStore.saveJob(updatedJob);
    _notifyJobUpdate(updatedJob);
    await _markJobFailed(updatedJob, 'Step $stepIndex failed: $error');
  }

  /// User signs a step (called from UI)
  Future<void> signStep(String jobId, int stepIndex) async {
    final job = await _jobStore.getJob(jobId);
    if (job == null) {
      throw Exception('Job not found');
    }

    if (job.status != BridgeJobStatus.waitingForUser) {
      throw Exception('Job is not waiting for user signature');
    }

    // Execute the step
    await _executeStep(job, stepIndex);
  }

  /// Get job stream
  Stream<BridgeJob> getJobStream(String jobId) {
    if (!_jobControllers.containsKey(jobId)) {
      _jobControllers[jobId] = StreamController<BridgeJob>.broadcast();
    }
    return _jobControllers[jobId]!.stream;
  }

  /// Notify job update
  void _notifyJobUpdate(BridgeJob job) {
    if (_jobControllers.containsKey(job.id)) {
      _jobControllers[job.id]!.add(job);
    }
  }

  /// Dispose resources
  void dispose() {
    _pollingTimer?.cancel();
    for (final controller in _jobControllers.values) {
      controller.close();
    }
    _jobControllers.clear();
  }
}

