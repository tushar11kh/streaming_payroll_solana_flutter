import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/wallet_connection_widget.dart';
import '../services/solana_client_service.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
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
                return _buildEmployeeActions();
              } else {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Connect your wallet to access employee features',
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

  Widget _buildEmployeeActions() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Employee Actions:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          // Placeholder for future actions
          Card(
            child: ListTile(
              leading: Icon(Icons.account_balance_wallet),
              title: Text('View Claimable Amount'),
              subtitle: Text('Check how much you can claim from your streams'),
            ),
          ),
          SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.money),
              title: Text('Claim Tokens'),
              subtitle: Text('Claim your earned tokens from streams'),
            ),
          ),
        ],
      ),
    );
  }
}