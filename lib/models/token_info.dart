// lib/models/token_info.dart
class TokenInfo {
  final String mint;
  final String symbol;
  final String name;
  final int decimals;

  TokenInfo({
    required this.mint,
    required this.symbol,
    required this.name,
    required this.decimals,
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      mint: json['mint'],
      symbol: json['symbol'],
      name: json['name'],
      decimals: json['decimals'],
    );
  }

  Map<String, dynamic> toJson() => {
    'mint': mint,
    'symbol': symbol,
    'name': name,
    'decimals': decimals,
  };
}