import 'dart:convert';
import 'dart:typed_data';

class Esp32ResponseParser {
  final List<int> value;

  Esp32ResponseParser(this.value);

  /// Gets the command
  int get command => value.isNotEmpty ? value[0] : 0;

  /// Checks if there's additional data
  bool get hasData => value.length > 1;

  /// Get the data length (second byte if it exists)
  int get dataLength => value.length > 1 ? value[1] : 0;

  // Get raw data bytes (everything after command and length bytes)
  List<int>? get rawData {
    if (value.length < 2) return null;

    final int declaredLength = value[1];
    final int expectedTotalLength = 1 + 1 + declaredLength;

    if (value.length < expectedTotalLength) {
      print(
          'Warning: Received truncated data. Expected $expectedTotalLength bytes, got ${value.length}.');
      return null;
    }

    return value.sublist(2, 2 + declaredLength);
  }

  /// Extract string
  String? getString() {
    final data = rawData;
    if (data == null) return null;

    try {
      return utf8.decode(data);
    } catch (e) {
      print('Error decoding string: $e');
      return null;
    }
  }

  /// Extract float (4 bytes)
  double? getFloat() {
    final data = rawData;
    if (data == null || data.length != 4) {
      print('Error: Expected 4 bytes for float, got ${data?.length ?? 0}');
      return null;
    }

    // Convert List<int> to Uint8List, then to ByteData to read float
    final bytes = Uint8List.fromList(data);
    final byteData = ByteData.sublistView(bytes);

    // Read as little-endian float (ESP32 is little-endian)
    return byteData.getFloat32(0, Endian.little);
  }

  /// Extract int32 (4 bytes)
  int? getInt32() {
    final data = rawData;
    if (data == null || data.length != 4) {
      print('Error: Expected 4 bytes for int32, got ${data?.length ?? 0}');
      return null;
    }

    final bytes = Uint8List.fromList(data);
    final byteData = ByteData.sublistView(bytes);

    return byteData.getInt32(0, Endian.little);
  }

  /// Extract uint32 (4 bytes)
  int? getUint32() {
    final data = rawData;
    if (data == null || data.length != 4) {
      print('Error: Expected 4 bytes for uint32, got ${data?.length ?? 0}');
      return null;
    }

    final bytes = Uint8List.fromList(data);
    final byteData = ByteData.sublistView(bytes);

    return byteData.getUint32(0, Endian.little);
  }

  /// Extract int16 (2 bytes)
  int? getInt16() {
    final data = rawData;
    if (data == null || data.length != 2) {
      print('Error: Expected 2 bytes for int16, got ${data?.length ?? 0}');
      return null;
    }

    final bytes = Uint8List.fromList(data);
    final byteData = ByteData.sublistView(bytes);

    return byteData.getInt16(0, Endian.little);
  }

  /// Extract uint16 (2 bytes)
  int? getUint16() {
    final data = rawData;
    if (data == null || data.length != 2) {
      print('Error: Expected 2 bytes for uint16, got ${data?.length ?? 0}');
      return null;
    }

    final bytes = Uint8List.fromList(data);
    final byteData = ByteData.sublistView(bytes);

    return byteData.getUint16(0, Endian.little);
  }

  /// Extract single byte
  int? getByte() {
    final data = rawData;
    if (data == null || data.length != 1) {
      print('Error: Expected 1 byte, got ${data?.length ?? 0}');
      return null;
    }

    return data[0];
  }

  /// Extract boolean (1 byte, 0 = false, non-zero = true)
  bool? getBool() {
    final byte = getByte();
    return byte != null ? byte != 0 : null;
  }
}
