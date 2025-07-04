import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;

  const TransactionList({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine layout based on screen size
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final isLargeDesktop = ResponsiveLayout.isLargeDesktop(context);
    final isWebPlatform = kIsWeb;
    
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: isDesktop ? 64 : 48,
                color: AppTheme.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions yet!', 
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.grey,
                  fontSize: isDesktop ? 20 : null,
                )
              ),
              if (isDesktop) const SizedBox(height: 8),
              if (isDesktop)
                Text(
                  'Your transaction history will appear here',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.grey.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      );
    }
    
    return isDesktop 
        ? _buildDesktopTransactionList(context)
        : _buildMobileTabletTransactionList(context, isTablet);
  }
  
  Widget _buildDesktopTransactionList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: transactions.length,
          separatorBuilder: (context, index) => Divider(
            height: 1, 
            color: AppTheme.grey.withOpacity(0.2),
          ),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: tx.assetCode == 'XLM' 
                    ? AppTheme.primaryGold 
                    : tx.assetCode == 'AKOFA' 
                        ? Colors.purple 
                        : Colors.blue,
                child: Text(
                  tx.assetCode ?? '', 
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.black,
                    fontWeight: FontWeight.bold,
                  )
                ),
              ),
              title: Row(
                children: [
                  Text(
                    (tx.type == TransactionType.send ? '- ' : '+ ') + tx.amount.toString(),
                    style: AppTheme.headingMedium.copyWith(
                      color: tx.type == TransactionType.send ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tx.assetCode ?? '',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(tx.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tx.status.toString().split('.').last,
                        style: AppTheme.bodySmall.copyWith(
                          color: _getStatusColor(tx.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tx.timestamp.toString(),
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                    ),
                  ],
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.chevron_right, color: AppTheme.primaryGold, size: 28),
                onPressed: () {
                  _showTransactionDetailsDialog(context, tx);
                },
              ),
              onTap: () {
                _showTransactionDetailsDialog(context, tx);
              },
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildMobileTabletTransactionList(BuildContext context, bool isTablet) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1, 
        color: AppTheme.grey.withOpacity(0.3),
      ),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16 : 8, 
            vertical: isTablet ? 8 : 4,
          ),
          leading: CircleAvatar(
            radius: isTablet ? 22 : 20,
            backgroundColor: tx.assetCode == 'XLM' 
                ? AppTheme.primaryGold 
                : tx.assetCode == 'AKOFA' 
                    ? Colors.purple 
                    : Colors.blue,
            child: Text(
              tx.assetCode ?? '', 
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.black,
                fontWeight: FontWeight.bold,
              )
            ),
          ),
          title: Text(
            (tx.type == TransactionType.send ? '- ' : '+ ') + tx.amount.toString() + ' ' + (tx.assetCode ?? ''),
            style: AppTheme.bodyLarge.copyWith(
              color: tx.type == TransactionType.send ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 18 : null,
            ),
          ),
          subtitle: Text(
            tx.status.toString().split('.').last + ' • ' + tx.timestamp.toString(),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey,
              fontSize: isTablet ? 14 : null,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.chevron_right, color: AppTheme.primaryGold, size: 24),
            onPressed: () {
              _showTransactionDetailsDialog(context, tx);
            },
          ),
          onTap: () {
            _showTransactionDetailsDialog(context, tx);
          },
        );
      },
    );
  }
  
  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
        return Colors.red;
      default:
        return AppTheme.grey;
    }
  }

  void _showTransactionDetailsDialog(BuildContext context, Transaction tx) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            tx.typeLabel,
            style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Amount', tx.amount.toString() + ' ' + tx.assetCode),
                _detailRow('Status', tx.statusLabel),
                _detailRow('Date', tx.timestamp.toString()),
                _detailRow('Sender', tx.senderAddress),
                _detailRow('Recipient', tx.recipientAddress),
                if (tx.memo != null && tx.memo!.isNotEmpty)
                  _detailRow('Memo', tx.memo!),
                if (tx.hash != null && tx.hash!.isNotEmpty)
                  _detailRow('Transaction Hash', tx.hash!),
                const SizedBox(height: 16),
                if (tx.hash != null && tx.hash!.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: AppTheme.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View on Stellar Explorer'),
                      onPressed: () {
                        _launchUrl(context, tx.hash!);
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close', style: TextStyle(color: AppTheme.primaryGold)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey)),
          Expanded(
            child: Text(value, style: AppTheme.bodyMedium.copyWith(color: AppTheme.white)),
          ),
        ],
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch Stellar Explorer.')),
      );
    }
  }
} 