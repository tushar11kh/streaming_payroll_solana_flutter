// lib/screens/employee_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  void _claimTokens(int index) async {
    final stream = _streams[index];
    final solanaService = Provider.of<SolanaClientService>(
      context,
      listen: false,
    );

    try {
      // TODO: Implement claim functionality
      // This will require creating a claim instruction and sending transaction
      print('Claiming tokens from stream: ${stream['employer']}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim functionality to be implemented')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Claim failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final solanaService = Provider.of<SolanaClientService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
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

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'From: ${stream['employer']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Token: ${token?.symbol ?? 'Unknown'}'),
                                  Text('Rate: ${stream['rate_per_second']} tokens/sec'),
                                  Text('Total Deposited: ${TokenUtils.formatAmount(uiDeposited, 4)} ${token?.symbol}'),
                                  Text('Claimed: ${TokenUtils.formatAmount(uiClaimed, 4)} ${token?.symbol}'),
                                  Text('Available to Claim: ${TokenUtils.formatAmount(uiClaimable, 4)} ${token?.symbol}'),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: uiClaimable > 0 ? () => _claimTokens(index) : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Claim Tokens'),
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