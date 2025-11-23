import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Ultra-simple transaction list - just displays the basics
class SimplePolygonTransactionList extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final Future<void> Function() onRefresh;

  const SimplePolygonTransactionList({
    super.key,
    required this.transactions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions yet',
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final tx = transactions[index];
          
          // Extract data with safe defaults
          final type = tx['type'] as String? ?? 'send';
          final asset = tx['asset'] as String? ?? 'MATIC';
          final value = (tx['value'] as num? ?? 0).toDouble();
          final from = tx['from'] as String? ?? '';
          final to = tx['to'] as String? ?? '';
          final timestamp = tx['timestamp'] as DateTime? ?? DateTime.now();
          final status = tx['status'] as String? ?? 'success';
          
          final isReceive = type == 'receive';
          final color = isReceive ? Colors.green : Colors.red;
          final sign = isReceive ? '+' : '-';
          
          return Card(
            color: AppTheme.darkGrey,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                isReceive ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
              ),
              title: Text(
                '$sign$value $asset',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${isReceive ? 'From' : 'To'}: ${_formatAddress(isReceive ? from : to)}\n${_formatTime(timestamp)}',
                style: TextStyle(color: AppTheme.grey, fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'success' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: status == 'success' ? Colors.green : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.isEmpty || address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM dd').format(time);
    }
  }
}

