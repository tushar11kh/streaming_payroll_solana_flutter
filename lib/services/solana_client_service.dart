import 'dart:convert';
import 'package:solana/solana.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/solana_constants.dart';
import 'package:flutter/foundation.dart';
import './pda_service.dart';
import '../models/stream.dart';
import '../utils/data_parsing.dart';
import './transaction_service.dart';

class SolanaClientService extends ChangeNotifier {
  // Add extends ChangeNotifier
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
      await prefs.setString(SolanaConstants.storedPublicKeyKey, publicKey!);

      notifyListeners(); // Add this to notify listeners of changes
      return true;
    } catch (e) {
      print('Error connecting wallet: $e');
      return false;
    }
  }

  // Connect wallet from stored credentials
  Future<bool> connectFromStored() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPrivateKey = prefs.getString(
        SolanaConstants.storedPrivateKeyKey,
      );
      final storedPublicKey = prefs.getString(
        SolanaConstants.storedPublicKeyKey,
      );

      if (storedPrivateKey != null && storedPublicKey != null) {
        final privateKeyBytes = base64Decode(storedPrivateKey);
        wallet = await Ed25519HDKeyPair.fromPrivateKeyBytes(
          privateKey: privateKeyBytes,
        );
        publicKey = storedPublicKey;
        notifyListeners(); // Add this to notify listeners of changes
        return true;
      }
      return false;
    } catch (e) {
      print('Error connecting from stored wallet: $e');
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
    notifyListeners(); // Add this to notify listeners of changes
  }

  // Get SOL balance
  Future<double> getSolBalance() async {
    if (wallet == null) throw Exception('Wallet not connected');

    try {
      final balance = await client.rpcClient.getBalance(
        wallet!.publicKey.toBase58(),
      );
      return balance.value / 1000000000; // Convert lamports to SOL
    } catch (e) {
      print('Error getting balance: $e');
      throw e;
    }
  }

  // Get token balance
  // Get token balance (simplified for Day 2)
  Future<double> getTokenBalance(String tokenMint) async {
    if (wallet == null) throw Exception('Wallet not connected');

    try {
      // Simplified version - we'll implement proper token balance in Day 9
      // For now, just return 0 and focus on wallet connection
      return 0.0;
    } catch (e) {
      print('Error getting token balance: $e');
      return 0.0;
    }
  }

  // Add these methods to the SolanaClientService class
  Future<Ed25519HDPublicKey> getStreamPda(Ed25519HDPublicKey employee) async {
    if (wallet == null) throw Exception('Wallet not connected');
    return PdaService.findStreamPda(wallet!.publicKey, employee);
  }

  Future<Ed25519HDPublicKey> getVaultPda(Ed25519HDPublicKey employee) async {
    if (wallet == null) throw Exception('Wallet not connected');
    return PdaService.findVaultPda(wallet!.publicKey, employee);
  }

  Future<StreamAccount?> getStreamAccount(Ed25519HDPublicKey employee) async {
  if (wallet == null) throw Exception('Wallet not connected');
  
  try {
    final streamPda = await getStreamPda(employee);
    final accountInfo = await client.rpcClient.getAccountInfo(streamPda.toBase58());
    
    // For now, just return null - we'll implement proper parsing in Day 9
    print('Account info: $accountInfo');
    return null;
  } catch (e) {
    print('Error getting stream account: $e');
    return null;
  }
}

// Add these methods to the SolanaClientService class
Future<String> createStreamTransaction(
  Ed25519HDPublicKey employee,
  int ratePerSecond,
  Ed25519HDPublicKey tokenMint,
) async {
  if (wallet == null) throw Exception('Wallet not connected');
  
  try {
    // Build the create stream instruction
    final instruction = await TransactionService.createStream(
      employer: wallet!.publicKey,
      employee: employee,
      ratePerSecond: ratePerSecond,
      tokenMint: tokenMint,
    );
    
    // Build transaction
    final message = await TransactionService.buildTransaction([instruction]);
    
    // Estimate fee
    final fee = await TransactionService.estimateFee(client, message);
    print('Estimated fee: $fee lamports');
    
    // For now, just return the message details - we'll send in Day 5
    return 'Transaction built successfully. Fee: ${fee / 1000000000} SOL';
  } catch (e) {
    print('Error building transaction: $e');
    throw Exception('Failed to build transaction: $e');
  }
}

// Test method to simulate transaction building
Future<String> testTransactionBuilding() async {
  if (wallet == null) throw Exception('Wallet not connected');
  
  // Use test values
  const testEmployee = '11111111111111111111111111111111';
  const testTokenMint = '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU'; // USDC devnet
  const testRate = 1000; // 1000 tokens per second (for testing)
  
  try {
    final employeeKey = Ed25519HDPublicKey.fromBase58(testEmployee);
    final tokenMintKey = Ed25519HDPublicKey.fromBase58(testTokenMint);
    
    return await createStreamTransaction(employeeKey, testRate, tokenMintKey);
  } catch (e) {
    return 'Error: $e';
  }
}


}
