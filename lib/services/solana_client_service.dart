import 'dart:convert';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streaming_payroll_solana_flutter/utils/token_utils.dart';
import '../constants/solana_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:solana/src/encoder/instruction.dart' as inst;
import 'package:fixnum/fixnum.dart';
import '../screens/employer_screen.dart';


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
  required BigInt amount, // BigInt here
}) async {
  try {
    // Build deposit_to_vault instruction
    final discriminator = [18, 62, 110, 8, 26, 106, 248, 151]; // From IDL
    final amountBytes = encodeUint64(amount); // BigInt -> 8 bytes LE
    final instructionData = [...discriminator, ...amountBytes];

    final instruction = inst.Instruction(
      programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
      accounts: [
        AccountMeta.writeable(pubKey: wallet!.publicKey, isSigner: true),
        AccountMeta.writeable(pubKey: streamPubkey, isSigner: false),
        AccountMeta.writeable(pubKey: vaultPubkey, isSigner: false),
        AccountMeta.writeable(pubKey: employerTokenAccount, isSigner: false),
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
    print('Error depositing to vault: $e');
    rethrow;
  }
}


// Helper function (add this to your service)
// helper: encode u64 little-endian from BigInt
List<int> encodeUint64(BigInt value) {
  final max = BigInt.parse('18446744073709551615'); // 2^64-1
  if (value < BigInt.zero || value > max) {
    throw ArgumentError('Value out of range for u64: $value');
  }

  final bytes = List<int>.filled(8, 0);
  var temp = value;
  for (int i = 0; i < 8; i++) {
    bytes[i] = (temp & BigInt.from(0xff)).toInt();
    temp = temp >> 8;
  }
  return bytes;
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

        final streamData = decodeStreamAccount(dataBytes);
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
BigInt decodeU64LE(List<int> b) {
  BigInt value = BigInt.zero;
  for (int i = 0; i < b.length; i++) {
    value |= (BigInt.from(b[i]) << (8 * i));
  }
  return value;
}
int decodeI64LE(List<int> b) {
  BigInt big = BigInt.zero;
  for (int i = 0; i < b.length; i++) {
    big |= (BigInt.from(b[i]) << (8 * i));
  }
  final signBit = BigInt.one << 63;
  if ((big & signBit) != BigInt.zero) {
    big = big - (BigInt.one << 64);
  }
  return big.toInt();
}


// Helper method to decode stream account data (same as employer side)
Map<String, dynamic> decodeStreamAccount(List<int> bytes) {
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
BigInt calculateClaimable(Map<String, dynamic> stream) {
  final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final startTime = stream['start_time'] as int;
  final elapsedTime = (currentTime - startTime).clamp(0, double.infinity).toInt();

  final BigInt ratePerSecond = TokenUtils.safeToBigInt(stream['rate_per_second']);
  final BigInt deposited = TokenUtils.safeToBigInt(stream['deposited_amount']);
  final BigInt claimed = TokenUtils.safeToBigInt(stream['claimed_amount']);

  final BigInt totalEarned = ratePerSecond * BigInt.from(elapsedTime);
  BigInt claimable = totalEarned - claimed;
  if (claimable < BigInt.zero) claimable = BigInt.zero;

  final BigInt maxClaimable = deposited - claimed;
  if (maxClaimable < BigInt.zero) return BigInt.zero;

  if (claimable > maxClaimable) return maxClaimable;
  return claimable;
}


}



