import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../bridge/providers/bridge_provider.dart';
import '../bridge/models/route_models.dart' as bridge_models;
import '../bridge/models/bridge_job.dart';
import '../bridge/bridge_config.dart';
import '../theme/app_theme.dart';

/// Bridge screen for cross-chain token transfers
class BridgeScreen extends StatefulWidget {
  const BridgeScreen({super.key});

  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _toAddressController = TextEditingController();
  
  String? _selectedFromChain;
  String? _selectedToChain;
  String? _selectedFromToken;
  String? _selectedToToken;
  
  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  void _initializeDefaults() async {
    final provider = Provider.of<BridgeProvider>(context, listen: false);
    
    // Set default to Stellar for both chains
    _selectedFromChain = BridgeConfig.stellarChainId;
    _selectedToChain = BridgeConfig.polygonChainId; // Default to Polygon for destination
    
    // Set chains in provider
    provider.setQuoteParams(
      fromChain: BridgeConfig.stellarChainId,
      toChain: BridgeConfig.polygonChainId,
    );
    
    // Get Stellar public key and set as from address
    final stellarAddress = await provider.getStellarPublicKey();
    if (stellarAddress != null && stellarAddress.isNotEmpty) {
      provider.setQuoteParams(
        fromAddress: stellarAddress,
        toAddress: stellarAddress, // Default to same address
      );
      // Also set in the text field
      _toAddressController.text = stellarAddress;
    } else {
      // If no address found, show a warning
      print('⚠️ Warning: Could not retrieve Stellar public key. Please enter manually.');
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    _amountController.dispose();
    _toAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text(
          'Cross-Chain Bridge',
          style: TextStyle(color: AppTheme.primaryGold),
        ),
        backgroundColor: AppTheme.black,
        elevation: 0,
      ),
      body: Consumer<BridgeProvider>(
        builder: (context, provider, child) {
          if (provider.currentJob != null) {
            return _buildJobProgressView(provider);
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildChainSelector(provider),
                const SizedBox(height: 24),
                _buildTokenSelector(provider),
                const SizedBox(height: 24),
                _buildAmountInput(provider),
                const SizedBox(height: 24),
                _buildToAddressInput(provider),
                const SizedBox(height: 24),
                _buildGetQuoteButton(provider),
                const SizedBox(height: 24),
                if (provider.error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorDisplay(provider.error!),
                ],
                if (provider.availableRoutes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildRoutesList(provider),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChainSelector(BridgeProvider provider) {
    return Card(
      color: AppTheme.darkGrey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Chains',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildChainDropdown(
                    'From',
                    _selectedFromChain,
                    (value) {
                      setState(() => _selectedFromChain = value);
                      provider.setQuoteParams(fromChain: value);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.arrow_forward,
                    color: AppTheme.primaryGold,
                  ),
                ),
                Expanded(
                  child: _buildChainDropdown(
                    'To',
                    _selectedToChain,
                    (value) {
                      setState(() => _selectedToChain = value);
                      provider.setQuoteParams(toChain: value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChainDropdown(
    String label,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    final chains = [
      {'id': BridgeConfig.stellarChainId, 'name': 'Stellar'},
      {'id': BridgeConfig.ethereumChainId, 'name': 'Ethereum'},
      {'id': BridgeConfig.polygonChainId, 'name': 'Polygon'},
      {'id': BridgeConfig.bscChainId, 'name': 'BSC'},
      {'id': BridgeConfig.avalancheChainId, 'name': 'Avalanche'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.grey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.black,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.grey),
            ),
          ),
          dropdownColor: AppTheme.darkGrey,
          style: const TextStyle(color: AppTheme.white),
          items: chains.map((chain) {
            return DropdownMenuItem<String>(
              value: chain['id'],
              child: Text(chain['name']!),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTokenSelector(BridgeProvider provider) {
    return Card(
      color: AppTheme.darkGrey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Tokens',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTokenDropdown(
                    'From',
                    _selectedFromToken,
                    _selectedFromChain,
                    (value) {
                      setState(() => _selectedFromToken = value);
                      if (value != null) {
                        provider.setQuoteParams(fromToken: value);
                      }
                    },
                    provider,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.swap_horiz,
                    color: AppTheme.primaryGold,
                  ),
                ),
                Expanded(
                  child: _buildTokenDropdown(
                    'To',
                    _selectedToToken,
                    _selectedToChain,
                    (value) {
                      setState(() => _selectedToToken = value);
                      if (value != null) {
                        provider.setQuoteParams(toToken: value);
                      }
                    },
                    provider,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenDropdown(
    String label,
    String? value,
    String? chainId,
    ValueChanged<String?> onChanged,
    BridgeProvider provider,
  ) {
    return FutureBuilder<List<bridge_models.Token>>(
      future: chainId != null
          ? provider.getSupportedTokens(chainId)
          : Future.value([]),
      builder: (context, snapshot) {
        final tokens = snapshot.data ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppTheme.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.grey),
                ),
              ),
              dropdownColor: AppTheme.darkGrey,
              style: const TextStyle(color: AppTheme.white),
              items: tokens.map((token) {
                return DropdownMenuItem<String>(
                  value: token.address,
                  child: Text(token.symbol),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAmountInput(BridgeProvider provider) {
    return Card(
      color: AppTheme.darkGrey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Amount',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.grey),
                ),
                hintText: 'Enter amount',
                hintStyle: const TextStyle(color: AppTheme.grey),
              ),
              onChanged: (value) {
                provider.setQuoteParams(fromAmount: value.trim());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToAddressInput(BridgeProvider provider) {
    return Card(
      color: AppTheme.darkGrey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recipient Address',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _toAddressController,
              style: const TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.grey),
                ),
                hintText: 'Enter recipient address',
                hintStyle: const TextStyle(color: AppTheme.grey),
              ),
              onChanged: (value) {
                provider.setQuoteParams(toAddress: value.trim());
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<String?>(
              future: provider.getStellarPublicKey(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final address = snapshot.data!;
                  return GestureDetector(
                    onTap: () {
                      _toAddressController.text = address;
                      provider.setQuoteParams(toAddress: address);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.black,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: AppTheme.primaryGold,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Use my Stellar address: ${address.substring(0, 8)}...${address.substring(address.length - 8)}',
                              style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward,
                            color: AppTheme.primaryGold,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGetQuoteButton(BridgeProvider provider) {
    return ElevatedButton(
      onPressed: provider.isLoading
          ? null
          : () async {
              await provider.getQuote();
              
              // Show error in snackbar if any
              if (provider.error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.error!),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: AppTheme.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: provider.isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
              ),
            )
          : const Text(
              'Get Quote',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildRoutesList(BridgeProvider provider) {
    return Card(
      color: AppTheme.darkGrey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Routes',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...provider.availableRoutes.map((route) {
              final isSelected = provider.selectedRoute?.id == route.id;
              return _buildRouteCard(route, isSelected, provider);
            }),
            const SizedBox(height: 16),
            if (provider.selectedRoute != null)
              ElevatedButton(
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        try {
                          await provider.executeRoute();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: AppTheme.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Start Bridge',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(
    bridge_models.BridgeRoute route,
    bool isSelected,
    BridgeProvider provider,
  ) {
    final totalFees = route.estimate.getTotalFeesUSD();
    
    return Card(
      color: isSelected ? AppTheme.primaryGold.withOpacity(0.2) : AppTheme.black,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => provider.selectRoute(route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    route.steps.first.tool,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryGold : AppTheme.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryGold,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${route.estimate.fromAmount} → ${route.estimate.toAmount}',
                style: const TextStyle(color: AppTheme.grey),
              ),
              if (totalFees != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Fees: \$${totalFees.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ],
              if (route.estimate.executionDuration != null) ...[
                const SizedBox(height: 4),
                Text(
                  'ETA: ${route.estimate.executionDuration!.inMinutes} min',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobProgressView(BridgeProvider provider) {
    final job = provider.currentJob!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppTheme.darkGrey,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bridge Status: ${job.status.toString().split('.').last}',
                    style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...job.steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    final isActive = index == job.currentStepIndex;
                    final isCompleted = step.status == StepStatus.confirmed;
                    
                    return _buildStepProgress(
                      index + 1,
                      job.route.steps[index].tool,
                      step.status,
                      step.txHash,
                      isActive,
                      isCompleted,
                      provider,
                      job.id,
                      index,
                    );
                  }),
                ],
              ),
            ),
          ),
          if (job.status == BridgeJobStatus.waitingForUser) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  await provider.signCurrentStep();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Sign Transaction',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepProgress(
    int stepNumber,
    String tool,
    StepStatus status,
    String? txHash,
    bool isActive,
    bool isCompleted,
    BridgeProvider provider,
    String jobId,
    int stepIndex,
  ) {
    IconData icon;
    Color color;
    
    if (isCompleted) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (isActive) {
      icon = Icons.radio_button_checked;
      color = AppTheme.primaryGold;
    } else {
      icon = Icons.radio_button_unchecked;
      color = AppTheme.grey;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step $stepNumber: $tool',
                  style: TextStyle(
                    color: isActive ? AppTheme.primaryGold : AppTheme.white,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (txHash != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tx: ${txHash.substring(0, 8)}...',
                    style: const TextStyle(
                      color: AppTheme.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
                Text(
                  'Status: ${status.toString().split('.').last}',
                  style: const TextStyle(
                    color: AppTheme.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(String error) {
    return Card(
      color: Colors.red.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

