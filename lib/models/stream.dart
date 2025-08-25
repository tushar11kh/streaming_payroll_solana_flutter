import 'package:solana/solana.dart';

class StreamAccount {
  final Ed25519HDPublicKey employer;
  final Ed25519HDPublicKey employee;
  final int startTime;
  final int ratePerSecond;
  final int depositedAmount;
  final int claimedAmount;
  final int bump;

  StreamAccount({
    required this.employer,
    required this.employee,
    required this.startTime,
    required this.ratePerSecond,
    required this.depositedAmount,
    required this.claimedAmount,
    required this.bump,
  });

  factory StreamAccount.fromBuffer(List<int> data) {
    // Skip discriminator (first 8 bytes)
    int offset = 8;
    
    // Parse employer (32 bytes)
    final employerBytes = data.sublist(offset, offset + 32);
    offset += 32;
    
    // Parse employee (32 bytes)
    final employeeBytes = data.sublist(offset, offset + 32);
    offset += 32;
    
    // Parse startTime (8 bytes, little-endian)
    int startTime = 0;
    for (int i = 0; i < 8; i++) {
      startTime += data[offset + i] << (i * 8);
    }
    offset += 8;
    
    // Parse ratePerSecond (8 bytes, little-endian)
    int ratePerSecond = 0;
    for (int i = 0; i < 8; i++) {
      ratePerSecond += data[offset + i] << (i * 8);
    }
    offset += 8;
    
    // Parse depositedAmount (8 bytes, little-endian)
    int depositedAmount = 0;
    for (int i = 0; i < 8; i++) {
      depositedAmount += data[offset + i] << (i * 8);
    }
    offset += 8;
    
    // Parse claimedAmount (8 bytes, little-endian)
    int claimedAmount = 0;
    for (int i = 0; i < 8; i++) {
      claimedAmount += data[offset + i] << (i * 8);
    }
    offset += 8;
    
    // Parse bump (1 byte)
    int bump = data[offset];
    
    return StreamAccount(
      employer: Ed25519HDPublicKey(employerBytes),
      employee: Ed25519HDPublicKey(employeeBytes),
      startTime: startTime,
      ratePerSecond: ratePerSecond,
      depositedAmount: depositedAmount,
      claimedAmount: claimedAmount,
      bump: bump,
    );
  }

  // Calculate claimable amount based on current time
  int getClaimableAmount() {
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsedTime = (currentTime - startTime).clamp(0, currentTime);
    final totalClaimable = elapsedTime * ratePerSecond;
    return (totalClaimable - claimedAmount).clamp(0, depositedAmount - claimedAmount);
  }

  // Convert to map for easy display
  Map<String, dynamic> toMap() {
    return {
      'employer': employer.toBase58(),
      'employee': employee.toBase58(),
      'startTime': startTime,
      'ratePerSecond': ratePerSecond,
      'depositedAmount': depositedAmount,
      'claimedAmount': claimedAmount,
      'bump': bump,
      'claimableAmount': getClaimableAmount(),
    };
  }

  @override
  String toString() {
    return 'StreamAccount(${toMap()})';
  }
}