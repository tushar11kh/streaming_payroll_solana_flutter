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
  final result = List<int>.filled(8, 0);
  for (var i = 0; i < 8; i++) {
    result[i] = value & 0xFF;
    value = value >> 8;
  }
  return result;
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
    return tokenAccounts.first.pubkey as String;
  } catch (e) {
    print('Error finding token account: $e');
    return null;
  }
}

}



