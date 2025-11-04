import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/akofa_tag_service.dart';
import '../theme/app_theme.dart';

class AkofaTagPrompt extends StatefulWidget {
  final String userId;
  final String? firstName;
  final String? publicKey;
  final VoidCallback? onTagCreated;

  const AkofaTagPrompt({
    super.key,
    required this.userId,
    this.firstName,
    this.publicKey,
    this.onTagCreated,
  });

  @override
  State<AkofaTagPrompt> createState() => _AkofaTagPromptState();
}

class _AkofaTagPromptState extends State<AkofaTagPrompt> {
  bool _isCreating = false;
  String? _error;
  String? _successMessage;
  String? _generatedTag;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.tag, color: AppTheme.primaryGold, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Create AKOFA Tag',
                  style: AppTheme.headingMedium.copyWith(
                    color: AppTheme.primaryGold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              'An AKOFA tag makes it easy for others to send you payments. It\'s like a username for your wallet.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Tag Preview (if generated)
            if (_generatedTag != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGold.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Your AKOFA Tag',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generatedTag!,
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Create Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createTag,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: AppTheme.grey.withOpacity(0.3),
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _generatedTag != null ? 'Confirm Tag' : 'Create Tag',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.black,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Cancel Button
            TextButton(
              onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Skip for Now',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
            ),

            // Status Messages
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTheme.bodySmall.copyWith(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: AppTheme.bodySmall.copyWith(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createTag() async {
    // Get user info from Firebase Auth for fallback
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';
    final email = user?.email ?? '';

    String nameToUse = widget.firstName ?? '';

    // If widget firstName is empty, try display name
    if (nameToUse.isEmpty && displayName.isNotEmpty) {
      nameToUse = displayName
          .split(' ')
          .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    }

    // If still empty, use email prefix
    if (nameToUse.isEmpty && email.isNotEmpty) {
      nameToUse = email.split('@').first;
    }

    // Final fallback
    if (nameToUse.isEmpty) {
      setState(() {
        _error = 'Unable to create tag: No valid name or email available';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final result = await AkofaTagService.ensureUserHasTag(
        userId: widget.userId,
        firstName: nameToUse,
        email: email,
        publicKey: widget.publicKey,
      );

      if (result['success']) {
        setState(() {
          _generatedTag = result['tag'];
          _successMessage = result['message'];
        });

        // Call callback if provided
        widget.onTagCreated?.call();

        // Auto-close after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(_generatedTag);
        }
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to create AKOFA tag';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error creating tag: $e';
      });
    } finally {
      setState(() => _isCreating = false);
    }
  }
}

/// Utility function to show AKOFA tag prompt
Future<String?> showAkofaTagPrompt({
  required BuildContext context,
  required String userId,
  String? firstName,
  String? publicKey,
  VoidCallback? onTagCreated,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AkofaTagPrompt(
      userId: userId,
      firstName: firstName,
      publicKey: publicKey,
      onTagCreated: onTagCreated,
    ),
  );
}
