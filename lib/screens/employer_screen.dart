import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solana/solana.dart';
import 'package:streaming_payroll_solana_flutter/services/pda_service.dart';
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

  // Add this method to the _EmployerScreenState class
Future<void> _testPdaCalculation() async {
  final solanaService = Provider.of<SolanaClientService>(context, listen: false);
  
  // Use a test employee address
  const testEmployee = '11111111111111111111111111111111'; // Example base58 address
  final employeeKey = Ed25519HDPublicKey.fromBase58(testEmployee);
  
  try {
    final streamPda = await PdaService.findStreamPda(solanaService.wallet!.publicKey, employeeKey);
    final vaultPda = await PdaService.findVaultPda(solanaService.wallet!.publicKey, employeeKey);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stream PDA: ${streamPda.toBase58().substring(0, 16)}...'),
            Text('Vault PDA: ${vaultPda.toBase58().substring(0, 16)}...'),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error calculating PDA: $e')),
    );
  }
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
    return Padding(
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
          // Add this to the Column children in _buildEmployerActions()
const SizedBox(height: 16),
Card(
  child: ListTile(
    leading: Icon(Icons.calculate),
    title: Text('Test PDA Calculation'),
    subtitle: Text('Verify stream and vault PDA addresses'),
    onTap: _testPdaCalculation,
  ),
),
        ],
      ),
    );
  }
}