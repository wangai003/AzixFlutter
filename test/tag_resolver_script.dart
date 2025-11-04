import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';
import 'package:azixflutter/services/akofa_tag_service.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('🔍 Resolving Akofa Tag: david9736');

  try {
    final result = await AkofaTagService.resolveTag('david9736');

    if (result['success'] == true) {
      print('✅ Tag resolved successfully!');
      print('🏷️  Tag: ${result['tag']}');
      print('👤 User ID: ${result['userId']}');
      print('📛 First Name: ${result['firstName']}');
      print('🏦 Wallet Address (Public Key): ${result['publicKey']}');
    } else {
      print('❌ Tag resolution failed!');
      print('📋 Error: ${result['error']}');
    }
  } catch (e) {
    print('❌ Error during tag resolution: $e');
  }

  print('🎉 Tag resolution completed!');
}
