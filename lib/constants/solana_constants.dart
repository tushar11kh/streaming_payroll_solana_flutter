// lib/constants/solana_constants.dart
import 'package:streaming_payroll_solana_flutter/models/token_info.dart';

class SolanaConstants {
  static const String rpcUrl = 'http://127.0.0.1:8899';
  static const String wsUrl = 'ws://127.0.0.1:8900';
  static const String programId = 'CtiRAqpHkEkzEzsbW4in6cKNcDBdevQFGbBBsSmJsCeL';
  static const String tokenProgramId = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  static const String streamSeed = 'stream';
  static const String vaultSeed = 'vault';

  // Supported tokens list
  static final List<TokenInfo> supportedTokens = [
    TokenInfo(
      mint: 'Fm7F4A2QLHxsBRzNZBWNkAZpezBNeoCV4WV2xaTybS7R',
      symbol: 'E-INR',
      name: 'Electronic Inr',
      decimals: 6,
    ),

    TokenInfo(
      mint: '6FN16yMemysar3GaPyLyp6txqxfiE5apjquBVm2JeTZn',
      symbol: 'E-USD',
      name: 'Electronic USD',
      decimals: 8,
    ),
  ];

  // Shared preferences keys
  static const String storedPrivateKeyKey = 'stored_private_key';
  static const String storedPublicKeyKey = 'stored_public_key';
  static const String storedTokensKey = 'supported_tokens'; // For caching
}