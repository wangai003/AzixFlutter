import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import '../services/wallet_connect_service.dart';
import '../providers/enhanced_wallet_provider.dart';
import '../theme/app_theme.dart';

class WalletConnectScreen extends StatefulWidget {
  const WalletConnectScreen({super.key});

  @override
  State<WalletConnectScreen> createState() => _WalletConnectScreenState();
}

class _WalletConnectScreenState extends State<WalletConnectScreen> {
  final _uriController = TextEditingController();
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    WalletConnectService.instance.init();
  }

  @override
  void dispose() {
    _uriController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final uri = _uriController.text.trim();
    if (uri.isEmpty) return;
    setState(() => _connecting = true);
    try {
      await WalletConnectService.instance.connect(uri);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WalletConnect request sent. Approve in dapp.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connect failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _approveSession(String id) async {
    final address =
        context.read<EnhancedWalletProvider>().address ?? context.read<EnhancedWalletProvider>().publicKey;
    if (address == null || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No wallet address. Create/restore wallet first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await WalletConnectService.instance.approveSession(id: id, address: address);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session approved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _approveRequest(
    SessionRequestEvent event,
  ) async {
    final password = await _promptPassword();
    if (password == null) return;
    try {
      await WalletConnectService.instance
          .approveRequest(request: event, password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request approved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approve failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _promptPassword() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unlock wallet'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Wallet password',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WalletConnect'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste WalletConnect URI from checkout',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _uriController,
                    decoration: const InputDecoration(
                      hintText: 'wc:...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _connecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _connecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Connect'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Session Proposals',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: WalletConnectService.instance.proposals,
                builder: (context, proposals, _) {
                  if (proposals.isEmpty) {
                    return const Center(child: Text('No proposals yet'));
                  }
                  return ListView.builder(
                    itemCount: proposals.length,
                    itemBuilder: (context, index) {
                      final proposal = proposals[index];
                      final meta = proposal.params.proposer.metadata;
                      return Card(
                        child: ListTile(
                          title: Text(meta.name ?? 'Unknown dApp'),
                          subtitle: Text(meta.url ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => WalletConnectService.instance
                                    .reject(id: proposal.id.toString()),
                                child: const Text('Reject'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    _approveSession(proposal.id.toString()),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text('Pending Requests',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: WalletConnectService.instance.pendingRequests,
                builder: (context, requests, _) {
                  if (requests.isEmpty) {
                    return const Center(child: Text('No pending requests'));
                  }
                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      final method = req.params.request.method;
                      final chainId = req.params.chainId;
                      return Card(
                        child: ListTile(
                          title: Text(method),
                          subtitle: Text('Chain: $chainId\nTopic: ${req.topic}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    WalletConnectService.instance.rejectRequest(
                                  req,
                                  reason: 'User rejected',
                                ),
                                child: const Text('Reject'),
                              ),
                              ElevatedButton(
                                onPressed: () => _approveRequest(req),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
