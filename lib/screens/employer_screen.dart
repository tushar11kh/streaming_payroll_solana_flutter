import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/wallet_connection_widget.dart';
import '../services/solana_client_service.dart';

class EmployerScreen extends StatefulWidget {
  const EmployerScreen({super.key});

  @override
  State<EmployerScreen> createState() => _EmployerScreenState();
}

class _EmployerScreenState extends State<EmployerScreen> {
  @override
  void initState() {
    super.initState();
    _connectStoredWallet();
  }

  Future<void> _connectStoredWallet() async {
    final solanaService = Provider.of<SolanaClientService>(context, listen: false);
    await solanaService.connectFromStored();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const WalletConnectionWidget(),
          const SizedBox(height: 20),
          Consumer<SolanaClientService>(
            builder: (context, solanaService, child) {
              if (solanaService.isConnected) {
                return _buildEmployerActions();
              } else {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Connect your wallet to access employer features',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmployerActions() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Employer Actions:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          // Placeholder for future actions
          Card(
            child: ListTile(
              leading: Icon(Icons.add_circle_outline),
              title: Text('Create New Stream'),
              subtitle: Text('Set up a new payment stream for an employee'),
            ),
          ),
          SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.account_balance_wallet),
              title: Text('Deposit to Vault'),
              subtitle: Text('Fund an existing stream vault'),
            ),
          ),
        ],
      ),
    );
  }
}