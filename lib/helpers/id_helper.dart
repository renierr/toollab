import 'dart:math';

final Random _random = Random.secure();

const String upperAlphanumeric = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

/// Drops look-alike characters (I, O, 0, 1).
const String unambiguousAlphanumeric = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String randomId(int length, {String alphabet = upperAlphanumeric}) =>
    String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
      ),
    );

/// RFC-4122 v4 UUID, the format of the browser-toolkit `crypto.randomUUID()`.
String randomUuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
