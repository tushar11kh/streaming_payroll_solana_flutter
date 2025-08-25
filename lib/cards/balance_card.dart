import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:streaming_payroll_solana_flutter/constants/solana_constants.dart';
import '../services/solana_client_service.dart';

class BalanceCard extends StatefulWidget {
  final String title;
  final bool showTokenBalance;
  final String? tokenMintAddress;

  const BalanceCard({
    super.key,
    this.title = 'Wallet Balance',
    this.showTokenBalance = true,
    this.tokenMintAddress,
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  double solBalance = 0;
  String tokenBalance = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  // In your _loadBalances method
  Future<void> _loadBalances() async {
    setState(() => loading = true); // Show loading

    final solanaService = Provider.of<SolanaClientService>(
      context,
      listen: false,
    );

    if (!solanaService.isConnected) {
      setState(() => loading = false);
      return;
    }

    try {
      // Get SOL balance
      final balance = await solanaService.client.rpcClient.getBalance(
        solanaService.wallet!.publicKey.toBase58(),
        commitment: Commitment.confirmed,
      );
      solBalance = balance.value / 1000000000;

      // Get token balance
      tokenBalance = await _getTokenBalance(
        solanaService,
        widget.tokenMintAddress!,
      );
    } catch (e) {
      print('Error loading balances: $e');
    } finally {
      setState(() => loading = false); // Hide loading
    }
  }

  Future<String> _getTokenBalance(
    SolanaClientService solanaService,
    String tokenMintAddress,
  ) async {
    try {
      // Convert base58 mint address to raw bytes (Uint8List / List<int>)
      final mintBytes = Ed25519HDPublicKey.fromBase58(tokenMintAddress).bytes;
      final ownerBytes = solanaService.wallet!.publicKey.bytes;

      // Use memcmp with raw bytes (List<int>), NOT base64 strings
      final tokenAccounts = await solanaService.client.rpcClient.getProgramAccounts(
        SolanaConstants
            .tokenProgramId, // e.g. 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'
        commitment: Commitment.confirmed,
        encoding: Encoding.base64,
        filters: [
          // Filter by mint address (offset 0 in token account layout) — pass raw bytes
          ProgramDataFilter.memcmp(
            offset: 0,
            bytes: mintBytes, // <-- raw bytes, NOT base64
          ),
          // Filter by owner (offset 32 in token account layout) — pass raw bytes
          ProgramDataFilter.memcmp(
            offset: 32,
            bytes: ownerBytes, // <-- raw bytes
          ),
        ],
      );

      print('Found ${tokenAccounts.length} token accounts');

      if (tokenAccounts.isEmpty) {
        print('No token accounts found!');
        return '0.0';
      }

      // tokenAccounts is a list of ProgramAccount objects. Get the first pubkey string.
      final firstAccount = tokenAccounts.first;
      String? tokenAccountPubkeyString;

      // Different shapes may exist depending on the client version; try common fields
      try {
        // In many versions firstAccount.pubkey is already a String
        tokenAccountPubkeyString = firstAccount.pubkey as String?;
      } catch (_) {
        // fallback: try toString or other shapes
        tokenAccountPubkeyString = firstAccount.toString();
      }

      if (tokenAccountPubkeyString == null ||
          tokenAccountPubkeyString.isEmpty) {
        print(
          'Could not determine token account pubkey from ProgramAccount shape.',
        );
        return '0.0';
      }

      // Fetch token account balance
      final balanceResp = await solanaService.client.rpcClient
          .getTokenAccountBalance(
            tokenAccountPubkeyString,
            commitment: Commitment.confirmed,
          );

      // balanceResp.value.* holds amount info
      final value = balanceResp.value;
      if (value.amount.isEmpty) return '0.0';

      // Prefer uiAmount (double) if present; otherwise parse uiAmountString
      if (value.uiAmountString != null) {
        return balanceResp.value.amount;
      } else if (value.uiAmountString != null) {
        return value.uiAmountString!;
      } else {
        // Last resort: parse amount / decimals (not handled here)
        print('Balance response had no uiAmount/uiAmountString.');
        return '0.0';
      }
    } catch (e, st) {
      print('Error getting token balance: $e\n$st');
      return '0.0';
    }
  }

  @override
  Widget build(BuildContext context) {
    final solanaService = Provider.of<SolanaClientService>(context);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Wallet Address
            Text(
              solanaService.publicKey ?? 'Not connected',
              style: const TextStyle(fontFamily: 'Monospace', fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 15),

            // Balances
            loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SOL Balance
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'SOL: ${solBalance.toStringAsFixed(4)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Token Balance (if enabled)
                      if (widget.showTokenBalance &&
                          widget.tokenMintAddress != null)
                        Row(
                          children: [
                            const Icon(Icons.monetization_on, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Tokens: ${double.parse(tokenBalance) / 1000000000}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          // Add a rotation animation for the refresh icon
                          IconButton(
                            icon: AnimatedBuilder(
                              animation: AlwaysStoppedAnimation(
                                loading ? 1 : 0,
                              ),
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: loading ? 2 * 3.1416 : 0,
                                  child: child,
                                );
                              },
                              child: Icon(Icons.refresh, size: 20),
                            ),
                            onPressed: loading
                                ? null
                                : _loadBalances, // Disable during refresh
                            tooltip: 'Refresh balances',
                          ),
                        ],
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
