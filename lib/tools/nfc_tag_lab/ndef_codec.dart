import 'dart:convert';
import 'dart:typed_data';

class DecodedRecord {
  final int index;
  final String recordType;
  final String mediaType;
  final String lang;
  final String encoding;
  final String value;
  final String rawHex;

  DecodedRecord({
    required this.index,
    required this.recordType,
    required this.mediaType,
    required this.lang,
    required this.encoding,
    required this.value,
    required this.rawHex,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'recordType': recordType,
    'mediaType': mediaType,
    'lang': lang,
    'encoding': encoding,
    'value': value,
    'rawHex': rawHex,
  };
}

class NdefCodec {
  static const List<String> uriPrefixes = [
    '',
    'http://www.',
    'https://www.',
    'http://',
    'https://',
    'tel:',
    'mailto:',
    'ftp://anonymous:anonymous@',
    'ftp://ftp.',
    'ftps://',
    'sftp://',
    'smb://',
    'nfs://',
    'ftp://',
    'dav://',
    'news:',
    'telnet://',
    'imap:',
    'rtsp://',
    'urn:',
    'pop:',
    'sip:',
    'sips:',
    'tftp:',
    'btspp://',
    'btl2cap://',
    'btgoep://',
    'tcpobex://',
    'irdaobex://',
    'file://',
    'urn:epc:id:',
    'urn:epc:tag:',
    'urn:epc:pat:',
    'urn:epc:raw:',
    'urn:epc:',
    'urn:nfc:',
  ];

  static String toHex(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  static String decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  static String decodeUriPayload(List<int> payload) {
    if (payload.isEmpty) return '';
    final prefixIndex = payload[0];
    final prefix = prefixIndex < uriPrefixes.length
        ? uriPrefixes[prefixIndex]
        : '';
    final rest = decodeText(payload.sublist(1));
    return '$prefix$rest';
  }

  static Uint8List encodeUriPayload(String uri) {
    final trimmed = uri.trim();
    int bestPrefixIndex = 0;

    for (int i = uriPrefixes.length - 1; i > 0; i--) {
      final prefix = uriPrefixes[i];
      if (prefix.isNotEmpty && trimmed.startsWith(prefix)) {
        bestPrefixIndex = i;
        break;
      }
    }

    final suffix = trimmed.substring(uriPrefixes[bestPrefixIndex].length);
    final suffixBytes = utf8.encode(suffix);
    final payload = Uint8List(suffixBytes.length + 1);
    payload[0] = bestPrefixIndex;
    payload.setAll(1, suffixBytes);
    return payload;
  }

  static Uint8List encodeTextPayload(String text, String lang) {
    final trimmedLang = lang.trim();
    final normalizedLang = RegExp(r'^[a-zA-Z0-9-]{1,8}$').hasMatch(trimmedLang)
        ? trimmedLang
        : 'en';
    final languageBytes = utf8.encode(normalizedLang);
    final textBytes = utf8.encode(text);

    final payload = Uint8List(1 + languageBytes.length + textBytes.length);
    payload[0] = languageBytes.length & 0x3F;
    payload.setAll(1, languageBytes);
    payload.setAll(1 + languageBytes.length, textBytes);
    return payload;
  }

  static String decodeUtf16(List<int> bytes) {
    if (bytes.length < 2) return '';
    final List<int> codeUnits = [];
    bool isLittleEndian = false;
    int start = 0;

    // Check for byte order mark (BOM)
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      isLittleEndian = true;
      start = 2;
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      isLittleEndian = false;
      start = 2;
    }

    for (int i = start; i < bytes.length - 1; i += 2) {
      final codeUnit = isLittleEndian
          ? (bytes[i + 1] << 8) | bytes[i]
          : (bytes[i] << 8) | bytes[i + 1];
      codeUnits.add(codeUnit);
    }
    try {
      return String.fromCharCodes(codeUnits);
    } catch (_) {
      return '';
    }
  }

  static Map<String, String> decodeWellKnownTextPayload(List<int> payload) {
    if (payload.isEmpty) {
      return {'lang': '', 'value': '', 'encoding': 'utf-8'};
    }

    final status = payload[0];
    final languageLength = status & 0x3F;
    final isUtf16 = (status & 0x80) != 0;

    if (1 + languageLength > payload.length) {
      return {'lang': '', 'value': '', 'encoding': 'utf-8'};
    }

    final langBytes = payload.sublist(1, 1 + languageLength);
    final textBytes = payload.sublist(1 + languageLength);

    final lang = decodeText(langBytes);
    String value = '';
    try {
      value = isUtf16 ? decodeUtf16(textBytes) : decodeText(textBytes);
    } catch (_) {
      value = decodeText(textBytes);
    }

    return {
      'lang': lang,
      'value': value,
      'encoding': isUtf16 ? 'utf-16' : 'utf-8',
    };
  }

  static DecodedRecord decodeRawRecord(
    int tnf,
    List<int> typeBytes,
    List<int> payload,
    int index,
  ) {
    final typeString = decodeText(typeBytes);

    if (tnf == 0x01 && typeString == 'T') {
      final text = decodeWellKnownTextPayload(payload);
      return DecodedRecord(
        index: index,
        recordType: 'text',
        mediaType: '',
        lang: text['lang']!,
        encoding: text['encoding']!,
        value: text['value']!,
        rawHex: toHex(payload),
      );
    }

    if (tnf == 0x01 && typeString == 'U') {
      return DecodedRecord(
        index: index,
        recordType: 'url',
        mediaType: '',
        lang: '',
        encoding: 'utf-8',
        value: decodeUriPayload(payload),
        rawHex: toHex(payload),
      );
    }

    if (tnf == 0x02) {
      return DecodedRecord(
        index: index,
        recordType: 'mime',
        mediaType: typeString,
        lang: '',
        encoding: 'utf-8',
        value: decodeText(payload),
        rawHex: toHex(payload),
      );
    }

    return DecodedRecord(
      index: index,
      recordType: 'tnf-$tnf:${typeString.isNotEmpty ? typeString : "unknown"}',
      mediaType: '',
      lang: '',
      encoding: '',
      value: decodeText(payload),
      rawHex: toHex(payload),
    );
  }

  static List<DecodedRecord> parseNdefMessageHex(String hexInput) {
    final cleaned = hexInput
        .replaceAll(RegExp(r'0x', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-fA-F0-9]'), '');

    if (cleaned.isEmpty) return [];
    if (cleaned.length % 2 != 0) {
      throw const FormatException('Hex input has an odd number of characters.');
    }

    final bytes = Uint8List(cleaned.length ~/ 2);
    for (int i = 0; i < cleaned.length; i += 2) {
      bytes[i ~/ 2] = int.parse(cleaned.substring(i, i + 2), radix: 16);
    }

    final List<DecodedRecord> records = [];
    int cursor = 0;

    while (cursor < bytes.length) {
      if (cursor + 2 > bytes.length) {
        throw const FormatException(
          'Unexpected end of NDEF data while reading record header.',
        );
      }

      final header = bytes[cursor++];
      final shortRecord = (header & 0x10) != 0;
      final idLengthPresent = (header & 0x08) != 0;
      final chunkFlag = (header & 0x20) != 0;
      final tnf = header & 0x07;

      if (chunkFlag) {
        throw const FormatException('Chunked NDEF records are not supported.');
      }

      final typeLength = bytes[cursor++];

      if (cursor >= bytes.length) {
        throw const FormatException(
          'Unexpected end of NDEF data while reading payload length.',
        );
      }

      int payloadLength = 0;
      if (shortRecord) {
        payloadLength = bytes[cursor++];
      } else {
        if (cursor + 4 > bytes.length) {
          throw const FormatException(
            'Unexpected end of NDEF data while reading 32-bit payload length.',
          );
        }
        payloadLength =
            (bytes[cursor] << 24) |
            (bytes[cursor + 1] << 16) |
            (bytes[cursor + 2] << 8) |
            bytes[cursor + 3];
        cursor += 4;
      }

      int idLength = 0;
      if (idLengthPresent) {
        if (cursor >= bytes.length) {
          throw const FormatException(
            'Unexpected end of NDEF data while reading ID length.',
          );
        }
        idLength = bytes[cursor++];
      }

      if (cursor + typeLength + idLength + payloadLength > bytes.length) {
        throw const FormatException(
          'NDEF payload length exceeds available bytes.',
        );
      }

      final typeBytes = bytes.sublist(cursor, cursor + typeLength);
      cursor += typeLength;
      cursor += idLength; // Skip ID bytes for now

      final payloadBytes = bytes.sublist(cursor, cursor + payloadLength);
      cursor += payloadLength;

      final decoded = decodeRawRecord(
        tnf,
        typeBytes,
        payloadBytes,
        records.length,
      );
      records.add(decoded);
    }

    return records;
  }

  static String encodeSingleRecordNdefHex({
    required String recordType,
    required String payload,
    String lang = 'en',
    String mimeType = '',
  }) {
    int tnf = 0x01;
    List<int> typeBytes = [];
    List<int> payloadBytes = [];

    if (recordType == 'text') {
      typeBytes = utf8.encode('T');
      payloadBytes = encodeTextPayload(payload, lang);
    } else if (recordType == 'url') {
      typeBytes = utf8.encode('U');
      payloadBytes = encodeUriPayload(payload);
    } else if (recordType == 'mime') {
      tnf = 0x02;
      final media = mimeType.trim().toLowerCase();
      if (media.isEmpty || !media.contains('/')) {
        throw const FormatException('A valid MIME type is required.');
      }
      typeBytes = utf8.encode(media);
      payloadBytes = utf8.encode(payload);
    } else {
      throw FormatException('Unsupported record type: $recordType');
    }

    final bool shortRecord = payloadBytes.length <= 255;
    // MB (Message Begin) = 1, ME (Message End) = 1, CF = 0, SR = shortRecord, IL = 0, TNF = tnf
    final int header = 0x80 | 0x40 | (shortRecord ? 0x10 : 0x00) | tnf;

    final List<int> messageBytes = [];
    messageBytes.add(header);
    messageBytes.add(typeBytes.length);

    if (shortRecord) {
      messageBytes.add(payloadBytes.length);
    } else {
      final len = payloadBytes.length;
      messageBytes.addAll([
        (len >>> 24) & 0xFF,
        (len >>> 16) & 0xFF,
        (len >>> 8) & 0xFF,
        len & 0xFF,
      ]);
    }

    messageBytes.addAll(typeBytes);
    messageBytes.addAll(payloadBytes);

    return toHex(messageBytes);
  }
}
