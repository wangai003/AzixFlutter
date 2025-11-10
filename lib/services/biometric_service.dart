import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'webauthn_service.dart';

/// Unified biometric authentication service
/// Supports both mobile (local_auth) and web (WebAuthn) platforms
class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on the current platform
  static Future<Map<String, dynamic>> checkBiometricSupport() async {
    try {
      if (kIsWeb) {
        // Web platform - check WebAuthn support
        final webauthnSupported = WebAuthnService.isWebAuthnSupported();
        return {
          'biometricsSupported': webauthnSupported,
          'webauthnSupported': webauthnSupported,
          'platform': 'web',
          'availableBiometrics': webauthnSupported
              ? ['fingerprint', 'face', 'pin']
              : [],
        };
      } else {
        // Mobile platform - check local_auth support
        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final isDeviceSupported = await _localAuth.isDeviceSupported();

        List<String> availableBiometrics = [];
        if (canCheckBiometrics && isDeviceSupported) {
          final biometrics = await _localAuth.getAvailableBiometrics();
          availableBiometrics = biometrics.map((type) {
            switch (type) {
              case BiometricType.face:
                return 'face';
              case BiometricType.fingerprint:
                return 'fingerprint';
              case BiometricType.iris:
                return 'iris';
              case BiometricType.strong:
                return 'strong';
              case BiometricType.weak:
                return 'weak';
              default:
                return 'unknown';
            }
          }).toList();
        }

        return {
          'biometricsSupported': canCheckBiometrics && isDeviceSupported,
          'webauthnSupported': false,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'availableBiometrics': availableBiometrics,
        };
      }
    } catch (e) {
      return {
        'biometricsSupported': false,
        'webauthnSupported': false,
        'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
        'availableBiometrics': [],
        'error': e.toString(),
      };
    }
  }

  /// Setup biometric authentication for a user
  static Future<Map<String, dynamic>> setupBiometricAuthentication({
    required String userId,
    required String userName,
    required String userDisplayName,
    required String rpName,
    String? rpId,
  }) async {
    try {
      final supportCheck = await checkBiometricSupport();
      if (!supportCheck['biometricsSupported']) {
        return {
          'success': false,
          'error':
              'Biometric authentication not supported on this device/browser',
        };
      }

      if (kIsWeb) {
        // Web platform - use WebAuthn
        return await WebAuthnService.createCredential(
          userId: userId,
          userName: userName,
          userDisplayName: userDisplayName,
          rpName: rpName,
          rpId: rpId,
        );
      } else {
        // Mobile platform - use local_auth for setup
        // Note: local_auth doesn't have a direct "setup" method
        // We authenticate to verify biometrics work, then store the setup
        final authResult = await authenticateWithBiometrics(
          localizedReason: 'Setup biometric authentication for your wallet',
        );

        if (authResult['success']) {
          return {
            'success': true,
            'message': 'Biometric authentication setup successful',
            'platform': Platform.isAndroid ? 'android' : 'ios',
            'biometricTypes': supportCheck['availableBiometrics'],
          };
        } else {
          return {
            'success': false,
            'error': authResult['error'] ?? 'Biometric setup failed',
          };
        }
      }
    } catch (e) {
      return {'success': false, 'error': 'Biometric setup failed: $e'};
    }
  }

  /// Authenticate using biometrics
  static Future<Map<String, dynamic>> authenticateWithBiometrics({
    required String localizedReason,
    String? credentialId,
  }) async {
    try {
      final supportCheck = await checkBiometricSupport();
      if (!supportCheck['biometricsSupported']) {
        return {
          'success': false,
          'error': 'Biometric authentication not supported',
        };
      }

      if (kIsWeb) {
        // Web platform - use WebAuthn
        if (credentialId == null) {
          return {
            'success': false,
            'error': 'Credential ID required for WebAuthn authentication',
          };
        }

        return await WebAuthnService.authenticate(credentialId: credentialId);
      } else {
        // Mobile platform - use local_auth
        final authenticated = await _localAuth.authenticate(
          localizedReason: localizedReason,
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );

        if (authenticated) {
          return {
            'success': true,
            'message': 'Biometric authentication successful',
            'platform': Platform.isAndroid ? 'android' : 'ios',
          };
        } else {
          return {
            'success': false,
            'error': 'Biometric authentication failed or was cancelled',
          };
        }
      }
    } catch (e) {
      return {'success': false, 'error': 'Biometric authentication error: $e'};
    }
  }

  /// Get available biometric types
  static Future<List<String>> getAvailableBiometricTypes() async {
    try {
      final supportCheck = await checkBiometricSupport();
      return List<String>.from(supportCheck['availableBiometrics'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Check if biometrics are enrolled on the device
  static Future<bool> areBiometricsEnrolled() async {
    try {
      if (kIsWeb) {
        // For web, we can't easily check if biometrics are enrolled
        // WebAuthn will handle this during authentication
        return true;
      } else {
        final biometrics = await _localAuth.getAvailableBiometrics();
        return biometrics.isNotEmpty;
      }
    } catch (e) {
      return false;
    }
  }
}
