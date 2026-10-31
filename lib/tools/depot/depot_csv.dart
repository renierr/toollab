import 'dart:convert';
import 'dart:typed_data';

class DepotCsv {
  DepotCsv._();

  static Uint8List encode(String header, Iterable<List<Object?>> rows) {
    final out = StringBuffer('\uFEFF')..writeln(header);
    for (final row in rows) {
      out.writeln(row.map(_cell).join(','));
    }
    return Uint8List.fromList(utf8.encode(out.toString()));
  }

  static String _cell(Object? value) {
    var text = value?.toString() ?? '';
    if (value is String && RegExp(r'^\s*[=+\-@\t\r]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}
