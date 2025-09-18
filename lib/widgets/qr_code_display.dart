import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';

class QRCodeDisplay extends StatelessWidget {
  final String address;
  final String title;

  const QRCodeDisplay({
    super.key,
    required this.address,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 350),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTheme.headingMedium.copyWith(
                    color: AppTheme.primaryGold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: address,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),

            const SizedBox(height: 16),

            // Address Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Address',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.white,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          color: AppTheme.primaryGold,
                          size: 16,
                        ),
                        onPressed: _copyAddress,
                        tooltip: 'Copy Address',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'How to Receive',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Share this QR code or address with the sender\n'
                    '• This address accepts both XLM and AKOFA tokens\n'
                    '• Make sure the sender has your AKOFA trustline if sending AKOFA',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: address));
    // Note: In a real app, you'd show a snackbar here
    // For now, we'll just copy silently
  }
}