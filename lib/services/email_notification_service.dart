import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Service for sending email notifications for mining events
class EmailNotificationService {
  static const String _apiKey =
      'your-sendgrid-api-key'; // Replace with actual API key
  static const String _sendGridUrl = 'https://api.sendgrid.com/v3/mail/send';

  /// Send mining start notification
  static Future<void> sendMiningStartNotification({
    required String userId,
    required String userEmail,
    required double miningRate,
    required DateTime sessionStart,
    required DateTime sessionEnd,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(userId)
          .get();

      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? userData['email'] ?? 'User';

      final emailData = {
        'personalizations': [
          {
            'to': [
              {'email': userEmail},
            ],
            'subject': '🚀 Mining Session Started - AZIX',
          },
        ],
        'from': {'email': 'noreply@azix.app', 'name': 'AZIX Mining'},
        'content': [
          {
            'type': 'text/html',
            'value': _buildMiningStartEmail(
              userName: userName,
              miningRate: miningRate,
              sessionStart: sessionStart,
              sessionEnd: sessionEnd,
            ),
          },
        ],
      };

      await _sendEmail(emailData);

      // Log notification
      await _logNotification(userId, 'mining_started', {
        'miningRate': miningRate,
        'sessionStart': sessionStart.toIso8601String(),
        'sessionEnd': sessionEnd.toIso8601String(),
      });
    } catch (e) {
      // Log error but don't throw
      await _logNotificationError(userId, 'mining_started', e.toString());
    }
  }

  /// Send mining completion notification
  static Future<void> sendMiningCompletionNotification({
    required String userId,
    required String userEmail,
    required double earnedAkofa,
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required Duration actualDuration,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(userId)
          .get();

      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? userData['email'] ?? 'User';

      final emailData = {
        'personalizations': [
          {
            'to': [
              {'email': userEmail},
            ],
            'subject': '✅ Mining Session Completed - AZIX',
          },
        ],
        'from': {'email': 'noreply@azix.app', 'name': 'AZIX Mining'},
        'content': [
          {
            'type': 'text/html',
            'value': _buildMiningCompletionEmail(
              userName: userName,
              earnedAkofa: earnedAkofa,
              sessionStart: sessionStart,
              sessionEnd: sessionEnd,
              actualDuration: actualDuration,
            ),
          },
        ],
      };

      await _sendEmail(emailData);

      // Log notification
      await _logNotification(userId, 'mining_completed', {
        'earnedAkofa': earnedAkofa,
        'sessionStart': sessionStart.toIso8601String(),
        'sessionEnd': sessionEnd.toIso8601String(),
        'actualDuration': actualDuration.inSeconds,
      });
    } catch (e) {
      await _logNotificationError(userId, 'mining_completed', e.toString());
    }
  }

  /// Send mining pause notification
  static Future<void> sendMiningPauseNotification({
    required String userId,
    required String userEmail,
    required double currentEarnings,
    required DateTime pausedAt,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(userId)
          .get();

      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? userData['email'] ?? 'User';

      final emailData = {
        'personalizations': [
          {
            'to': [
              {'email': userEmail},
            ],
            'subject': '⏸️ Mining Session Paused - AZIX',
          },
        ],
        'from': {'email': 'noreply@azix.app', 'name': 'AZIX Mining'},
        'content': [
          {
            'type': 'text/html',
            'value': _buildMiningPauseEmail(
              userName: userName,
              currentEarnings: currentEarnings,
              pausedAt: pausedAt,
            ),
          },
        ],
      };

      await _sendEmail(emailData);

      // Log notification
      await _logNotification(userId, 'mining_paused', {
        'currentEarnings': currentEarnings,
        'pausedAt': pausedAt.toIso8601String(),
      });
    } catch (e) {
      await _logNotificationError(userId, 'mining_paused', e.toString());
    }
  }

  /// Send mining resume notification
  static Future<void> sendMiningResumeNotification({
    required String userId,
    required String userEmail,
    required double currentEarnings,
    required DateTime resumedAt,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(userId)
          .get();

      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? userData['email'] ?? 'User';

      final emailData = {
        'personalizations': [
          {
            'to': [
              {'email': userEmail},
            ],
            'subject': '▶️ Mining Session Resumed - AZIX',
          },
        ],
        'from': {'email': 'noreply@azix.app', 'name': 'AZIX Mining'},
        'content': [
          {
            'type': 'text/html',
            'value': _buildMiningResumeEmail(
              userName: userName,
              currentEarnings: currentEarnings,
              resumedAt: resumedAt,
            ),
          },
        ],
      };

      await _sendEmail(emailData);

      // Log notification
      await _logNotification(userId, 'mining_resumed', {
        'currentEarnings': currentEarnings,
        'resumedAt': resumedAt.toIso8601String(),
      });
    } catch (e) {
      await _logNotificationError(userId, 'mining_resumed', e.toString());
    }
  }

  /// Send email via SendGrid
  static Future<void> _sendEmail(Map<String, dynamic> emailData) async {
    try {
      final response = await http.post(
        Uri.parse(_sendGridUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(emailData),
      );

      if (response.statusCode != 202) {
        throw Exception('Failed to send email: ${response.statusCode}');
      }
    } catch (e) {
      // For demo purposes, we'll just log the error
      // In production, you'd want to implement a fallback or queue system
      print('Email sending failed: $e');
      throw e;
    }
  }

  /// Build mining start email HTML
  static String _buildMiningStartEmail({
    required String userName,
    required double miningRate,
    required DateTime sessionStart,
    required DateTime sessionEnd,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Mining Started</title>
</head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
    <div style="background: linear-gradient(135deg, #1a1a2e, #16213e); color: white; padding: 30px; text-align: center;">
        <h1>🚀 Mining Session Started!</h1>
        <p>Hello $userName,</p>
    </div>

    <div style="padding: 30px; background: #f8f9fa;">
        <h2>Your mining session has begun!</h2>

        <div style="background: white; padding: 20px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #ffd700;">
            <h3>Session Details:</h3>
            <p><strong>Mining Rate:</strong> $miningRate ₳/hour</p>
            <p><strong>Started:</strong> ${sessionStart.toString().split('.')[0]}</p>
            <p><strong>Ends:</strong> ${sessionEnd.toString().split('.')[0]}</p>
            <p><strong>Expected Earnings:</strong> ${(miningRate * 24).toStringAsFixed(2)} ₳</p>
        </div>

        <p>You can monitor your mining progress in the AZIX app. Your earnings will be automatically credited to your wallet when the session completes.</p>

        <div style="text-align: center; margin: 30px 0;">
            <a href="https://azix.app" style="background: #ffd700; color: #000; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">View Mining Progress</a>
        </div>
    </div>

    <div style="background: #343a40; color: white; padding: 20px; text-align: center;">
        <p>Happy Mining! ⛏️</p>
        <p>AZIX Team</p>
    </div>
</body>
</html>
    ''';
  }

  /// Build mining completion email HTML
  static String _buildMiningCompletionEmail({
    required String userName,
    required double earnedAkofa,
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required Duration actualDuration,
  }) {
    final hours = actualDuration.inHours;
    final minutes = actualDuration.inMinutes.remainder(60);

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Mining Completed</title>
</head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
    <div style="background: linear-gradient(135deg, #28a745, #20c997); color: white; padding: 30px; text-align: center;">
        <h1>✅ Mining Session Completed!</h1>
        <p>Hello $userName,</p>
    </div>

    <div style="padding: 30px; background: #f8f9fa;">
        <h2>Congratulations! Your mining session has finished.</h2>

        <div style="background: white; padding: 20px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #28a745;">
            <h3>Session Results:</h3>
            <p><strong>💰 Earnings:</strong> $earnedAkofa ₳</p>
            <p><strong>⏱️ Duration:</strong> $hours hours $minutes minutes</p>
            <p><strong>📅 Started:</strong> ${sessionStart.toString().split('.')[0]}</p>
            <p><strong>🏁 Completed:</strong> ${sessionEnd.toString().split('.')[0]}</p>
        </div>

        <p>Your earnings have been automatically credited to your AZIX wallet. You can now use your AKOFA tokens or start a new mining session!</p>

        <div style="text-align: center; margin: 30px 0;">
            <a href="https://azix.app" style="background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">Start New Session</a>
        </div>
    </div>

    <div style="background: #343a40; color: white; padding: 20px; text-align: center;">
        <p>Keep Mining! ⛏️</p>
        <p>AZIX Team</p>
    </div>
</body>
</html>
    ''';
  }

  /// Build mining pause email HTML
  static String _buildMiningPauseEmail({
    required String userName,
    required double currentEarnings,
    required DateTime pausedAt,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Mining Paused</title>
</head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
    <div style="background: linear-gradient(135deg, #ffc107, #fd7e14); color: white; padding: 30px; text-align: center;">
        <h1>⏸️ Mining Session Paused</h1>
        <p>Hello $userName,</p>
    </div>

    <div style="padding: 30px; background: #f8f9fa;">
        <h2>Your mining session has been paused.</h2>

        <div style="background: white; padding: 20px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #ffc107;">
            <h3>Current Status:</h3>
            <p><strong>💰 Current Earnings:</strong> $currentEarnings ₳</p>
            <p><strong>⏸️ Paused At:</strong> ${pausedAt.toString().split('.')[0]}</p>
        </div>

        <p>You can resume your mining session anytime from the AZIX app. Your progress is safely saved and will continue from where you left off.</p>

        <div style="text-align: center; margin: 30px 0;">
            <a href="https://azix.app" style="background: #ffc107; color: #000; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">Resume Mining</a>
        </div>
    </div>

    <div style="background: #343a40; color: white; padding: 20px; text-align: center;">
        <p>AZIX Team</p>
    </div>
</body>
</html>
    ''';
  }

  /// Build mining resume email HTML
  static String _buildMiningResumeEmail({
    required String userName,
    required double currentEarnings,
    required DateTime resumedAt,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Mining Resumed</title>
</head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
    <div style="background: linear-gradient(135deg, #007bff, #6610f2); color: white; padding: 30px; text-align: center;">
        <h1>▶️ Mining Session Resumed</h1>
        <p>Hello $userName,</p>
    </div>

    <div style="padding: 30px; background: #f8f9fa;">
        <h2>Your mining session has been resumed!</h2>

        <div style="background: white; padding: 20px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #007bff;">
            <h3>Current Status:</h3>
            <p><strong>💰 Current Earnings:</strong> $currentEarnings ₳</p>
            <p><strong>▶️ Resumed At:</strong> ${resumedAt.toString().split('.')[0]}</p>
        </div>

        <p>Your mining session is now active again. Keep earning AKOFA tokens!</p>

        <div style="text-align: center; margin: 30px 0;">
            <a href="https://azix.app" style="background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">View Progress</a>
        </div>
    </div>

    <div style="background: #343a40; color: white; padding: 20px; text-align: center;">
        <p>AZIX Team</p>
    </div>
</body>
</html>
    ''';
  }

  /// Log notification event
  static Future<void> _logNotification(
    String userId,
    String eventType,
    Map<String, dynamic> details,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('email_notifications').add({
        'userId': userId,
        'eventType': eventType,
        'details': details,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'sent',
      });
    } catch (e) {
      // Log locally if Firestore fails
      print('Failed to log notification: $e');
    }
  }

  /// Log notification error
  static Future<void> _logNotificationError(
    String userId,
    String eventType,
    String error,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('email_notifications').add({
        'userId': userId,
        'eventType': eventType,
        'error': error,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'failed',
      });
    } catch (e) {
      print('Failed to log notification error: $e');
    }
  }

  /// Get user's email preferences
  static Future<Map<String, bool>> getUserEmailPreferences(
    String userId,
  ) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(userId)
          .get();

      final userData = userDoc.data() ?? {};
      final preferences =
          userData['emailPreferences'] as Map<String, dynamic>? ?? {};

      return {
        'miningStart': preferences['miningStart'] ?? true,
        'miningComplete': preferences['miningComplete'] ?? true,
        'miningPause': preferences['miningPause'] ?? false,
        'miningResume': preferences['miningResume'] ?? false,
      };
    } catch (e) {
      // Default to sending important notifications only
      return {
        'miningStart': true,
        'miningComplete': true,
        'miningPause': false,
        'miningResume': false,
      };
    }
  }
}
