import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// IPFS service for storing extended raffle metadata
class IPFSService {
  // Using Pinata or Infura IPFS gateway - replace with your preferred service
  static const String _pinataApiKey = 'YOUR_PINATA_API_KEY'; // Add to secrets
  static const String _pinataSecretKey =
      'YOUR_PINATA_SECRET_KEY'; // Add to secrets
  static const String _pinataGateway = 'https://gateway.pinata.cloud/ipfs/';
  static const String _pinataApiUrl =
      'https://api.pinata.cloud/pinning/pinJSONToIPFS';

  // Alternative: Use Infura
  static const String _infuraProjectId =
      'YOUR_INFURA_PROJECT_ID'; // Add to secrets
  static const String _infuraProjectSecret =
      'YOUR_INFURA_PROJECT_SECRET'; // Add to secrets
  static const String _infuraGateway = 'https://ipfs.infura.io/ipfs/';

  /// Upload raffle metadata to IPFS
  static Future<String?> uploadRaffleMetadata({
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_pinataApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'pinata_api_key': _pinataApiKey,
          'pinata_secret_api_key': _pinataSecretKey,
        },
        body: jsonEncode(metadata),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['IpfsHash'];
      } else {
        print('Failed to upload to IPFS: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading to IPFS: $e');
      return null;
    }
  }

  /// Upload file to IPFS
  static Future<String?> uploadFile({
    required Uint8List fileData,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final uri = Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'pinata_api_key': _pinataApiKey,
          'pinata_secret_api_key': _pinataSecretKey,
        })
        ..files.add(
          http.MultipartFile.fromBytes('file', fileData, filename: fileName),
        );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        return data['IpfsHash'];
      } else {
        print('Failed to upload file to IPFS: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading file to IPFS: $e');
      return null;
    }
  }

  /// Retrieve data from IPFS
  static Future<Map<String, dynamic>?> getMetadata(String ipfsHash) async {
    try {
      final response = await http.get(Uri.parse('$_pinataGateway$ipfsHash'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to retrieve from IPFS: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error retrieving from IPFS: $e');
      return null;
    }
  }

  /// Get IPFS gateway URL for a hash
  static String getGatewayUrl(String ipfsHash) {
    return '$_pinataGateway$ipfsHash';
  }

  /// Create comprehensive raffle metadata for IPFS
  static Map<String, dynamic> createRaffleIPFSMetadata({
    required String raffleId,
    required String title,
    required String description,
    String? detailedDescription,
    required String creatorId,
    required String creatorName,
    required Map<String, dynamic> entryRequirements,
    required Map<String, dynamic> prizeDetails,
    required int maxEntries,
    required DateTime startDate,
    required DateTime endDate,
    List<String>? galleryImages,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return {
      'version': '1.0',
      'type': 'raffle_metadata',
      'raffleId': raffleId,
      'title': title,
      'description': description,
      'detailedDescription': detailedDescription,
      'creator': {'id': creatorId, 'name': creatorName},
      'entryRequirements': entryRequirements,
      'prizeDetails': prizeDetails,
      'constraints': {
        'maxEntries': maxEntries,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
      'galleryImages': galleryImages ?? [],
      'additionalMetadata': additionalMetadata ?? {},
      'createdAt': DateTime.now().toIso8601String(),
      'schema': {
        'name': 'AzixFlutter Raffle Metadata',
        'description': 'Extended metadata for raffle system',
        'properties': {
          'title': {'type': 'string'},
          'description': {'type': 'string'},
          'detailedDescription': {'type': 'string'},
          'creator': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'name': {'type': 'string'},
            },
          },
          'entryRequirements': {'type': 'object'},
          'prizeDetails': {'type': 'object'},
          'constraints': {'type': 'object'},
          'galleryImages': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
      },
    };
  }

  /// Validate IPFS hash format
  static bool isValidIPFSHash(String hash) {
    // IPFS hashes start with 'Qm' for CIDv0 or 'bafy' for CIDv1
    return hash.startsWith('Qm') || hash.startsWith('bafy');
  }

  /// Pin content to ensure persistence
  static Future<bool> pinContent(String ipfsHash) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.pinata.cloud/pinning/pinByHash'),
        headers: {
          'Content-Type': 'application/json',
          'pinata_api_key': _pinataApiKey,
          'pinata_secret_api_key': _pinataSecretKey,
        },
        body: jsonEncode({'hashToPin': ipfsHash}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error pinning content: $e');
      return false;
    }
  }
}
