import 'dart:convert';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/solana_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:solana/src/encoder/instruction.dart' as inst;


class SolanaClientService extends ChangeNotifier {
  late SolanaClient client;
  Ed25519HDKeyPair? wallet;
  String? publicKey;
  bool get isConnected => wallet != null;

  SolanaClientService() {
    client = SolanaClient(
      rpcUrl: Uri.parse(SolanaConstants.rpcUrl),
      websocketUrl: Uri.parse(SolanaConstants.wsUrl),
    );
  }

  // Connect wallet from private key bytes
  Future<bool> connectFromPrivateKey(List<int> privateKeyBytes) async {
    try {
      wallet = await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: privateKeyBytes,
      );
      publicKey = wallet?.publicKey.toBase58();
      
      // Store wallet info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SolanaConstants.storedPrivateKeyKey,
        base64Encode(privateKeyBytes),
      );
      await prefs.setString(
        SolanaConstants.storedPublicKeyKey,
        publicKey!,
      );
      
      notifyListeners();  // Add this to notify listeners of changes
      return true;
    } catch (e) {
      print('Error connecting wallet: $e');
      return false;
    }
  }

    // Disconnect wallet
  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SolanaConstants.storedPrivateKeyKey);
    await prefs.remove(SolanaConstants.storedPublicKeyKey);
    wallet = null;
    publicKey = null;
    notifyListeners();  // Add this to notify listeners of changes
  }




  // In your SolanaClientService class, add:
Future<String> depositToVault({
  required Ed25519HDPublicKey streamPubkey,
  required Ed25519HDPublicKey vaultPubkey,
  required Ed25519HDPublicKey employerTokenAccount,
  required int amount,
}) async {
  try {
    // Build deposit_to_vault instruction
    final discriminator = [18, 62, 110, 8, 26, 106, 248, 151]; // From IDL
    final amountBytes = encodeUint64(amount);
    final instructionData = [...discriminator, ...amountBytes];

    final instruction = inst.Instruction(
      programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
      accounts: [
        // employer (signer, writable)
        AccountMeta.writeable(pubKey: wallet!.publicKey, isSigner: true),
        // stream (writable)
        AccountMeta.writeable(pubKey: streamPubkey, isSigner: false),
        // vault (writable)
        AccountMeta.writeable(pubKey: vaultPubkey, isSigner: false),
        // employer_token_account (writable)
        AccountMeta.writeable(pubKey: employerTokenAccount, isSigner: false),
        // token_program
        AccountMeta.readonly(
          pubKey: Ed25519HDPublicKey.fromBase58('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
          isSigner: false,
        ),
      ],
      data: ByteArray(instructionData),
    );

    final message = Message(instructions: [instruction]);
    final signature = await client.sendAndConfirmTransaction(
      message: message,
      signers: [wallet!],
      commitment: Commitment.confirmed,
    );

    return signature;
  } catch (e) {
    print('Error depositing to vault: $e');
    rethrow;
  }
}

// Helper function (add this to your service)
List<int> encodeUint64(int value) {
  final byteData = ByteData(8);
  byteData.setUint64(0, value, Endian.little);
  return byteData.buffer.asUint8List().toList();
}

Future<double> getSolBalance() async {
  try {
    final balance = await client.rpcClient.getBalance(wallet!.publicKey.toBase58());
    return balance.value / 1000000000; // Convert lamports to SOL
  } catch (e) {
    print('Error getting SOL balance: $e');
    return 0;
  }
}

// Replace ALL token account finding methods with this ONE method
Future<String?> findEmployerTokenAccount(String mintAddress) async {
  try {
    // Use the SAME approach as BalanceCard (it works!)
    final mintBytes = Ed25519HDPublicKey.fromBase58(mintAddress).bytes;
    final ownerBytes = wallet!.publicKey.bytes;

    final tokenAccounts = await client.rpcClient.getProgramAccounts(
      SolanaConstants.tokenProgramId,
      commitment: Commitment.confirmed,
      encoding: Encoding.base64,
      filters: [
        ProgramDataFilter.memcmp(offset: 0, bytes: mintBytes),
        ProgramDataFilter.memcmp(offset: 32, bytes: ownerBytes),
      ],
    );

    print('Found ${tokenAccounts.length} token accounts for mint: $mintAddress');

    if (tokenAccounts.isEmpty) {
      print('No token account found for mint: $mintAddress');
      return null;
    }

    // Return the first token account address
    return tokenAccounts.first.pubkey;
  } catch (e) {
    print('Error finding token account: $e');
    return null;
  }
}

// Add to SolanaClientService
Future<List<Map<String, dynamic>>> fetchEmployeeStreams() async {
  if (!isConnected) return [];

  try {
    final programId = Ed25519HDPublicKey.fromBase58(SolanaConstants.programId);
    final employeePubkey = wallet!.publicKey;

    // Get all Stream accounts where employee matches connected wallet
    final accounts = await client.rpcClient.getProgramAccounts(
      programId.toBase58(),
      commitment: Commitment.confirmed,
      encoding: Encoding.base64,
      filters: [
        // Filter for Stream accounts by checking account discriminator
        ProgramDataFilter.memcmp(
          offset: 0,
          bytes: [166, 224, 59, 4, 202, 10, 186, 83], // Stream account discriminator
        ),
        // Filter for streams where employee matches connected wallet
        ProgramDataFilter.memcmp(
          offset: 40, // Skip 8-byte discriminator + 32-byte employer, employee is at offset 40
          bytes: employeePubkey.bytes,
        ),
      ],
    );

    final List<Map<String, dynamic>> streams = [];

    for (final account in accounts) {
      try {
        final dynamic accDataRaw = account.account.data;
        List<int> dataBytes;

        if (accDataRaw is BinaryAccountData) {
          dataBytes = accDataRaw.data.cast<int>();
        } else if (accDataRaw is List && accDataRaw.isNotEmpty && accDataRaw[0] is String) {
          dataBytes = base64Decode(accDataRaw[0] as String);
        } else if (accDataRaw is String) {
          dataBytes = base64Decode(accDataRaw);
        } else if (accDataRaw is Map) {
          final dynamic inner = accDataRaw['data'];
          if (inner is List && inner.isNotEmpty && inner[0] is String) {
            dataBytes = base64Decode(inner[0] as String);
          } else if (inner is String) {
            dataBytes = base64Decode(inner);
          } else {
            continue;
          }
        } else {
          continue;
        }

        if (dataBytes.length < 137) continue;

        final streamData = _decodeStreamAccount(dataBytes);
        streams.add(streamData);
      } catch (e) {
        print('Error decoding stream account: $e');
      }
    }

    // Sort by start time (newest first)
    streams.sort((a, b) => (b['start_time'] as int).compareTo(a['start_time'] as int));
    
    return streams;
  } catch (e) {
    print('Error fetching employee streams: $e');
    return [];
  }
}

// Helper method to decode stream account data (same as employer side)
Map<String, dynamic> _decodeStreamAccount(List<int> bytes) {
  // Your existing decode method from employer screen
  // Make sure this is consistent with both employer and employee
  final employer = Ed25519HDPublicKey(bytes.sublist(8, 40));
  final employee = Ed25519HDPublicKey(bytes.sublist(40, 72));
  final tokenMint = Ed25519HDPublicKey(bytes.sublist(72, 104));
  final tokenDecimals = bytes[104];

  final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
  final startTime = byteData.getInt64(105, Endian.little);
  final ratePerSecond = byteData.getUint64(113, Endian.little);
  final depositedAmount = byteData.getUint64(121, Endian.little);
  final claimedAmount = byteData.getUint64(129, Endian.little);
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

// Add to SolanaClientService
Future<String> claimTokens({
  required Ed25519HDPublicKey streamPubkey,
  required Ed25519HDPublicKey vaultPubkey,
  required Ed25519HDPublicKey employeeTokenAccount,
  required int bump, // Stream PDA bump
}) async {
  try {
    // Build claim instruction
    final discriminator = [62, 198, 214, 193, 213, 159, 108, 210]; // From IDL
    final instructionData = [...discriminator];

    final instruction = inst.Instruction(
      programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
      accounts: [
        // employee (signer, writable)
        AccountMeta.writeable(pubKey: wallet!.publicKey, isSigner: true),
        // stream (writable)
        AccountMeta.writeable(pubKey: streamPubkey, isSigner: false),
        // vault (writable)
        AccountMeta.writeable(pubKey: vaultPubkey, isSigner: false),
        // employee_token_account (writable)
        AccountMeta.writeable(pubKey: employeeTokenAccount, isSigner: false),
        // token_program
        AccountMeta.readonly(
          pubKey: Ed25519HDPublicKey.fromBase58(SolanaConstants.tokenProgramId),
          isSigner: false,
        ),
      ],
      data: ByteArray(instructionData),
    );

    final message = Message(instructions: [instruction]);
    final signature = await client.sendAndConfirmTransaction(
      message: message,
      signers: [wallet!],
      commitment: Commitment.confirmed,
    );

    return signature;
  } catch (e) {
    print('Error claiming tokens: $e');
    rethrow;
  }
}

// Helper method to calculate claimable amount
int calculateClaimable(Map<String, dynamic> stream) {
  final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final elapsedTime = (currentTime - stream['start_time']).clamp(0, double.infinity).toInt();
  final totalEarned = elapsedTime * stream['rate_per_second'];
  final claimableAmount = totalEarned - stream['claimed_amount'];
  
  // Cannot claim more than what's available in the vault
  final maxClaimable = stream['deposited_amount'] - stream['claimed_amount'];
  
  return claimableAmount.clamp(0, maxClaimable).toInt();
}

}



