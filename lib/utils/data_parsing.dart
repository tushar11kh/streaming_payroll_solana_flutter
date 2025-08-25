import '../models/stream.dart';

class DataParsing {
  static StreamAccount? parseStreamAccount(List<int> data) {
    try {
      return StreamAccount.fromBuffer(data);
    } catch (e) {
      print('Error parsing stream account: $e');
      return null;
    }
  }

  // Helper to convert little-endian bytes to integer
  static int bytesToInt(List<int> bytes, {int offset = 0, int length = 8}) {
    int value = 0;
    for (int i = 0; i < length; i++) {
      value += bytes[offset + i] << (i * 8);
    }
    return value;
  }

  // Helper to convert integer to little-endian bytes
  static List<int> intToBytes(int value, {int length = 8}) {
    final bytes = List<int>.filled(length, 0);
    for (int i = 0; i < length; i++) {
      bytes[i] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }
}