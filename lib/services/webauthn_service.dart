import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;

// JavaScript interop for WebAuthn API
@JS('navigator.credentials')
external dynamic get credentials;

@JS()
@anonymous
class PublicKeyCredentialCreationOptions {
  external factory PublicKeyCredentialCreationOptions({
    required Uint8List challenge,
    required PublicKeyCredentialRpEntity rp,
    required PublicKeyCredentialUserEntity user,
    required List<PublicKeyCredentialParameters> pubKeyCredParams,
    int? timeout,
    List<PublicKeyCredentialDescriptor>? excludeCredentials,
    AuthenticatorSelectionCriteria? authenticatorSelection,
    String? attestation,
    AuthenticationExtensionsClientInputs? extensions,
  });
}

@JS()
@anonymous
class PublicKeyCredentialRpEntity {
  external factory PublicKeyCredentialRpEntity({
    required String name,
    String? id,
  });
}

@JS()
@anonymous
class PublicKeyCredentialUserEntity {
  external factory PublicKeyCredentialUserEntity({
    required Uint8List id,
    required String name,
    required String displayName,
  });
}

@JS()
@anonymous
class PublicKeyCredentialParameters {
  external factory PublicKeyCredentialParameters({
    required int type,
    required int alg,
  });
}

@JS()
@anonymous
class AuthenticatorSelectionCriteria {
  external factory AuthenticatorSelectionCriteria({
    String? authenticatorAttachment,
    bool? requireResidentKey,
    String? userVerification,
  });
}

@JS()
@anonymous
class PublicKeyCredentialDescriptor {
  external factory PublicKeyCredentialDescriptor({
    required String type,
    required Uint8List id,
    List<String>? transports,
  });
}

@JS()
@anonymous
class AuthenticationExtensionsClientInputs {
  external factory AuthenticationExtensionsClientInputs();
}

@JS()
@staticInterop
class PublicKeyCredential {}

extension PublicKeyCredentialExtension on PublicKeyCredential {
  external Uint8List get rawId;
  external AuthenticatorResponse get response;
  external String get type;
}

@JS()
@staticInterop
class AuthenticatorResponse {}

extension AuthenticatorResponseExtension on AuthenticatorResponse {
  external Uint8List get clientDataJSON;
  external Uint8List get authenticatorData;
  external Uint8List get signature;
  external Uint8List? get userHandle;
}

@JS()
@staticInterop
class AuthenticatorAttestationResponse {}

extension AuthenticatorAttestationResponseExtension
    on AuthenticatorAttestationResponse {
  external Uint8List get attestationObject;
  Uint8List get clientDataJSON => js_util.getProperty(this, 'clientDataJSON');
  Uint8List get authenticatorData =>
      js_util.getProperty(this, 'authenticatorData');
  Uint8List get signature => js_util.getProperty(this, 'signature');
  Uint8List? get userHandle => js_util.getProperty(this, 'userHandle');
}

@JS()
@staticInterop
class AuthenticatorAssertionResponse {}

extension AuthenticatorAssertionResponseExtension
    on AuthenticatorAssertionResponse {
  external Uint8List get signature;
  external Uint8List get userHandle;
  Uint8List get clientDataJSON => js_util.getProperty(this, 'clientDataJSON');
  Uint8List get authenticatorData =>
      js_util.getProperty(this, 'authenticatorData');
}

@JS()
@anonymous
class PublicKeyCredentialRequestOptions {
  external factory PublicKeyCredentialRequestOptions({
    required Uint8List challenge,
    int? timeout,
    String? rpId,
    List<PublicKeyCredentialDescriptor>? allowCredentials,
    String? userVerification,
    AuthenticationExtensionsClientInputs? extensions,
  });
}

/// WebAuthn service for biometric authentication on web platforms
class WebAuthnService {
  /// Check if WebAuthn is supported in the current browser
  static bool isWebAuthnSupported() {
    try {
      return js_util.hasProperty(js_util.globalThis, 'navigator') &&
          js_util.hasProperty(
            js_util.getProperty(js_util.globalThis, 'navigator'),
            'credentials',
          ) &&
          js_util.hasProperty(
            js_util.getProperty(
              js_util.getProperty(js_util.globalThis, 'navigator'),
              'credentials',
            ),
            'create',
          ) &&
          js_util.hasProperty(
            js_util.getProperty(
              js_util.getProperty(js_util.globalThis, 'navigator'),
              'credentials',
            ),
            'get',
          );
    } catch (e) {
      return false;
    }
  }

  /// Create a new WebAuthn credential for biometric registration
  static Future<Map<String, dynamic>> createCredential({
    required String userId,
    required String userName,
    required String userDisplayName,
    required String rpName,
    String? rpId,
  }) async {
    try {
      if (!isWebAuthnSupported()) {
        throw Exception('WebAuthn is not supported in this browser');
      }

      // Generate cryptographically secure challenge
      final challenge = _generateChallenge();

      // Create user entity
      final userIdBytes = utf8.encode(userId) as Uint8List;
      final userEntity = PublicKeyCredentialUserEntity(
        id: userIdBytes,
        name: userName,
        displayName: userDisplayName,
      );

      // Create relying party entity
      final rpEntity = PublicKeyCredentialRpEntity(name: rpName, id: rpId);

      // Define supported algorithms (ES256, RS256)
      final pubKeyCredParams = [
        PublicKeyCredentialParameters(type: -7, alg: -7), // ES256
        PublicKeyCredentialParameters(type: -7, alg: -257), // RS256
      ];

      // Create authenticator selection criteria
      final authenticatorSelection = AuthenticatorSelectionCriteria(
        authenticatorAttachment:
            'platform', // Prefer platform authenticators (biometrics)
        userVerification: 'required', // Require user verification
        requireResidentKey: false,
      );

      // Create credential creation options
      final options = PublicKeyCredentialCreationOptions(
        challenge: challenge,
        rp: rpEntity,
        user: userEntity,
        pubKeyCredParams: pubKeyCredParams,
        authenticatorSelection: authenticatorSelection,
        timeout: 60000, // 60 seconds
        attestation: 'direct',
      );

      // Call WebAuthn create API
      final credential = await js_util.promiseToFuture<PublicKeyCredential>(
        js_util.callMethod(credentials, 'create', [
          js_util.jsify({'publicKey': options}),
        ]),
      );

      // Extract credential data
      final response = credential.response as AuthenticatorAttestationResponse;
      final credentialId = base64UrlEncode(credential.rawId);
      final attestationObject = base64UrlEncode(response.attestationObject);
      final clientDataJSON = base64UrlEncode(response.clientDataJSON);

      return {
        'success': true,
        'credentialId': credentialId,
        'attestationObject': attestationObject,
        'clientDataJSON': clientDataJSON,
        'challenge': base64UrlEncode(challenge),
        'userId': base64UrlEncode(userIdBytes),
        'publicKey': _extractPublicKeyFromAttestationObject(
          response.attestationObject,
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'WebAuthn credential creation failed: $e',
      };
    }
  }

  /// Authenticate using WebAuthn
  static Future<Map<String, dynamic>> authenticate({
    required String credentialId,
    String? rpId,
  }) async {
    try {
      if (!isWebAuthnSupported()) {
        throw Exception('WebAuthn is not supported in this browser');
      }

      // Generate new challenge for authentication
      final challenge = _generateChallenge();

      // Decode credential ID
      final credentialIdBytes = base64UrlDecode(credentialId);

      // Create credential descriptor
      final allowCredentials = [
        PublicKeyCredentialDescriptor(
          type: 'public-key',
          id: credentialIdBytes,
        ),
      ];

      // Create authentication options
      final options = PublicKeyCredentialRequestOptions(
        challenge: challenge,
        timeout: 60000, // 60 seconds
        rpId: rpId,
        allowCredentials: allowCredentials,
        userVerification: 'required',
      );

      // Call WebAuthn get API
      final assertion = await js_util.promiseToFuture<PublicKeyCredential>(
        js_util.callMethod(credentials, 'get', [
          js_util.jsify({'publicKey': options}),
        ]),
      );

      // Extract assertion data
      final response = assertion.response as AuthenticatorAssertionResponse;
      final authenticatorData = base64UrlEncode(response.authenticatorData);
      final clientDataJSON = base64UrlEncode(response.clientDataJSON);
      final signature = base64UrlEncode(response.signature);
      final userHandle = response.userHandle != null
          ? base64UrlEncode(response.userHandle!)
          : null;

      return {
        'success': true,
        'credentialId': base64UrlEncode(assertion.rawId),
        'authenticatorData': authenticatorData,
        'clientDataJSON': clientDataJSON,
        'signature': signature,
        'userHandle': userHandle,
        'challenge': base64UrlEncode(challenge),
      };
    } catch (e) {
      return {'success': false, 'error': 'WebAuthn authentication failed: $e'};
    }
  }

  /// Generate a cryptographically secure challenge
  static Uint8List _generateChallenge() {
    final random = Random.secure();
    final challenge = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      challenge[i] = random.nextInt(256);
    }
    return challenge;
  }

  /// Extract public key from attestation object (simplified)
  static String _extractPublicKeyFromAttestationObject(
    Uint8List attestationObject,
  ) {
    // In a real implementation, you would parse the CBOR attestation object
    // and extract the public key. For now, return a placeholder.
    // This would require a CBOR parsing library.
    return 'placeholder_public_key';
  }
}

/// Base64 URL encoding/decoding utilities
String base64UrlEncode(Uint8List bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

Uint8List base64UrlDecode(String str) {
  // Add padding if necessary
  String padded = str;
  while (padded.length % 4 != 0) {
    padded += '=';
  }
  return base64Url.decode(padded);
}
