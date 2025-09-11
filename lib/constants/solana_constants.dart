// lib/constants/solana_constants.dart
import 'package:streaming_payroll_solana_flutter/models/token_info.dart';

class SolanaConstants {
  static const String rpcUrl = 'http://192.168.1.17:8899';
  static const String wsUrl = 'ws://192.168.1.17:8900/';
  static const String programId = 'CtiRAqpHkEkzEzsbW4in6cKNcDBdevQFGbBBsSmJsCeL';
  static const String tokenProgramId = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  static const String streamSeed = 'stream';
  static const String vaultSeed = 'vault';

  // Supported tokens list
  static final List<TokenInfo> supportedTokens = [
    TokenInfo(
      mint: '67aPua82DDJqywGGnBCERbew6p6eNt4UaHJnY3veS43d',
      symbol: 'E-INR',
      name: 'Electronic Inr',
      decimals: 8,
    ),

    TokenInfo(
      mint: 'Dzb6nCxRS5x9yCxknDADHNUUJuw1oXnrnH5FSho9Nawa',
      symbol: 'E-USD',
      name: 'Electronic USD',
      decimals: 4,
    ),
    
    TokenInfo(
      mint: 'CAjFufCamSJQjszKWMuKsgwiCW4ssucyeBb1waYTnfUq',
      symbol: 'JOBC',
      name: 'Job Coin',
      decimals: 6,
    ),
  ];
  

  // Shared preferences keys
  static const String storedPrivateKeyKey = 'stored_private_key';
  static const String storedPublicKeyKey = 'stored_public_key';
  static const String storedTokensKey = 'supported_tokens'; // For caching
}