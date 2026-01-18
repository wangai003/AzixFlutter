import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'raffle_service.dart';

/// Service to automatically check and draw winners for expired raffles
class RaffleSchedulerService {
  static Timer? _schedulerTimer;
  static bool _isRunning = false;

  /// Start the raffle scheduler (checks every 5 minutes)
  static void startScheduler() {
    if (_isRunning) {
      print('⚠️ Raffle scheduler already running');
      return;
    }

    print('✅ Starting raffle scheduler service...');
    _isRunning = true;

    // Run immediately on start
    _checkAndDrawExpiredRaffles();

    // Then run every 5 minutes
    _schedulerTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) => _checkAndDrawExpiredRaffles(),
    );
  }

  /// Stop the raffle scheduler
  static void stopScheduler() {
    if (_schedulerTimer != null) {
      _schedulerTimer!.cancel();
      _schedulerTimer = null;
      _isRunning = false;
      print('🛑 Raffle scheduler stopped');
    }
  }

  /// Check for expired raffles and draw winners
  static Future<void> _checkAndDrawExpiredRaffles() async {
    try {
      print('🔍 Checking for expired raffles...');
      await RaffleService.checkAndDrawExpiredRaffles();
      print('✅ Expired raffles check completed');
    } catch (e) {
      print('❌ Error checking expired raffles: $e');
    }
  }

  /// Manually trigger winner draw check (useful for testing)
  static Future<void> triggerManualCheck() async {
    print('🎲 Manual raffle check triggered');
    await _checkAndDrawExpiredRaffles();
  }

  /// Check if scheduler is running
  static bool get isRunning => _isRunning;
}

