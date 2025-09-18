import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as app_transaction;
import '../theme/app_theme.dart';

class EnhancedTransactionList extends StatelessWidget {
  final List<app_transaction.Transaction> transactions;
  final Future<void> Function() onRefresh;

  const EnhancedTransactionList({
    super.key,
    required this.transactions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryGold,
      backgroundColor: AppTheme.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return _buildTransactionItem(transaction, context);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.swap_horiz,
            size: 64,
            color: AppTheme.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: AppTheme.headingMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.grey.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    app_transaction.Transaction transaction,
    BuildContext context,
  ) {
    final isIncoming = transaction.isIncoming;
    final amountColor = isIncoming ? Colors.green : Colors.red;
    final icon = _getTransactionIcon(transaction.type);
    final backgroundColor = _getTransactionBackgroundColor(transaction.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: amountColor, size: 20),
        ),
        title: Text(
          _getTransactionTitle(transaction),
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatTransactionDate(transaction.timestamp),
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 2),
            // Display sender/recipient with Akofa tags and addresses
            _buildSenderRecipientInfo(transaction),
            if (transaction.memo != null && transaction.memo!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Memo: ${transaction.memo}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryGold.withOpacity(0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (transaction.transactionHash != null) ...[
              const SizedBox(height: 2),
              Text(
                'Hash: ${_formatTransactionHash(transaction.transactionHash!)}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.grey.withOpacity(0.7),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
        trailing: SizedBox(
          width: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isIncoming ? '+' : '-'}${transaction.amount.toStringAsFixed(4)} ${transaction.assetCode}',
                style: AppTheme.bodyMedium.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _getStatusColor(transaction.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  transaction.statusLabel,
                  style: AppTheme.bodyTiny.copyWith(
                    color: _getStatusColor(transaction.status),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        onTap: () => _showTransactionDetails(context, transaction),
      ),
    );
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'send':
        return Icons.arrow_upward;
      case 'receive':
        return Icons.arrow_downward;
      case 'mining':
        return Icons.work;
      case 'buyAkofa':
        return Icons.shopping_cart;
      case 'swap':
        return Icons.swap_horiz;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _getTransactionBackgroundColor(String type) {
    switch (type) {
      case 'send':
        return Colors.red.withOpacity(0.2);
      case 'receive':
        return Colors.green.withOpacity(0.2);
      case 'mining':
        return AppTheme.primaryGold.withOpacity(0.2);
      case 'buyAkofa':
        return Colors.blue.withOpacity(0.2);
      case 'swap':
        return Colors.purple.withOpacity(0.2);
      default:
        return AppTheme.darkGrey.withOpacity(0.3);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return AppTheme.grey;
    }
  }

  String _getTransactionTitle(app_transaction.Transaction transaction) {
    switch (transaction.type) {
      case 'send':
        return 'Sent ${transaction.assetCode}';
      case 'receive':
        return 'Received ${transaction.assetCode}';
      case 'mining':
        return 'Mining Reward';
      case 'buyAkofa':
        return 'Bought AKOFA';
      case 'swap':
        return 'Asset Swap';
      default:
        return transaction.typeLabel;
    }
  }

  String _formatTransactionDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    }
  }

  String _formatTransactionHash(String hash) {
    if (hash.length <= 12) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 6)}';
  }

  Widget _buildSenderRecipientInfo(app_transaction.Transaction transaction) {
    final isIncoming = transaction.isIncoming;

    if (isIncoming) {
      // For incoming transactions, show sender info
      final senderTag = transaction.senderAkofaTag;
      final senderAddress = transaction.senderAddress;

      if (senderTag != null && senderTag.isNotEmpty) {
        return Row(
          children: [
            Text(
              'From: ',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.grey.withOpacity(0.8),
              ),
            ),
            Expanded(
              child: Text(
                senderTag,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (senderAddress != null && senderAddress.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                '(${_formatAddress(senderAddress)})',
                style: AppTheme.bodyTiny.copyWith(
                  color: AppTheme.grey.withOpacity(0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      } else if (senderAddress != null && senderAddress.isNotEmpty) {
        return Text(
          'From: ${_formatAddress(senderAddress)}',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.grey.withOpacity(0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    } else {
      // For outgoing transactions, show recipient info
      final recipientTag = transaction.recipientAkofaTag;
      final recipientAddress = transaction.recipientAddress;

      if (recipientTag != null && recipientTag.isNotEmpty) {
        return Row(
          children: [
            Text(
              'To: ',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.grey.withOpacity(0.8),
              ),
            ),
            Expanded(
              child: Text(
                recipientTag,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (recipientAddress != null && recipientAddress.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                '(${_formatAddress(recipientAddress)})',
                style: AppTheme.bodyTiny.copyWith(
                  color: AppTheme.grey.withOpacity(0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      } else if (recipientAddress != null && recipientAddress.isNotEmpty) {
        return Text(
          'To: ${_formatAddress(recipientAddress)}',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.grey.withOpacity(0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    }

    return const SizedBox.shrink();
  }

  String _formatAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  void _showTransactionDetails(
    BuildContext context,
    app_transaction.Transaction transaction,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction Details',
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
            const SizedBox(height: 16),

            // Transaction Type and Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getTransactionBackgroundColor(transaction.type),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTransactionIcon(transaction.type),
                    color: transaction.isIncoming ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTransactionTitle(transaction),
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        transaction.statusLabel,
                        style: AppTheme.bodySmall.copyWith(
                          color: _getStatusColor(transaction.status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Amount
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  ),
                  Text(
                    '${transaction.isIncoming ? '+' : '-'}${transaction.amount} ${transaction.assetCode}',
                    style: AppTheme.bodyLarge.copyWith(
                      color: transaction.isIncoming ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Transaction Details
            _buildDetailRow(
              'Date',
              _formatTransactionDate(transaction.timestamp),
            ),
            _buildDetailRow('Type', transaction.typeLabel),
            _buildDetailRow('Asset', transaction.assetCode),

            if (transaction.memo != null && transaction.memo!.isNotEmpty)
              _buildDetailRow('Memo', transaction.memo!),

            // Enhanced sender/recipient display with both tags and addresses
            if (transaction.isIncoming) ...[
              if (transaction.senderAkofaTag != null ||
                  transaction.senderAddress != null)
                _buildEnhancedAddressRow(
                  'From',
                  transaction.senderAkofaTag,
                  transaction.senderAddress,
                ),
            ] else ...[
              if (transaction.recipientAkofaTag != null ||
                  transaction.recipientAddress != null)
                _buildEnhancedAddressRow(
                  'To',
                  transaction.recipientAkofaTag,
                  transaction.recipientAddress,
                ),
            ],

            if (transaction.transactionHash != null) ...[
              const SizedBox(height: 16),
              Text(
                'Transaction Hash',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction.transactionHash!,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.white,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedAddressRow(String label, String? tag, String? address) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag != null && tag.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.tag, size: 14, color: AppTheme.primaryGold),
                      const SizedBox(width: 4),
                      Text(
                        'Tag: $tag',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (address != null && address.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 14,
                        color: AppTheme.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Address: $address',
                          style: AppTheme.bodyTiny.copyWith(
                            color: AppTheme.white,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
