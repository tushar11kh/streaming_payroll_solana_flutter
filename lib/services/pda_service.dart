import 'package:solana/solana.dart';
import '../constants/solana_constants.dart';

class PdaService {
  // Find stream PDA address
  static Future<Ed25519HDPublicKey> findStreamPda(
    Ed25519HDPublicKey employer,
    Ed25519HDPublicKey employee,
  ) async {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        SolanaConstants.streamSeed.codeUnits,
        employer.bytes,
        employee.bytes,
      ],
      programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
    );
  }

  // Find vault PDA address
  static Future<Ed25519HDPublicKey> findVaultPda(
    Ed25519HDPublicKey employer,
    Ed25519HDPublicKey employee,
  ) async {
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        SolanaConstants.vaultSeed.codeUnits,
        employer.bytes,
        employee.bytes,
      ],
      programId: Ed25519HDPublicKey.fromBase58(SolanaConstants.programId),
    );
  }

  // For this package version, we can't easily get the bump seed
  // We'll need to handle this differently in the transaction building
  static Future<int> findBumpSeed(
    Ed25519HDPublicKey employer,
    Ed25519HDPublicKey employee,
    String seedType,
  ) async {
    // Since this package version doesn't expose the bump,
    // we'll return a placeholder for now
    // We'll handle the actual bump finding during transaction construction
    return 255; // Placeholder - will be updated in Day 4
  }
}