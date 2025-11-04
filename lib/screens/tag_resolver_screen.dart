import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../services/akofa_tag_service.dart';

class TagResolverScreen extends StatefulWidget {
  const TagResolverScreen({super.key});

  @override
  State<TagResolverScreen> createState() => _TagResolverScreenState();
}

class _TagResolverScreenState extends State<TagResolverScreen> {
  String _result = 'Tap the button to resolve tag "david9736"';
  bool _isLoading = false;

  Future<void> _resolveTag() async {
    setState(() {
      _isLoading = true;
      _result = 'Resolving tag...';
    });

    try {
      // Ensure Firebase is initialized
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final result = await AkofaTagService.resolveTag('david9736');

      if (result['success'] == true) {
        setState(() {
          _result =
              '''
✅ Tag resolved successfully!

🏷️  Tag: ${result['tag']}
👤 User ID: ${result['userId']}
📛 First Name: ${result['firstName']}
🏦 Wallet Address (Public Key): ${result['publicKey']}
          ''';
        });
      } else {
        setState(() {
          _result = '❌ Tag resolution failed!\n\n📋 Error: ${result['error']}';
        });
      }
    } catch (e) {
      setState(() {
        _result = '❌ Error during tag resolution: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akofa Tag Resolver')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Resolve Akofa Tag: david9736',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _resolveTag,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Resolve Tag'),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result,
                style: const TextStyle(fontFamily: 'monospace'),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
