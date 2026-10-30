import 'dart:convert';
import 'dart:typed_data';

import 'totp.dart';
import 'totp_account.dart';
import 'totp_crypto.dart';

enum TotpImportErrorCode {
  passwordRequired,
  wrongPassword,
  unsupported,
  encryptedUnsupported,
  empty,
  invalid,
}

class TotpImportException implements Exception {
  final TotpImportErrorCode code;
  final String? format;

  const TotpImportException(this.code, {this.format});

  @override
  String toString() =>
      'TotpImportException($code${format == null ? '' : ': $format'})';
}

class TotpImportResult {
  final String format;
  final List<TotpAccount> accounts;

  const TotpImportResult({required this.format, required this.accounts});
}

/// Reads authenticator backups from the common export formats and from
/// `otpauth://` links. Encrypted 2FAS and ToolLab backups are decrypted with
/// the supplied password; encrypted Aegis exports are rejected because their
/// per-slot master-key scheme is not supported.
class TotpImporter {
  TotpImporter._();

  static const _ownFormat = 'tool-lab-totp-backup';
  static const _base64Pattern = r'^[A-Za-z0-9+/=\s]+$';

  static Future<TotpImportResult> parseText(
    String text, {
    String? password,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const TotpImportException(TotpImportErrorCode.empty);
    }

    if (trimmed.toLowerCase().startsWith('otpauth-migration://')) {
      final accounts = _parseMigrationUri(trimmed);
      if (accounts.isEmpty) {
        throw const TotpImportException(TotpImportErrorCode.empty);
      }
      return TotpImportResult(
        format: 'Google Authenticator',
        accounts: accounts,
      );
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final decoded = _decodeJson(trimmed);
      return _parseJson(decoded, password);
    }

    if (trimmed.toLowerCase().contains('otpauth://')) {
      final accounts = _parseUriText(trimmed);
      if (accounts.isEmpty) {
        throw const TotpImportException(TotpImportErrorCode.empty);
      }
      return TotpImportResult(format: 'otpauth', accounts: accounts);
    }

    if (RegExp(_base64Pattern).hasMatch(trimmed) && trimmed.length > 32) {
      if (password == null || password.isEmpty) {
        throw const TotpImportException(
          TotpImportErrorCode.passwordRequired,
          format: 'ToolLab',
        );
      }
      try {
        final json = await TotpCrypto.decrypt(trimmed, password);
        final decoded = jsonDecode(json);
        final accounts = _parseJsonAccounts(decoded);
        if (accounts.isEmpty) {
          throw const TotpImportException(TotpImportErrorCode.empty);
        }
        return TotpImportResult(format: 'ToolLab', accounts: accounts);
      } on TotpImportException {
        rethrow;
      } catch (_) {
        throw const TotpImportException(
          TotpImportErrorCode.wrongPassword,
          format: 'ToolLab',
        );
      }
    }

    throw const TotpImportException(TotpImportErrorCode.unsupported);
  }

  static dynamic _decodeJson(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      throw const TotpImportException(TotpImportErrorCode.invalid);
    }
  }

  static Future<TotpImportResult> _parseJson(
    dynamic data,
    String? password,
  ) async {
    if (data is List) {
      final accounts = _parseEntries(data);
      if (accounts.isEmpty) {
        final generic = _genericJson(data);
        if (generic.isEmpty) {
          throw const TotpImportException(TotpImportErrorCode.empty);
        }
        return TotpImportResult(format: 'JSON', accounts: generic);
      }
      return TotpImportResult(format: 'andOTP / JSON', accounts: accounts);
    }

    if (data is! Map) {
      throw const TotpImportException(TotpImportErrorCode.unsupported);
    }

    final map = Map<String, dynamic>.from(data);
    final format = (map['format'] as String?)?.toLowerCase();

    if (format == _ownFormat) {
      return _parseOwnBackup(map, password);
    }

    if (map.containsKey('servicesEncrypted') || map.containsKey('services')) {
      return _parseTwoFas(map, password);
    }

    final aegisDb = map['db'];
    if (aegisDb is Map && aegisDb['entries'] is List) {
      final accounts = _parseAegisEntries(aegisDb['entries'] as List);
      if (accounts.isEmpty) {
        throw const TotpImportException(TotpImportErrorCode.empty);
      }
      return TotpImportResult(format: 'Aegis', accounts: accounts);
    }
    if (map.containsKey('header') && (aegisDb is String || aegisDb == null)) {
      throw const TotpImportException(
        TotpImportErrorCode.encryptedUnsupported,
        format: 'Aegis',
      );
    }

    if (map['tokens'] is List) {
      final accounts = _parseEntries(map['tokens'] as List);
      if (accounts.isEmpty) {
        throw const TotpImportException(TotpImportErrorCode.empty);
      }
      return TotpImportResult(format: 'FreeOTP', accounts: accounts);
    }

    if (map['items'] is List) {
      final accounts = _parseBitwarden(map['items'] as List);
      if (accounts.isEmpty) {
        throw const TotpImportException(TotpImportErrorCode.empty);
      }
      return TotpImportResult(format: 'Bitwarden', accounts: accounts);
    }

    final accounts = _parseJsonAccounts(map);
    if (accounts.isNotEmpty) {
      return TotpImportResult(format: 'JSON', accounts: accounts);
    }

    final generic = _genericJson(map);
    if (generic.isNotEmpty) {
      return TotpImportResult(format: 'JSON', accounts: generic);
    }

    throw const TotpImportException(TotpImportErrorCode.empty);
  }

  static Future<TotpImportResult> _parseOwnBackup(
    Map<String, dynamic> map,
    String? password,
  ) async {
    final encrypted = map['encrypted'] == true;
    if (encrypted) {
      if (password == null || password.isEmpty) {
        throw const TotpImportException(
          TotpImportErrorCode.passwordRequired,
          format: 'ToolLab',
        );
      }
      try {
        final clear = await TotpCrypto.decrypt(
          map['payload'] as String,
          password,
        );
        final accounts = _parseJsonAccounts(jsonDecode(clear));
        if (accounts.isEmpty) {
          throw const TotpImportException(TotpImportErrorCode.empty);
        }
        return TotpImportResult(format: 'ToolLab', accounts: accounts);
      } on TotpImportException {
        rethrow;
      } catch (_) {
        throw const TotpImportException(
          TotpImportErrorCode.wrongPassword,
          format: 'ToolLab',
        );
      }
    }

    final accounts = _parseJsonAccounts(map);
    if (accounts.isEmpty) {
      throw const TotpImportException(TotpImportErrorCode.empty);
    }
    return TotpImportResult(format: 'ToolLab', accounts: accounts);
  }

  static Future<TotpImportResult> _parseTwoFas(
    Map<String, dynamic> map,
    String? password,
  ) async {
    List<dynamic> services;
    final encrypted = map['servicesEncrypted'];

    if (encrypted is String && encrypted.isNotEmpty) {
      if (password == null || password.isEmpty) {
        throw const TotpImportException(
          TotpImportErrorCode.passwordRequired,
          format: '2FAS',
        );
      }
      dynamic decrypted;
      try {
        final clear = await TotpCrypto.decryptTwoFas(encrypted, password);
        decrypted = jsonDecode(clear);
      } catch (_) {
        throw const TotpImportException(
          TotpImportErrorCode.wrongPassword,
          format: '2FAS',
        );
      }
      if (decrypted is Map && decrypted['services'] is List) {
        services = decrypted['services'] as List;
      } else if (decrypted is List) {
        services = decrypted;
      } else {
        throw const TotpImportException(TotpImportErrorCode.invalid);
      }
    } else if (map['services'] is List) {
      services = map['services'] as List;
    } else {
      throw const TotpImportException(TotpImportErrorCode.empty);
    }

    final ordered = services.whereType<Map>().toList()
      ..sort((a, b) {
        final pa = (a['order'] is Map ? a['order']['position'] : null) as num?;
        final pb = (b['order'] is Map ? b['order']['position'] : null) as num?;
        return (pa ?? 0).compareTo(pb ?? 0);
      });

    final accounts = <TotpAccount>[];
    for (final raw in ordered) {
      final service = Map<String, dynamic>.from(raw);
      final otpRaw = service['otp'];
      final otp = otpRaw is Map
          ? Map<String, dynamic>.from(otpRaw)
          : <String, dynamic>{};
      final link = _asString(otp['link']);
      final parts = link == null ? null : Totp.parseOtpAuthUri(link);
      final secret = _asString(service['secret']) ?? parts?.secret;
      if (secret == null || !Totp.isValidSecret(secret)) continue;
      final algorithmRaw =
          _asString(otp['algorithm']) ??
          (_asString(service['algorithm']) ?? parts?.algorithm.name);
      if (algorithmRaw?.toUpperCase() == 'MD5') continue;
      final issuer =
          _asString(service['name']) ??
          _asString(otp['issuer']) ??
          parts?.issuer ??
          '';
      final account = _asString(otp['account']) ?? parts?.account ?? '';
      accounts.add(
        TotpAccount.newAccount(
          issuer: issuer,
          accountName: account,
          secret: secret,
          algorithm: Totp.algorithmFromName(algorithmRaw),
          digits: _asInt(otp['digits']) ?? parts?.digits ?? 6,
          period: _asInt(otp['period']) ?? parts?.period ?? 30,
          type: _typeFrom(otp['tokenType']) ?? parts?.type ?? TotpType.totp,
          counter: _asInt(otp['counter']) ?? parts?.counter ?? 0,
        ),
      );
    }

    final unique = _dedupe(accounts);
    if (unique.isEmpty) {
      throw const TotpImportException(TotpImportErrorCode.empty);
    }
    return TotpImportResult(format: '2FAS', accounts: unique);
  }

  static List<TotpAccount> _parseAegisEntries(List<dynamic> entries) {
    final accounts = <TotpAccount>[];
    for (final raw in entries) {
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final infoRaw = entry['info'];
      final info = infoRaw is Map
          ? Map<String, dynamic>.from(infoRaw)
          : <String, dynamic>{};
      final secret = _asString(info['secret']);
      if (secret == null || !Totp.isValidSecret(secret)) continue;
      if (_asString(info['algo'])?.toUpperCase() == 'MD5') continue;
      accounts.add(
        TotpAccount.newAccount(
          issuer: _asString(entry['issuer']) ?? '',
          accountName: _asString(entry['name']) ?? '',
          secret: secret,
          algorithm: Totp.algorithmFromName(_asString(info['algo'])),
          digits: _asInt(info['digits']) ?? 6,
          period: _asInt(info['period']) ?? 30,
          type: _typeFrom(entry['type']) ?? TotpType.totp,
          counter: _asInt(info['counter']) ?? 0,
        ),
      );
    }
    return _dedupe(accounts);
  }

  static List<TotpAccount> _parseBitwarden(List<dynamic> items) {
    final accounts = <TotpAccount>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final loginRaw = item['login'];
      if (loginRaw is! Map) continue;
      final login = Map<String, dynamic>.from(loginRaw);
      final totp = _asString(login['totp']);
      if (totp == null || totp.isEmpty) continue;

      final parts = Totp.parseOtpAuthUri(totp);
      if (parts != null) {
        accounts.add(
          TotpAccount.newAccount(
            issuer: parts.issuer.isEmpty
                ? _asString(item['name']) ?? ''
                : parts.issuer,
            accountName: parts.account.isNotEmpty
                ? parts.account
                : _asString(login['username']) ?? '',
            secret: parts.secret,
            algorithm: parts.algorithm,
            digits: parts.digits,
            period: parts.period,
            type: parts.type,
            counter: parts.counter,
          ),
        );
      } else if (Totp.isValidSecret(totp)) {
        accounts.add(
          TotpAccount.newAccount(
            issuer: _asString(item['name']) ?? '',
            accountName: _asString(login['username']) ?? '',
            secret: totp,
          ),
        );
      }
    }
    return _dedupe(accounts);
  }

  /// andOTP, Raivo, FreeOTP and other flat entry lists.
  static List<TotpAccount> _parseEntries(List<dynamic> entries) {
    final accounts = <TotpAccount>[];
    for (final raw in entries) {
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final secret = _asString(entry['secret']);
      if (secret == null || !Totp.isValidSecret(secret)) continue;
      if (_asString(entry['algorithm'])?.toUpperCase() == 'MD5') continue;
      accounts.add(
        TotpAccount.newAccount(
          issuer: _asString(entry['issuer']) ?? '',
          accountName:
              _asString(entry['label']) ??
              _asString(entry['account']) ??
              _asString(entry['accountName']) ??
              _asString(entry['name']) ??
              '',
          secret: secret,
          algorithm: Totp.algorithmFromName(
            _asString(entry['algorithm']) ?? _asString(entry['algo']),
          ),
          digits: _asInt(entry['digits']) ?? 6,
          period: _asInt(entry['period']) ?? 30,
          type:
              _typeFrom(entry['type']) ??
              _typeFrom(entry['tokenType']) ??
              TotpType.totp,
          counter: _asInt(entry['counter']) ?? 0,
        ),
      );
    }
    return _dedupe(accounts);
  }

  static List<TotpAccount> _parseJsonAccounts(dynamic data) {
    if (data is List) return _parseEntries(data);
    if (data is Map) {
      for (final key in const ['accounts', 'entries', 'services', 'tokens']) {
        final list = data[key];
        if (list is List) {
          final accounts = _parseEntries(list);
          if (accounts.isNotEmpty) return accounts;
        }
      }
      final single = _parseEntries([data]);
      if (single.isNotEmpty) return single;
    }
    return const [];
  }

  /// Last resort for unknown JSON shapes: collect otpauth links and objects
  /// that at least carry a Base32 secret plus a name.
  static List<TotpAccount> _genericJson(dynamic data) {
    final accounts = <TotpAccount>[];
    final seen = <String>{};

    void add(TotpAccount account) {
      final key = '${account.secret}|${account.issuer}|${account.accountName}'
          .toLowerCase();
      if (seen.add(key)) accounts.add(account);
    }

    void walk(dynamic node) {
      if (node is String) {
        final parts = Totp.parseOtpAuthUri(node);
        if (parts != null) {
          add(
            TotpAccount.newAccount(
              issuer: parts.issuer,
              accountName: parts.account,
              secret: parts.secret,
              algorithm: parts.algorithm,
              digits: parts.digits,
              period: parts.period,
              type: parts.type,
              counter: parts.counter,
            ),
          );
        }
        return;
      }
      if (node is List) {
        for (final item in node) {
          walk(item);
        }
        return;
      }
      if (node is Map) {
        final secret = _asString(node['secret']);
        if (secret != null && Totp.isValidSecret(secret)) {
          add(
            TotpAccount.newAccount(
              issuer: _asString(node['issuer']) ?? '',
              accountName:
                  _asString(node['account']) ??
                  _asString(node['label']) ??
                  _asString(node['name']) ??
                  '',
              secret: secret,
              algorithm: Totp.algorithmFromName(_asString(node['algorithm'])),
              digits: _asInt(node['digits']) ?? 6,
              period: _asInt(node['period']) ?? 30,
              type: _typeFrom(node['type']) ?? TotpType.totp,
              counter: _asInt(node['counter']) ?? 0,
            ),
          );
        }
        for (final value in node.values) {
          walk(value);
        }
      }
    }

    walk(data);
    return accounts;
  }

  static List<TotpAccount> _parseUriText(String text) {
    final accounts = <TotpAccount>[];
    final matches = RegExp(r"otpauth://[^\s'<>]+").allMatches(text);
    for (final match in matches) {
      final parts = Totp.parseOtpAuthUri(match.group(0)!);
      if (parts == null) continue;
      accounts.add(
        TotpAccount.newAccount(
          issuer: parts.issuer,
          accountName: parts.account,
          secret: parts.secret,
          algorithm: parts.algorithm,
          digits: parts.digits,
          period: parts.period,
          type: parts.type,
          counter: parts.counter,
        ),
      );
    }
    return _dedupe(accounts);
  }

  static List<TotpAccount> _parseMigrationUri(String uri) {
    final parsed = Uri.tryParse(uri.trim());
    final data = parsed?.queryParameters['data'];
    if (data == null || data.isEmpty) {
      throw const TotpImportException(TotpImportErrorCode.invalid);
    }
    Uint8List bytes;
    try {
      bytes = base64Decode(Uri.decodeComponent(data));
    } catch (_) {
      throw const TotpImportException(TotpImportErrorCode.invalid);
    }

    final accounts = <TotpAccount>[];
    var pos = 0;
    while (pos < bytes.length) {
      final tag = _readVarint(bytes, pos);
      if (tag == null) break;
      pos = tag.next;
      final field = tag.value >> 3;
      final wire = tag.value & 0x07;
      if (field == 1 && wire == 2) {
        final length = _readVarint(bytes, pos);
        if (length == null) break;
        pos = length.next;
        final end = pos + length.value;
        if (end > bytes.length) break;
        final account = _parseMigrationEntry(
          Uint8List.sublistView(bytes, pos, end),
        );
        if (account != null) accounts.add(account);
        pos = end;
      } else {
        pos = _skipField(bytes, pos, wire);
        if (pos < 0) break;
      }
    }
    return _dedupe(accounts);
  }

  static TotpAccount? _parseMigrationEntry(Uint8List bytes) {
    Uint8List? secret;
    var name = '';
    var issuer = '';
    var algorithm = TotpAlgorithm.sha1;
    var digits = 6;
    var type = TotpType.totp;
    var counter = 0;

    var pos = 0;
    while (pos < bytes.length) {
      final tag = _readVarint(bytes, pos);
      if (tag == null) break;
      pos = tag.next;
      final field = tag.value >> 3;
      final wire = tag.value & 0x07;
      if (wire == 2) {
        final length = _readVarint(bytes, pos);
        if (length == null) break;
        pos = length.next;
        final end = pos + length.value;
        if (end > bytes.length) break;
        final chunk = Uint8List.sublistView(bytes, pos, end);
        if (field == 1) {
          secret = chunk;
        } else if (field == 2) {
          name = utf8.decode(chunk, allowMalformed: true);
        } else if (field == 3) {
          issuer = utf8.decode(chunk, allowMalformed: true);
        }
        pos = end;
      } else if (wire == 0) {
        final value = _readVarint(bytes, pos);
        if (value == null) break;
        pos = value.next;
        switch (field) {
          case 4:
            algorithm = switch (value.value) {
              2 => TotpAlgorithm.sha256,
              3 => TotpAlgorithm.sha512,
              _ => TotpAlgorithm.sha1,
            };
          case 5:
            digits = value.value == 2 ? 8 : 6;
          case 6:
            type = value.value == 1 ? TotpType.hotp : TotpType.totp;
          case 7:
            counter = value.value;
        }
      } else {
        pos = _skipField(bytes, pos, wire);
        if (pos < 0) break;
      }
    }

    if (secret == null || secret.isEmpty) return null;
    var accountName = name;
    var accountIssuer = issuer;
    final colon = name.indexOf(':');
    if (accountIssuer.isEmpty && colon >= 0) {
      accountIssuer = name.substring(0, colon).trim();
      accountName = name.substring(colon + 1).trim();
    }

    return TotpAccount.newAccount(
      issuer: accountIssuer,
      accountName: accountName,
      secret: Totp.encodeBase32(secret),
      algorithm: algorithm,
      digits: digits,
      type: type,
      counter: counter,
    );
  }

  static _Varint? _readVarint(Uint8List bytes, int start) {
    var result = 0;
    var shift = 0;
    var pos = start;
    while (pos < bytes.length && shift < 64) {
      final byte = bytes[pos++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return _Varint(result, pos);
      shift += 7;
    }
    return null;
  }

  static int _skipField(Uint8List bytes, int pos, int wire) {
    switch (wire) {
      case 0:
        final value = _readVarint(bytes, pos);
        return value?.next ?? -1;
      case 1:
        return pos + 8 <= bytes.length ? pos + 8 : -1;
      case 2:
        final length = _readVarint(bytes, pos);
        if (length == null) return -1;
        final end = length.next + length.value;
        return end <= bytes.length ? end : -1;
      case 5:
        return pos + 4 <= bytes.length ? pos + 4 : -1;
      default:
        return -1;
    }
  }

  static List<TotpAccount> _dedupe(List<TotpAccount> accounts) {
    final result = <TotpAccount>[];
    for (final account in accounts) {
      if (result.any(account.sameIdentity)) continue;
      result.add(account);
    }
    return result;
  }

  static TotpType? _typeFrom(dynamic value) {
    final raw = _asString(value)?.toUpperCase();
    if (raw == null) return null;
    if (raw.contains('HOTP')) return TotpType.hotp;
    if (raw.contains('TOTP')) return TotpType.totp;
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class _Varint {
  final int value;
  final int next;

  const _Varint(this.value, this.next);
}
