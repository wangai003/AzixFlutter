import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../providers/auth_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_list.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  TransactionType? _selectedType;
  String? _selectedAsset;
  DateTimeRange? _selectedDateRange;
  String _sentReceivedFilter = 'All'; // 'All', 'Sent', 'Received'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StellarProvider>(context, listen: false).loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stellarProvider = Provider.of<StellarProvider>(context);
    final allTransactions = stellarProvider.transactions;
    final userPublicKey = stellarProvider.publicKey;

    // Get all unique asset codes
    final assetCodes = allTransactions.map((tx) => tx.assetCode).toSet().toList();

    // Apply filters
    List<Transaction> filtered = allTransactions;
    // Sent/Received filter
    if (_sentReceivedFilter == 'Sent' && userPublicKey != null) {
      filtered = filtered.where((tx) => tx.senderAddress == userPublicKey).toList();
    } else if (_sentReceivedFilter == 'Received' && userPublicKey != null) {
      filtered = filtered.where((tx) => tx.recipientAddress == userPublicKey).toList();
    }
    if (_selectedType != null) {
      filtered = filtered.where((tx) => tx.type == _selectedType).toList();
    }
    if (_selectedAsset != null && _selectedAsset!.isNotEmpty) {
      filtered = filtered.where((tx) => tx.assetCode == _selectedAsset).toList();
    }
    if (_selectedDateRange != null) {
      filtered = filtered.where((tx) =>
        tx.timestamp.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
        tx.timestamp.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)))
      ).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        backgroundColor: AppTheme.black,
        foregroundColor: AppTheme.primaryGold,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => stellarProvider.loadTransactions(),
          ),
        ],
      ),
      backgroundColor: AppTheme.black,
      body: Column(
        children: [
          // Sent/Received toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _sentReceivedFilter == 'All',
                  onSelected: (selected) {
                    if (selected) setState(() => _sentReceivedFilter = 'All');
                  },
                  selectedColor: AppTheme.primaryGold,
                  labelStyle: TextStyle(color: _sentReceivedFilter == 'All' ? AppTheme.black : AppTheme.primaryGold),
                  backgroundColor: AppTheme.black,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Sent'),
                  selected: _sentReceivedFilter == 'Sent',
                  onSelected: (selected) {
                    if (selected) setState(() => _sentReceivedFilter = 'Sent');
                  },
                  selectedColor: AppTheme.primaryGold,
                  labelStyle: TextStyle(color: _sentReceivedFilter == 'Sent' ? AppTheme.black : AppTheme.primaryGold),
                  backgroundColor: AppTheme.black,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Received'),
                  selected: _sentReceivedFilter == 'Received',
                  onSelected: (selected) {
                    if (selected) setState(() => _sentReceivedFilter = 'Received');
                  },
                  selectedColor: AppTheme.primaryGold,
                  labelStyle: TextStyle(color: _sentReceivedFilter == 'Received' ? AppTheme.black : AppTheme.primaryGold),
                  backgroundColor: AppTheme.black,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Type filter
                DropdownButton<TransactionType?>(
                  value: _selectedType,
                  hint: const Text('Type'),
                  dropdownColor: AppTheme.black,
                  style: TextStyle(color: AppTheme.primaryGold),
                  items: [
                    const DropdownMenuItem<TransactionType?>(
                      value: null,
                      child: Text('All'),
                    ),
                    ...TransactionType.values.map((type) => DropdownMenuItem<TransactionType?>(
                      value: type,
                      child: Text(type.toString().split('.').last.capitalize()),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedType = val),
                ),
                const SizedBox(width: 12),
                // Asset filter
                DropdownButton<String?>(
                  value: _selectedAsset,
                  hint: const Text('Asset'),
                  dropdownColor: AppTheme.black,
                  style: TextStyle(color: AppTheme.primaryGold),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All'),
                    ),
                    ...assetCodes.map((code) => DropdownMenuItem<String?>(
                      value: code,
                      child: Text(code),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedAsset = val),
                ),
                const SizedBox(width: 12),
                // Date filter
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, color: AppTheme.primaryGold),
                  label: Text(
                    _selectedDateRange == null
                      ? 'Date'
                      : '${_selectedDateRange!.start.toLocal().toString().split(' ')[0]} - ${_selectedDateRange!.end.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(color: AppTheme.primaryGold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryGold),
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2022, 1, 1),
                      lastDate: DateTime.now(),
                      initialDateRange: _selectedDateRange,
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primaryGold,
                            onPrimary: AppTheme.black,
                            surface: AppTheme.black,
                            onSurface: AppTheme.primaryGold,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => _selectedDateRange = picked);
                  },
                ),
                if (_selectedType != null || _selectedAsset != null || _selectedDateRange != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.primaryGold),
                    onPressed: () => setState(() {
                      _selectedType = null;
                      _selectedAsset = null;
                      _selectedDateRange = null;
                    }),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.grey),
          Expanded(
            child: filtered.isEmpty
              ? Center(
                  child: Text('No transactions found.', style: TextStyle(color: AppTheme.grey)),
                )
              : TransactionList(transactions: filtered),
          ),
        ],
      ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
} 