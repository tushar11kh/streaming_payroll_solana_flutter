// lib/screens/employee_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:streaming_payroll_solana_flutter/services/solana_client_service.dart';
import 'package:streaming_payroll_solana_flutter/utils/token_utils.dart';
import '../cards/balance_card.dart';
import '../constants/solana_constants.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  List<Map<String, dynamic>> _streams = [];
  bool _loadingStreams = false;

  @override
  void initState() {
    super.initState();
    _fetchStreams();
  }

  Future<void> _fetchStreams() async {
    final solanaService = Provider.of<SolanaClientService>(
      context,
      listen: false,
    );
    
    if (!solanaService.isConnected) return;

    setState(() => _loadingStreams = true);
    try {
      final streams = await solanaService.fetchEmployeeStreams();
      setState(() => _streams = streams);
    } catch (e) {
      print('Error fetching streams: $e');
    } finally {
      setState(() => _loadingStreams = false);
    }
  }

  // lib/screens/employee_screen.dart - Update _claimTokens method
void _claimTokens(int index) async {
  final stream = _streams[index];
  final solanaService = Provider.of<SolanaClientService>(
    context,
    listen: false,
  );

  setState(() => _loadingStreams = true);

  try {
    // 1. Calculate claimable amount
    final claimableAmount = solanaService.calculateClaimable(stream);
    
    if (claimableAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tokens available to claim yet')),
      );
      return;
    }

    // 2. Find or create EMPLOYEE token account (not employer!)
    final employeeTokenAccount = await _findOrCreateEmployeeTokenAccount(stream['token_mint']);
    
    if (employeeTokenAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create token account for receiving tokens')),
      );
      return;
    }

    // 3. Derive the PDAs
    final employerKey = Ed25519HDPublicKey.fromBase58(stream['employer']);
    final employeeKey = Ed25519HDPublicKey.fromBase58(stream['employee']);
    final tokenMintKey = Ed25519HDPublicKey.fromBase58(stream['token_mint']);

    final streamPda = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        SolanaConstants.streamSeed.codeUnits,
        employerKey.bytes,
        employeeKey.bytes,
        tokenMintKey.bytes,
      ],
      programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
    );

    final vaultPda = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        SolanaConstants.vaultSeed.codeUnits,
        employerKey.bytes,
        employeeKey.bytes,
        tokenMintKey.bytes,
      ],
      programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
    );

    // 4. Execute claim transaction
    final signature = await solanaService.claimTokens(
      streamPubkey: streamPda,
      vaultPubkey: vaultPda,
      employeeTokenAccount: Ed25519HDPublicKey.fromBase58(employeeTokenAccount),
      bump: stream['bump'],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Claim successful! TX: ${signature.substring(0, 8)}...'),
        duration: const Duration(seconds: 5),
      ),
    );

    // 5. Refresh streams
    _fetchStreams();

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Claim failed: $e')),
    );
  } finally {
    setState(() => _loadingStreams = false);
  }
}

// Add this helper method to create employee token account if needed
Future<String?> _findOrCreateEmployeeTokenAccount(String mintAddress) async {
  final solanaService = Provider.of<SolanaClientService>(
    context,
    listen: false,
  );

  try {
    // First try to find existing token account
    final mintBytes = Ed25519HDPublicKey.fromBase58(mintAddress).bytes;
    final ownerBytes = solanaService.wallet!.publicKey.bytes;

    final tokenAccounts = await solanaService.client.rpcClient.getProgramAccounts(
      SolanaConstants.tokenProgramId,
      commitment: Commitment.confirmed,
      encoding: Encoding.base64,
      filters: [
        ProgramDataFilter.memcmp(offset: 0, bytes: mintBytes),
        ProgramDataFilter.memcmp(offset: 32, bytes: ownerBytes),
      ],
    );

    if (tokenAccounts.isNotEmpty) {
      return tokenAccounts.first.pubkey as String;
    }

    // If not found, create associated token account for EMPLOYEE
    final associatedTokenAddress = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        solanaService.wallet!.publicKey.bytes, // EMPLOYEE's wallet
        TokenProgram.id.bytes,
        Ed25519HDPublicKey.fromBase58(mintAddress).bytes,
      ],
      programId: AssociatedTokenAccountProgram.id,
    );

    final createInstruction = AssociatedTokenAccountInstruction.createAccount(
      funder: solanaService.wallet!.publicKey, // EMPLOYEE pays the rent
      address: associatedTokenAddress,
      owner: solanaService.wallet!.publicKey, // EMPLOYEE owns the account
      mint: Ed25519HDPublicKey.fromBase58(mintAddress),
    );

    final message = Message(instructions: [createInstruction]);
    await solanaService.client.sendAndConfirmTransaction(
      message: message,
      signers: [solanaService.wallet!], // EMPLOYEE signs
      commitment: Commitment.confirmed,
    );

    return associatedTokenAddress.toBase58();
  } catch (e) {
    print('Error creating employee token account: $e');
    return null;
  }
}

  @override
  Widget build(BuildContext context) {
    final solanaService = Provider.of<SolanaClientService>(context);

    return Scaffold(
      appBar: // In the app bar or somewhere convenient
AppBar(
  title: const Text('Employee Dashboard'),
  backgroundColor: Colors.green[800],
  foregroundColor: Colors.white,
  actions: [
    IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: _fetchStreams,
      tooltip: 'Refresh streams',
    ),
  ],
),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            BalanceCard(
              title: 'My Wallet Balance',
              tokensToShow: SolanaConstants.supportedTokens,
            ),
            const SizedBox(height: 30),

            // Streams section
            const Text(
              'My Payment Streams',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _loadingStreams
                ? const CircularProgressIndicator()
                : _streams.isEmpty
                    ? const Text('No active streams yet...')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _streams.length,
                        itemBuilder: (context, index) {
                          final stream = _streams[index];
                          final token = TokenUtils.findTokenByMint(stream['token_mint']);
                          final uiDeposited = TokenUtils.toUiAmount(
                            stream['deposited_amount'],
                            stream['token_decimals'],
                          );
                          final uiClaimed = TokenUtils.toUiAmount(
                            stream['claimed_amount'],
                            stream['token_decimals'],
                          );

                          // Calculate claimable amount
                          final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                          final elapsedTime = (currentTime - stream['start_time']).clamp(0, double.infinity).toInt();
                          final totalEarned = elapsedTime * stream['rate_per_second'];
                          final claimableAmount = totalEarned - stream['claimed_amount'];
                          final uiClaimable = TokenUtils.toUiAmount(
                            claimableAmount.clamp(0, stream['deposited_amount'] - stream['claimed_amount']).toInt(),
                            stream['token_decimals'],
                          );

                          // In the Employee Screen build method, update the stream card:
return Card(
  margin: const EdgeInsets.only(bottom: 16),
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'From: ${stream['employer'].substring(0, 8)}...', // Shortened address
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('Token: ${token?.symbol ?? 'Unknown'}'),
        Text('Rate: ${TokenUtils.toUiAmount(stream['rate_per_second'], stream['token_decimals']).toStringAsFixed(stream['token_decimals'])} ${token?.symbol}/sec'),
        Text('Total Deposited: ${TokenUtils.formatAmount(uiDeposited, 4)} ${token?.symbol}'),
        Text('Already Claimed: ${TokenUtils.formatAmount(uiClaimed, 4)} ${token?.symbol}'),
        Text(
          'Available to Claim: ${TokenUtils.formatAmount(uiClaimable, 4)} ${token?.symbol}',
          style: TextStyle(
            color: uiClaimable > 0 ? Colors.green : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: uiClaimable > 0 ? () => _claimTokens(index) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: uiClaimable > 0 ? Colors.green[700] : Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: _loadingStreams
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Claim Tokens'),
        ),
      ],
    ),
  ),
);
                        },
                      ),
          ],
        ),
      ),
    );
  }
}