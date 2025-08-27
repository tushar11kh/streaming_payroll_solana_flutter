// lib/utils/token_utils.dart
import 'package:streaming_payroll_solana_flutter/constants/solana_constants.dart';
import 'package:streaming_payroll_solana_flutter/models/token_info.dart';

class TokenUtils {
  // rawAmount is BigInt now
  static double toUiAmount(dynamic rawAmount, int decimals) {
    final bigRaw = safeToBigInt(rawAmount);
    final divisor = BigInt.from(10).pow(decimals);
    // convert to double for UI rendering (safe for typical token scales)
    return bigRaw.toDouble() / divisor.toDouble();
  }

  // returns BigInt (raw on-chain integer)
  static BigInt toRawAmount(double uiAmount, int decimals) {
    final multiplier = BigInt.from(10).pow(decimals);
    // round the UI value to nearest integer units
    final rawDouble = (uiAmount * multiplier.toDouble()).round();
    return BigInt.from(rawDouble);
  }

  static String formatAmount(double amount, int decimalPlaces) {
    return amount.toStringAsFixed(decimalPlaces);
  }

  static TokenInfo? findTokenByMint(String mintAddress) {
    try {
      return SolanaConstants.supportedTokens.firstWhere(
        (token) => token.mint == mintAddress,
      );
    } catch (e) {
      return null; // Return null if not found
    }
  }

  // Helper to safely convert numbers for web/mobile
  static BigInt safeToBigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) return BigInt.parse(value);
    // As a last resort, use double -> round -> BigInt
    if (value is double) return BigInt.from(value.round());
    // fallback
    return BigInt.zero;
  }
}
