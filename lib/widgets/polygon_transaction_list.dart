import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Modern transaction list widget for Polygon/Alchemy transactions
/// Works directly with transaction maps from the Alchemy API
class PolygonTransactionList extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final Future<void> Function() onRefresh;
  final String? userAddress;

  const PolygonTransactionList({
    super.key,
    required this.transactions,
    required this.onRefresh,
    this.userAddress,
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
          final tx = transactions[index];
          return _buildTransactionCard(context, tx);
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
            Icons.receipt_long,
            size: 80,
            color: AppTheme.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No Transactions Yet',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your Polygon transaction history\nwill appear here',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> tx) {
    // Extract transaction data with safe defaults
    final hash = tx['hash'] as String? ?? 'Unknown';
    final from = tx['from'] as String? ?? '';
    final to = tx['to'] as String? ?? '';
    final value = (tx['value'] as num? ?? 0).toDouble();
    final asset = tx['asset'] as String? ?? 'MATIC';
    final type = tx['type'] as String? ?? 'send';
    final status = tx['status'] as String? ?? 'success';
    final timestamp = tx['timestamp'] as DateTime? ?? DateTime.now();
    final network = tx['network'] as String? ?? 'polygon';

    // Determine if incoming or outgoing
    final isIncoming = type == 'receive';
    final amountColor = isIncoming ? Colors.green : Colors.red;
    final amountPrefix = isIncoming ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTransactionDetails(context, tx),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Transaction icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: amountColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTransactionIcon(type),
                    color: amountColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Transaction details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type and asset
                      Row(
                        children: [
                          Text(
                            _getTransactionTitle(type, asset),
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // Address or timestamp
                      Text(
                        isIncoming 
                            ? 'From: ${_formatAddress(from)}'
                            : 'To: ${_formatAddress(to)}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Time
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppTheme.grey.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(timestamp),
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.grey.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$amountPrefix$value',
                      style: AppTheme.bodyLarge.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      asset,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isSuccess = status == 'success';
    final color = isSuccess ? Colors.green : Colors.orange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'receive':
        return Icons.arrow_downward_rounded;
      case 'send':
        return Icons.arrow_upward_rounded;
      case 'self':
        return Icons.sync_alt_rounded;
      case 'contract':
        return Icons.description_outlined;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  String _getTransactionTitle(String type, String asset) {
    switch (type) {
      case 'receive':
        return 'Received $asset';
      case 'send':
        return 'Sent $asset';
      case 'self':
        return 'Self Transfer';
      case 'contract':
        return 'Contract Interaction';
      default:
        return '$asset Transaction';
    }
  }

  String _formatAddress(String address) {
    if (address.isEmpty) return 'Unknown';
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> tx) {
    // Extract all transaction details
    final hash = tx['hash'] as String? ?? 'Unknown';
    final from = tx['from'] as String? ?? 'Unknown';
    final to = tx['to'] as String? ?? 'Unknown';
    final value = (tx['value'] as num? ?? 0).toDouble();
    final asset = tx['asset'] as String? ?? 'MATIC';
    final tokenName = tx['tokenName'] as String? ?? asset;
    final type = tx['type'] as String? ?? 'send';
    final status = tx['status'] as String? ?? 'success';
    final timestamp = tx['timestamp'] as DateTime? ?? DateTime.now();
    final blockNumber = tx['blockNumber'] as int? ?? 0;
    final gasUsed = tx['gasUsed'] as int? ?? 0;
    final gasPrice = tx['gasPrice'] as int? ?? 0;
    final network = tx['network'] as String? ?? 'polygon';
    final contractAddress = tx['contractAddress'] as String? ?? '';
    
    final isIncoming = type == 'receive';
    final amountColor = isIncoming ? Colors.green : Colors.red;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.darkGrey,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: amountColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTransactionIcon(type),
                      color: amountColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTransactionTitle(type, asset),
                          style: AppTheme.headingMedium.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildStatusBadge(status),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Amount highlight
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: amountColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: amountColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Amount',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${isIncoming ? '+' : '-'}$value',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tokenName,
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Transaction details
              _buildDetailSection('Transaction Details', [
                _buildDetailRow(
                  context,
                  'Network',
                  network.toUpperCase(),
                  icon: Icons.public,
                ),
                _buildDetailRow(
                  context,
                  'Date & Time',
                  DateFormat('MMM dd, yyyy • HH:mm:ss').format(timestamp),
                  icon: Icons.access_time,
                ),
                _buildDetailRow(
                  context,
                  'Block Number',
                  '#$blockNumber',
                  icon: Icons.widgets,
                ),
                if (gasUsed > 0)
                  _buildDetailRow(
                    context,
                    'Gas Used',
                    gasUsed.toString(),
                    icon: Icons.local_gas_station,
                  ),
              ]),
              
              const SizedBox(height: 20),
              
              // Addresses
              _buildDetailSection('Addresses', [
                _buildAddressRow(context, 'From', from),
                _buildAddressRow(context, 'To', to),
                if (contractAddress.isNotEmpty)
                  _buildAddressRow(context, 'Contract', contractAddress),
              ]),
              
              const SizedBox(height: 20),
              
              // Transaction Hash
              _buildDetailSection('Transaction Hash', [
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: hash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Transaction hash copied!'),
                        backgroundColor: AppTheme.primaryGold,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryGold.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            hash,
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy,
                          size: 16,
                          color: AppTheme.primaryGold,
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
              
              const SizedBox(height: 24),
              
              // View on Explorer button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Open block explorer
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening in ${network == 'polygon-amoy' ? 'Amoy' : 'Polygon'} Explorer...'),
                        backgroundColor: AppTheme.primaryGold,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View on Block Explorer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: AppTheme.grey,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.grey,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(BuildContext context, String label, String address) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: address));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label address copied!'),
            backgroundColor: AppTheme.primaryGold,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 16,
              color: AppTheme.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                address,
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.copy,
              size: 14,
              color: AppTheme.primaryGold.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}

