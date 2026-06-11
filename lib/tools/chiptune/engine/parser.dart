import 'dart:typed_data';

import 'module.dart';
import 'parsers/it_parser.dart';
import 'parsers/mod_parser.dart';
import 'parsers/xm_parser.dart';

/// Detects the tracker format from the file header and parses accordingly.
ModuleFile parseModule(Uint8List data) {
  if (readString(data, 0, 4) == 'IMPM') return parseIt(data);
  if (readString(data, 0, 17).startsWith('Extended Module:')) {
    return parseXm(data);
  }
  return parseMod(data);
}

/// Returns the format label for a header, or null if unrecognised.
String? detectFormat(Uint8List data) {
  if (data.length < 4) return null;
  if (readString(data, 0, 4) == 'IMPM') return 'IT';
  if (data.length >= 17 &&
      readString(data, 0, 17).startsWith('Extended Module:')) {
    return 'XM';
  }
  // MOD: assume valid if it carries a known marker or is large enough.
  return 'MOD';
}
