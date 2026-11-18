import 'dart:typed_data';

/// Nonce and counter of the current connection to a vehicle, read from its
/// session characteristic (ffe2). Only valid on the connection it was read
/// on: the vehicle picks a new random nonce on every connect, so messages
/// made for one connection (for example recorded by a fake vehicle) are
/// useless on any other.
class VehicleSession {
  final Uint8List nonce;
  int nextCounter;

  VehicleSession({required this.nonce, required this.nextCounter});

  /// Hands out the counter for the next command. A counter is never handed
  /// out twice, one whose write failed is simply skipped (the firmware
  /// accepts counters up to 63 ahead of its own).
  int takeCounter() => nextCounter++;
}
