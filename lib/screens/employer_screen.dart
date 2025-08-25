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
  final _employeeController = TextEditingController();
  final _rateController = TextEditingController();
  final _tokenMintController = TextEditingController();
  bool _isCreatingStream = false;

  @override
  void initState() {
    super.initState();
    _connectStoredWallet();
  }

  @override
  void dispose() {
    _employeeController.dispose();
    _rateController.dispose();
    _tokenMintController.dispose();
    super.dispose();
  }

  Future<void> _connectStoredWallet() async {
    final solanaService = Provider.of<SolanaClientService>(
      context,
      listen: false,
    );
    await solanaService.connectFromStored();
  }

  // Add this method to the _EmployerScreenState class
  Future<void> _testPdaCalculation() async {
    final solanaService = Provider.of<SolanaClientService>(
      context,
      listen: false,
    );

    // Use a test employee address
    const testEmployee =
        '11111111111111111111111111111111'; // Example base58 address
    final employeeKey = Ed25519HDPublicKey.fromBase58(testEmployee);

    try {
      final streamPda = await PdaService.findStreamPda(
        solanaService.wallet!.publicKey,
        employeeKey,
      );
      final vaultPda = await PdaService.findVaultPda(
        solanaService.wallet!.publicKey,
        employeeKey,
      );

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error calculating PDA: $e')));
    }
  }

  // Add this method to the _EmployerScreenState class
  Future<void> _testTransactionBuilding() async {
    final solanaService = Provider.of<SolanaClientService>(
      context,
      listen: false,
    );

    try {
      final result = await solanaService.testTransactionBuilding();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Add this method to handle stream creation
  Future<void> _createStream() async {
    if (_employeeController.text.isEmpty ||
        _tokenMintController.text.isEmpty ||
        _rateController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isCreatingStream = true;
    });

    final solanaService = Provider.of<SolanaClientService>(
      context,
      listen: false,
    );

    try {
      final employeeKey = Ed25519HDPublicKey.fromBase58(
        _employeeController.text,
      );
      final tokenMintKey = Ed25519HDPublicKey.fromBase58(
        _tokenMintController.text,
      );
      final rate = int.parse(_rateController.text);

      final result = await solanaService.createStreamTransaction(
        employeeKey,
        rate,
        tokenMintKey,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ready to create stream: $result'),
          duration: const Duration(seconds: 5),
        ),
      );

      // Clear form
      _employeeController.clear();
      _tokenMintController.clear();
      _rateController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating stream: $e')));
    } finally {
      setState(() {
        _isCreatingStream = false;
      });
    }
  }

  void _fillExampleValues() {
    _employeeController.text =
        '11111111111111111111111111111111'; // Example employee
    _tokenMintController.text =
        '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU'; // USDC devnet
    _rateController.text = '1000'; // Example rate
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employer Actions:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Create Stream Form
          _buildCreateStreamForm(),

          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: Icon(Icons.account_balance_wallet),
              title: Text('Deposit to Vault'),
              subtitle: Text('Fund an existing stream vault'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.calculate),
              title: Text('Test PDA Calculation'),
              subtitle: Text('Verify stream and vault PDA addresses'),
              onTap: _testPdaCalculation,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.build),
              title: Text('Test Transaction Building'),
              subtitle: Text('Build create_stream transaction (not sent)'),
              onTap: _testTransactionBuilding,
            ),
          ),
          // Add this in _buildCreateStreamForm() after the form fields:
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _fillExampleValues,
            child: const Text('Fill Example Values'),
          ),
        ],
      ),
    );
  }

  // Add this new method to build the create stream form
  Widget _buildCreateStreamForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create New Stream',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _employeeController,
              decoration: const InputDecoration(
                labelText: 'Employee Public Key',
                hintText: 'Enter employee wallet address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenMintController,
              decoration: const InputDecoration(
                labelText: 'Token Mint Address',
                hintText: 'Enter token mint address (e.g., USDC devnet)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rateController,
              decoration: const InputDecoration(
                labelText: 'Rate per Second',
                hintText: 'Enter tokens per second rate',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _isCreatingStream
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createStream,
                    child: const Text('Create Payment Stream'),
                  ),
          ],
        ),
      ),
    );
  }
}
