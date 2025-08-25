import 'dart:convert';

import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import '../constants/solana_constants.dart';
import './pda_service.dart';

class TransactionService {
  // Create stream instruction - return regular Instruction for now
  static Future<Instruction> createStream({
    required Ed25519HDPublicKey employer,
    required Ed25519HDPublicKey employee,
    required int ratePerSecond,
    required Ed25519HDPublicKey tokenMint,
  }) async {
    final programId = Ed25519HDPublicKey.fromBase58(SolanaConstants.programId);
    
    // Find PDAs
    final streamPda = await PdaService.findStreamPda(employer, employee);
    final vaultPda = await PdaService.findVaultPda(employer, employee);
    
    // Encode ratePerSecond as little-endian bytes (8 bytes)
    final rateBytes = _intToLittleEndianBytes(ratePerSecond, length: 8);
    
    // For Day 4, we'll use regular Instruction without Anchor discriminator
    // We'll fix this in Day 6 when we implement proper Anchor transactions
    return Instruction(
      programId: programId,
      accounts: [
        AccountMeta.writeable(pubKey: employer, isSigner: true),
        AccountMeta.readonly(pubKey: employee, isSigner: false),
        AccountMeta.writeable(pubKey: streamPda, isSigner: false),
        AccountMeta.writeable(pubKey: vaultPda, isSigner: false),
        AccountMeta.readonly(pubKey: tokenMint, isSigner: false),
        AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
        AccountMeta.readonly(pubKey: Ed25519HDPublicKey.fromBase58('SysvarRent111111111111111111111111111111111'), isSigner: false),
      ],
      data: ByteArray(rateBytes), // Wrap in ByteArray // Just the rate bytes without discriminator for now
    );
  }

  // Helper method to convert integer to little-endian bytes
  static List<int> _intToLittleEndianBytes(int value, {int length = 8}) {
    final bytes = List<int>.filled(length, 0);
    for (int i = 0; i < length; i++) {
      bytes[i] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }

  // Build and return a complete transaction
  static Future<Message> buildTransaction(List<Instruction> instructions) async {
    return Message(instructions: instructions);
  }

  // Estimate transaction fee
// Estimate transaction fee - simple for Day 4
static Future<int> estimateFee(SolanaClient client, Message message) async {
  try {
    // Simple fixed fee for testing
    return 10000; // ~0.00001 SOL
  } catch (e) {
    return 10000;
  }
}
}