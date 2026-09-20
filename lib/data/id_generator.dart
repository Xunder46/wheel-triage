import 'dart:math';

/// Generates RFC-4122-style version-4 UUID strings using only `dart:math`
/// (no external `uuid` dependency — not on the brief's approved package
/// list, and this is all either repository implementation needs). Used by
/// both `DriftWheelRepository` and `InMemoryWheelRepository` so every
/// created row gets a stable, opaque, never-auto-incrementing id
/// (docs/conventions.md's naming table).
String generateId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

  String hex(int start, int end) =>
      bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
