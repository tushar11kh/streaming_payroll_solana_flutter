import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:streaming_payroll_solana_flutter/constants/solana_constants.dart';
import '../services/solana_client_service.dart';
import 'package:solana/src/encoder/instruction.dart' as inst;

class EmployerScreen extends StatefulWidget {
  const EmployerScreen({super.key});

  @override
  State<EmployerScreen> createState() => _EmployerScreenState();
}

class _EmployerScreenState extends State<EmployerScreen> {
  final TextEditingController _employeeController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
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
      final rateBytes = _encodeUint64(rate);
      final instructionData = [...discriminator, ...rateBytes];

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
            pubKey: Ed25519HDPublicKey.fromBase58(
              '9UEPmvkKMpHtM2Yn6HkktCEDUo3tMyBR3YEnBr2mgdLR',
            ),
            isSigner: false,
          ),
          // token_program
          AccountMeta.readonly(
            pubKey: Ed25519HDPublicKey.fromBase58(
              'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
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
            dataBytes = accDataRaw.data?.cast<int>();
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
      streams.sort((a, b) => (b['start_time'] as int).compareTo(a['start_time'] as int));
      print("printing _streams before set state:$_streams");
      setState(() => _streams = streams);
    } catch (e) {
      print('Error fetching streams: $e');
    } finally {
      setState(() => _loadingStreams = false);
    }
  }

  // Helper function to encode u64 as little-endian bytes
  List<int> _encodeUint64(int value) {
    final result = List<int>.filled(8, 0);
    for (var i = 0; i < 8; i++) {
      result[i] = value & 0xFF;
      value = value >> 8;
    }
    return result;
  }

  Map<String, dynamic> _decodeStreamAccount(List<int> bytes) {
    // Layout:
    // 0-7: discriminator
    // 8-39: employer
    // 40-71: employee
    // 72-79: start_time (i64 LE)
    // 80-87: rate_per_second (u64 LE)
    // 88-95: deposited_amount (u64 LE)
    // 96-103: claimed_amount (u64 LE)
    // 104: bump (u8)

    final employer = Ed25519HDPublicKey(bytes.sublist(8, 40));
    final employee = Ed25519HDPublicKey(bytes.sublist(40, 72));

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

    final startTime = decodeI64LE(bytes.sublist(72, 80));
    final ratePerSecond = decodeU64LE(bytes.sublist(80, 88));
    final depositedAmount = decodeU64LE(bytes.sublist(88, 96));
    final claimedAmount = decodeU64LE(bytes.sublist(96, 104));
    final bump = bytes[104];

    return {
      'employer': employer.toBase58(),
      'employee': employee.toBase58(),
      'start_time': startTime,
      'rate_per_second': ratePerSecond,
      'deposited_amount': depositedAmount,
      'claimed_amount': claimedAmount,
      'bump': bump,
    };
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
            // Employer Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Employer Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      solanaService.publicKey ?? 'Not connected',
                      style: const TextStyle(
                        fontFamily: 'Monospace',
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _streams.length,
                    itemBuilder: (context, index) {
                      final stream = _streams[index];
                      return Card(
                        child: ListTile(
                          title: Text('Employee: ${stream['employee']}'),
                          subtitle: Text(
                            'Rate: ${stream['rate_per_second']} tokens/sec',
                          ),
                          trailing: Text(
                            'Deposited: ${stream['deposited_amount']}',
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
