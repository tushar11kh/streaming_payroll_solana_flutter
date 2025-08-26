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
      mint: 'A9ESrFEinfstuaduPPpFTQcFhjwkkPgV7bgGYNj2Cyak',
      symbol: 'JOB',
      name: 'Job Coin',
      decimals: 9,
    ),
    TokenInfo(
      mint: 'DZtXmiYXLrZzUhEQqjFX6ceN4nhAdYoGFAQY4m6EYv3R',
      symbol: 'E-INR',
      name: 'Electronic Inr',
      decimals: 6,
    ),
    TokenInfo(
      mint: 'FvwLSGm6AUkQvjUz83WBbYkyjQviMTqwAFKt5HfMooxF',
      symbol: 'SUPA',
      name: 'Superman',
      decimals: 9,
    ),
  ];

  // Shared preferences keys
  static const String storedPrivateKeyKey = 'stored_private_key';
  static const String storedPublicKeyKey = 'stored_public_key';
  static const String storedTokensKey = 'supported_tokens'; // For caching
}