import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/moonpay_service.dart';

class MoonPayTransactionStatusIndicator extends StatelessWidget {
  final String status;
  final double? amount;
  final String? currency;
  final VoidCallback? onRefresh;

  const MoonPayTransactionStatusIndicator({
    super.key,
    required this.status,
    this.amount,
    this.currency,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = MoonPayService.getTransactionStatusInfo(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(statusInfo['color'] as String),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(statusInfo['color'] as String),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: _getIconColor(statusInfo['color'] as String),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusInfo['label'] as String,
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (amount != null && currency != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${amount!.toStringAsFixed(4)} $currency',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onRefresh != null && _shouldShowRefresh(status)) ...[
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
                  onPressed: onRefresh,
                  tooltip: 'Check status',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusInfo['description'] as String,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey.withOpacity(0.8),
            ),
          ),
          if (_isPendingStatus(status)) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              backgroundColor: AppTheme.darkGrey,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(statusInfo['color'] as String),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBorderColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green.withOpacity(0.5);
      case 'red':
        return Colors.red.withOpacity(0.5);
      case 'orange':
        return Colors.orange.withOpacity(0.5);
      case 'blue':
        return Colors.blue.withOpacity(0.5);
      case 'gray':
        return AppTheme.grey.withOpacity(0.5);
      default:
        return AppTheme.primaryGold.withOpacity(0.5);
    }
  }

  Color _getBackgroundColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green.withOpacity(0.2);
      case 'red':
        return Colors.red.withOpacity(0.2);
      case 'orange':
        return Colors.orange.withOpacity(0.2);
      case 'blue':
        return Colors.blue.withOpacity(0.2);
      case 'gray':
        return AppTheme.darkGrey.withOpacity(0.3);
      default:
        return AppTheme.primaryGold.withOpacity(0.2);
    }
  }

  Color _getIconColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case 'gray':
        return AppTheme.grey;
      default:
        return AppTheme.primaryGold;
    }
  }

  Color _getProgressColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case 'gray':
        return AppTheme.grey;
      default:
        return AppTheme.primaryGold;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'waitingPayment':
        return Icons.payment;
      case 'pending':
        return Icons.hourglass_empty;
      case 'waitingAuthorization':
        return Icons.verified_user;
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  bool _shouldShowRefresh(String status) {
    return status == 'waitingPayment' ||
        status == 'pending' ||
        status == 'waitingAuthorization';
  }

  bool _isPendingStatus(String status) {
    return status == 'waitingPayment' ||
        status == 'pending' ||
        status == 'waitingAuthorization';
  }
}

class MoonPayTransactionHistory extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final VoidCallback? onRefresh;

  const MoonPayTransactionHistory({
    super.key,
    required this.transactions,
    this.onRefresh,
  });

  Future<void> _defaultRefresh() async {
    // Default empty refresh function
  }

  static Future<void> _staticDefaultRefresh() async {
    // Static default refresh function
  }

  Future<void> _instanceDefaultRefresh() async {
    // Instance default refresh function
  }

  static Future<void> get defaultRefresh => _staticDefaultRefresh();

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: AppTheme.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No MoonPay transactions',
              style: AppTheme.headingMedium.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Your MoonPay purchase history will appear here',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildTransactionItem(transaction, context);
      },
    );
  }

  Widget _buildTransactionItem(
    Map<String, dynamic> transaction,
    BuildContext context,
  ) {
    final status = transaction['status'] ?? 'unknown';
    final amount = transaction['quoteCurrencyAmount'] ?? 0.0;
    final currency = transaction['currency']?['code'] ?? 'XLM';
    final createdAt = transaction['createdAt'];

    DateTime? dateTime;
    if (createdAt is DateTime) {
      dateTime = createdAt;
    } else if (createdAt is String) {
      dateTime = DateTime.tryParse(createdAt);
    }

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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusBackgroundColor(status),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusIconColor(status),
            size: 20,
          ),
        ),
        title: Text(
          'MoonPay Purchase',
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
              dateTime != null ? _formatDate(dateTime) : 'Unknown date',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusBackgroundColor(status).withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                MoonPayService.getTransactionStatusInfo(status)['label']
                    as String,
                style: AppTheme.bodyTiny.copyWith(
                  color: _getStatusIconColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          '${amount.toStringAsFixed(4)} $currency',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => _showTransactionDetails(context, transaction),
      ),
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    Map<String, dynamic> transaction,
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
                  'MoonPay Transaction Details',
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

            // Status indicator
            MoonPayTransactionStatusIndicator(
              status: transaction['status'] ?? 'unknown',
              amount: transaction['quoteCurrencyAmount']?.toDouble(),
              currency: transaction['currency']?['code'],
            ),

            const SizedBox(height: 16),

            // Transaction details
            _buildDetailRow('Transaction ID', transaction['id'] ?? 'N/A'),
            _buildDetailRow(
              'Amount',
              '${transaction['quoteCurrencyAmount'] ?? 0} ${transaction['currency']?['code'] ?? 'XLM'}',
            ),
            _buildDetailRow(
              'Base Amount',
              '${transaction['baseCurrencyAmount'] ?? 0} ${transaction['baseCurrencyCode'] ?? 'USD'}',
            ),

            if (transaction['createdAt'] != null) ...[
              _buildDetailRow(
                'Created',
                _formatDateTime(transaction['createdAt']),
              ),
            ],

            if (transaction['updatedAt'] != null) ...[
              _buildDetailRow(
                'Updated',
                _formatDateTime(transaction['updatedAt']),
              ),
            ],

            if (transaction['failureReason'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Failure Reason',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.red),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction['failureReason'],
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime is DateTime) {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (dateTime is String) {
      final parsed = DateTime.tryParse(dateTime);
      if (parsed != null) {
        return '${parsed.month}/${parsed.day}/${parsed.year} ${parsed.hour}:${parsed.minute.toString().padLeft(2, '0')}';
      }
    }
    return dateTime.toString();
  }

  Color _getStatusBackgroundColor(String status) {
    final statusInfo = MoonPayService.getTransactionStatusInfo(status);
    final colorName = statusInfo['color'] as String;

    switch (colorName) {
      case 'green':
        return Colors.green.withOpacity(0.2);
      case 'red':
        return Colors.red.withOpacity(0.2);
      case 'orange':
        return Colors.orange.withOpacity(0.2);
      case 'blue':
        return Colors.blue.withOpacity(0.2);
      case 'gray':
        return AppTheme.darkGrey.withOpacity(0.3);
      default:
        return AppTheme.primaryGold.withOpacity(0.2);
    }
  }

  Color _getStatusIconColor(String status) {
    final statusInfo = MoonPayService.getTransactionStatusInfo(status);
    final colorName = statusInfo['color'] as String;

    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case 'gray':
        return AppTheme.grey;
      default:
        return AppTheme.primaryGold;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'waitingPayment':
        return Icons.payment;
      case 'pending':
        return Icons.hourglass_empty;
      case 'waitingAuthorization':
        return Icons.verified_user;
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}
