import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:streaming_payroll_solana_flutter/constants/solana_constants.dart';
import 'package:streaming_payroll_solana_flutter/models/token_info.dart';
import 'package:streaming_payroll_solana_flutter/utils/token_utils.dart';
import '../services/solana_client_service.dart';
import 'package:solana/src/encoder/instruction.dart' as inst;
import '../cards/balance_card.dart';
import 'dart:typed_data';

class EmployerScreen extends StatefulWidget {
  const EmployerScreen({super.key});

  @override
  State<EmployerScreen> createState() => _EmployerScreenState();
}

class _EmployerScreenState extends State<EmployerScreen> {
  final TextEditingController _employeeController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  TokenInfo? _selectedToken;
  bool _isLoading = false;
  List<Map<String, dynamic>> _streams = [];
  bool _loadingStreams = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStreams();
      print(_streams);
    });
  }

  Future<void> _createStream() async {
    final solanaService = Provider.of<SolanaClientService>(
      context,
      listen: false,
    );

    if (_selectedToken == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a token')));
      return;
    }

    if (!solanaService.isConnected || solanaService.wallet == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wallet not connected')));
      return;
    }

    final employeePubkey = _employeeController.text.trim();
    final rate = int.tryParse(_rateController.text.trim()) ?? 0;

    if (employeePubkey.isEmpty || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid employee address and rate'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Parse keys
      final employerKey = solanaService.wallet!.publicKey;
      final employeeKey = Ed25519HDPublicKey.fromBase58(employeePubkey);

      // 2. Derive PDAs
      final streamPda = await Ed25519HDPublicKey.findProgramAddress(
        seeds: [
          SolanaConstants.streamSeed.codeUnits,
          employerKey.bytes,
          employeeKey.bytes,
        ],
        programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
      );

      final vaultPda = await Ed25519HDPublicKey.findProgramAddress(
        seeds: [
          SolanaConstants.vaultSeed.codeUnits,
          employerKey.bytes,
          employeeKey.bytes,
        ],
        programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
      );

      // 3. Build instruction data (discriminator + rate_per_second)
      final discriminator = [71, 188, 111, 127, 108, 40, 229, 158];
      final rateBytes = SolanaClientService().encodeUint64(rate);
      final instructionData = [
        ...discriminator,
        ...rateBytes,
        _selectedToken!.decimals,
      ];

      // 4. Create instruction
      final instruction = inst.Instruction(
        programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
        accounts: [
          // employer (signer, writable)
          AccountMeta.writeable(pubKey: employerKey, isSigner: true),
          // employee (readonly)
          AccountMeta.readonly(pubKey: employeeKey, isSigner: false),
          // stream (PDA, writable)
          AccountMeta.writeable(pubKey: streamPda, isSigner: false),
          // vault (PDA, writable)
          AccountMeta.writeable(pubKey: vaultPda, isSigner: false),
          // token_mint (TODO: Replace with actual token mint)
          AccountMeta.readonly(
            pubKey: Ed25519HDPublicKey.fromBase58(_selectedToken!.mint),
            isSigner: false,
          ),
          // token_program
          AccountMeta.readonly(
            pubKey: Ed25519HDPublicKey.fromBase58(
              SolanaConstants.tokenProgramId,
            ),
            isSigner: false,
          ),
          // system_program
          AccountMeta.readonly(
            pubKey: Ed25519HDPublicKey.fromBase58(
              '11111111111111111111111111111111',
            ),
            isSigner: false,
          ),
          // rent
          AccountMeta.readonly(
            pubKey: Ed25519HDPublicKey.fromBase58(
              'SysvarRent111111111111111111111111111111111',
            ),
            isSigner: false,
          ),
        ],
        data: ByteArray(instructionData),
      );

      // 5. Create and send transaction
      final message = Message(instructions: [instruction]);

      final signature = await solanaService.client.sendAndConfirmTransaction(
        message: message,
        signers: [solanaService.wallet!],
        commitment: Commitment.confirmed,
      );

      _fetchStreams();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream created successfully!')),
      );

      // Clear form
      _employeeController.clear();
      _rateController.clear();

      print(_streams);
      print("Printed the transaction instruction: \n" + "  " + signature);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating stream: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStreams() async {
    final solanaService = Provider.of<SolanaClientService>(
      context,
      listen: false,
    );
    if (!solanaService.isConnected || solanaService.wallet == null) return;

    setState(() => _loadingStreams = true);
    try {
      final programId = Ed25519HDPublicKey.fromBase58(
        SolanaConstants.programId,
      );
      final employerPubkey = solanaService.wallet!.publicKey;

      // Get all Stream accounts owned by our program
      final accounts = await solanaService.client.rpcClient.getProgramAccounts(
        programId.toBase58(),
        commitment: Commitment.confirmed,
        encoding: Encoding.base64,
        filters: [
          // Filter for Stream accounts by checking account discriminator
          ProgramDataFilter.memcmp(
            offset: 0,
            bytes: [
              166,
              224,
              59,
              4,
              202,
              10,
              186,
              83,
            ], // Stream account discriminator
          ),
          // Filter for streams where employer matches connected wallet
          ProgramDataFilter.memcmp(
            offset: 8, // Skip 8-byte discriminator, employer is first field
            bytes: employerPubkey.bytes,
          ),
        ],
      );

      print("Debug accounts: $accounts");

      final List<Map<String, dynamic>> streams = [];

      for (final account in accounts) {
        try {
          // Debug: show account wrapper types
          debugPrint('ProgramAccount: ${account.runtimeType}');
          debugPrint('Inner account info type: ${account.account.runtimeType}');

          final dynamic accDataRaw = account.account.data;

          // Extract raw bytes into `dataBytes`
          List<int>? dataBytes;

          // Case 1: BinaryAccountData (the solana package DTO)
          if (accDataRaw is BinaryAccountData) {
            // BinaryAccountData.data is typically Uint8List or List<int>
            dataBytes = accDataRaw.data.cast<int>();
          }
          // Case 2: RPC returned [base64String, "base64"]
          else if (accDataRaw is List &&
              accDataRaw.isNotEmpty &&
              accDataRaw[0] is String) {
            dataBytes = base64Decode(accDataRaw[0] as String);
          }
          // Case 3: RPC returned a single base64 string
          else if (accDataRaw is String) {
            dataBytes = base64Decode(accDataRaw);
          }
          // Case 4: Nested map shape: { "data": [ "...", "base64" ] } or { "data": "..." }
          else if (accDataRaw is Map) {
            final dynamic inner = accDataRaw['data'];
            if (inner is List && inner.isNotEmpty && inner[0] is String) {
              dataBytes = base64Decode(inner[0] as String);
            } else if (inner is String) {
              dataBytes = base64Decode(inner);
            }
          }

          if (dataBytes == null) {
            debugPrint(
              'Skipping account: cannot extract raw bytes (unsupported shape: ${accDataRaw.runtimeType})',
            );
            continue;
          }

          debugPrint('Account data length: ${dataBytes.length}');
          if (dataBytes.length < 105) {
            debugPrint(
              'Skipping account: insufficient length ${dataBytes.length}',
            );
            continue;
          }

          // Debug: show discriminator bytes
          debugPrint('discriminator bytes: ${dataBytes.sublist(0, 8)}');

          final streamData = _decodeStreamAccount(dataBytes);
          streams.add(streamData);
          debugPrint('Decoded stream: $streamData');
        } catch (e, st) {
          debugPrint('Error decoding stream account: $e\n$st');
        }
      }
      streams.sort(
        (a, b) => (b['start_time'] as int).compareTo(a['start_time'] as int),
      );
      print("printing _streams before set state:$_streams");
      setState(() => _streams = streams);
    } catch (e) {
      print('Error fetching streams: $e');
    } finally {
      setState(() => _loadingStreams = false);
    }
  }

  Map<String, dynamic> _decodeStreamAccount(List<int> bytes) {
    // Layout:
    // 0-7: discriminator (8 bytes)
    // 8-39: employer (32 bytes)
    // 40-71: employee (32 bytes)
    // 72-103: token_mint (32 bytes) - NEW FIELD
    // 104: token_decimals (1 byte) - NEW FIELD
    // 105-112: start_time (i64 LE, 8 bytes)
    // 113-120: rate_per_second (u64 LE, 8 bytes)
    // 121-128: deposited_amount (u64 LE, 8 bytes)
    // 129-136: claimed_amount (u64 LE, 8 bytes)
    // 137: bump (1 byte)

    final employer = Ed25519HDPublicKey(bytes.sublist(8, 40));
    final employee = Ed25519HDPublicKey(bytes.sublist(40, 72));

    final tokenMint = Ed25519HDPublicKey(bytes.sublist(72, 104)); // New field
    final tokenDecimals = bytes[104]; // New field

    int decodeU64LE(List<int> b) {
      var value = 0;
      for (var i = 0; i < b.length; i++) {
        value |= (b[i] & 0xff) << (8 * i);
      }
      return value;
    }

    int decodeI64LE(List<int> b) {
      // Use BigInt to avoid sign issues
      final u = BigInt.zero | BigInt.from(0);
      BigInt big = BigInt.zero;
      for (var i = 0; i < b.length; i++) {
        big |= (BigInt.from(b[i]) << (8 * i));
      }
      final signBit = BigInt.one << 63;
      if ((big & signBit) != BigInt.zero) {
        big = big - (BigInt.one << 64);
      }
      return big.toInt();
    }

    // Proper u64/i64 decoding using ByteData
    // final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

    final startTime = decodeI64LE(bytes.sublist(105, 113));
    final ratePerSecond = decodeU64LE(bytes.sublist(113, 121));
    final depositedAmount = decodeU64LE(bytes.sublist(121, 129));
    final claimedAmount = decodeU64LE(bytes.sublist(129, 137));
    final bump = bytes[137];

    return {
      'employer': employer.toBase58(),
      'employee': employee.toBase58(),
      'token_mint': tokenMint.toBase58(),
      'token_decimals': tokenDecimals,
      'start_time': startTime,
      'rate_per_second': ratePerSecond,
      'deposited_amount': depositedAmount,
      'claimed_amount': claimedAmount,
      'bump': bump,
    };
  }

  void _showDepositDialog(int index) {
    final stream = _streams[index];
    final token = TokenUtils.findTokenByMint(stream['token_mint']);
    final amountController = TextEditingController();
    String? tokenAccountAddress;
    bool loadingTokenAccount = true;

    showDialog(
      context: context,
      builder: (context) {
        // Pre-fetch the token account
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final solanaService = Provider.of<SolanaClientService>(
            context,
            listen: false,
          );
          final tokenAccountAddress = await solanaService
              .findEmployerTokenAccount(stream['token_mint']);

          if (tokenAccountAddress == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create token account')),
            );
            setState(() => _isLoading = false);
            return;
          }
        });

        return StatefulBuilder(
          builder: (context, setstate) {
            return AlertDialog(
              title: Text('Deposit ${token!.symbol}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Employee: ${stream['employee']}'),
                  const SizedBox(height: 10),
                  Text(
                    'Current deposit: ${TokenUtils.formatAmount(TokenUtils.toUiAmount(stream['deposited_amount'], stream['token_decimals']), 4)} ${token.symbol}',
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount to deposit',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ), // Allow decimals
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final solanaService = Provider.of<SolanaClientService>(
                      context,
                      listen: false,
                    );
                    final rawAmount = TokenUtils.toRawAmount(
                      double.tryParse(amountController.text) ?? 0,
                      stream['token_decimals'],
                    );
                    // final tokenAccount = tokenAccountController.text.trim();

                    if (rawAmount <= 0) {
                      //|| tokenAccount.isEmpty
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter valid amount and token account',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      // Re-derive the PDAs using the same method as during creation
                      final employerKey = solanaService.wallet!.publicKey;
                      final employeeKey = Ed25519HDPublicKey.fromBase58(
                        stream['employee'],
                      );

                      final streamPda =
                          await Ed25519HDPublicKey.findProgramAddress(
                            seeds: [
                              SolanaConstants.streamSeed.codeUnits,
                              employerKey.bytes,
                              employeeKey.bytes,
                            ],
                            programId: Ed25519HDPublicKey.fromBase58(
                              SolanaConstants.programId,
                            ),
                          );

                      final vaultPda =
                          await Ed25519HDPublicKey.findProgramAddress(
                            seeds: [
                              SolanaConstants.vaultSeed.codeUnits,
                              employerKey.bytes,
                              employeeKey.bytes,
                            ],
                            programId: Ed25519HDPublicKey.fromBase58(
                              SolanaConstants.programId,
                            ),
                          );

                      // In your depositToVault method or where you call it:
                      final tokenAccountAddress = await solanaService
                          .findEmployerTokenAccount(stream['token_mint']);

                      if (tokenAccountAddress == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No token account found. Please get some tokens first.',
                            ),
                          ),
                        );
                        return;
                      }

                      final amount = (rawAmount).round();

                      final signature = await solanaService.depositToVault(
                        streamPubkey: streamPda,
                        vaultPubkey: vaultPda,
                        employerTokenAccount: Ed25519HDPublicKey.fromBase58(
                          tokenAccountAddress!,
                        ),
                        amount: amount,
                      );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Deposit successful! TX: ${signature.substring(0, 8)}...',
                          ),
                        ),
                      );
                      _fetchStreams(); // Refresh to show updated amount
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Deposit failed: $e')),
                      );
                    }
                  },
                  child: const Text('Deposit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final solanaService = Provider.of<SolanaClientService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employer Dashboard'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            BalanceCard(
              title: 'Wallet Balance',
              tokensToShow: [
                SolanaConstants.supportedTokens[0],
                SolanaConstants.supportedTokens[1],
                SolanaConstants.supportedTokens[2],
              ],
            ),
            const SizedBox(height: 30),

            // Create Stream Form
            const Text(
              'Create Payment Stream',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _employeeController,
              decoration: const InputDecoration(
                labelText: 'Employee Public Key',
                border: OutlineInputBorder(),
                hintText: 'Enter employee wallet address',
              ),
            ),

            const SizedBox(height: 16),

            // Token Selection Dropdown
            DropdownButtonFormField<TokenInfo>(
              value: _selectedToken,
              decoration: const InputDecoration(
                labelText: 'Select Token',
                border: OutlineInputBorder(),
              ),
              items: SolanaConstants.supportedTokens.map((token) {
                return DropdownMenuItem<TokenInfo>(
                  value: token,
                  child: Text('${token.symbol} (${token.name})'),
                );
              }).toList(),
              onChanged: (token) {
                setState(() => _selectedToken = token);
              },
              validator: (value) {
                if (value == null) return 'Please select a token';
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _rateController,
              decoration: const InputDecoration(
                labelText: 'Rate per Second (tokens)',
                border: OutlineInputBorder(),
                hintText: 'e.g., 1000000 (1 token per second)',
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createStream,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Create Stream',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),

            const SizedBox(height: 30),

            // Streams section
            const Text(
              'Your Active Streams',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _loadingStreams
                ? const CircularProgressIndicator()
                : _streams.isEmpty
                ? const Text('No active streams yet...')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _streams.length,
                    itemBuilder: (context, index) {
                      final stream = _streams[index];
                      final token = TokenUtils.findTokenByMint(
                        stream['token_mint'],
                      );
                      final uiDeposited = TokenUtils.toUiAmount(
                        stream['deposited_amount'],
                        stream['token_decimals'],
                      );

                      return Card(
                        child: ListTile(
                          title: Text('Employee: ${stream['employee']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Token: ${token?.symbol ?? 'Unknown'}'),
                              Text(
                                'Rate: ${stream['rate_per_second']} tokens/sec',
                              ),
                              Text(
                                'Deposited: ${TokenUtils.formatAmount(uiDeposited, 4)} ${token?.symbol}',
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _showDepositDialog(index),
                            child: const Text('Deposit'),
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

  @override
  void dispose() {
    _employeeController.dispose();
    _rateController.dispose();
    super.dispose();
  }
}
