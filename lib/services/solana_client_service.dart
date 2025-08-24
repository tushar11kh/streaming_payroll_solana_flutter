import 'dart:convert';
import 'package:solana/solana.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/solana_constants.dart';
import 'package:flutter/foundation.dart';

class SolanaClientService extends ChangeNotifier {  // Add extends ChangeNotifier
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

  // Connect wallet from stored credentials
  Future<bool> connectFromStored() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPrivateKey = prefs.getString(SolanaConstants.storedPrivateKeyKey);
      final storedPublicKey = prefs.getString(SolanaConstants.storedPublicKeyKey);
      
      if (storedPrivateKey != null && storedPublicKey != null) {
        final privateKeyBytes = base64Decode(storedPrivateKey);
        wallet = await Ed25519HDKeyPair.fromPrivateKeyBytes(
          privateKey: privateKeyBytes,
        );
        publicKey = storedPublicKey;
        notifyListeners();  // Add this to notify listeners of changes
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
    notifyListeners();  // Add this to notify listeners of changes
  }

    // Get SOL balance
  Future<double> getSolBalance() async {
    if (wallet == null) throw Exception('Wallet not connected');
    
    try {
      final balance = await client.rpcClient.getBalance(wallet!.publicKey.toBase58());
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
}