// lib/utils/token_utils.dart
import 'package:streaming_payroll_solana_flutter/constants/solana_constants.dart';
import 'package:streaming_payroll_solana_flutter/models/token_info.dart';

class TokenUtils {
  static double toUiAmount(int rawAmount, int decimals) {
    return rawAmount / BigInt.from(10).pow(decimals).toDouble();
  }

  static int toRawAmount(double uiAmount, int decimals) {
    return (uiAmount * BigInt.from(10).pow(decimals).toDouble()).round();
  }

  static String formatAmount(double amount, int decimals) {
    return amount.toStringAsFixed(decimals);
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
}