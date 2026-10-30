import 'dart:math';

import 'totp.dart';

class TotpAccount {
  TotpAccount({
    required this.id,
    required this.issuer,
    required this.accountName,
    required this.secret,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.type = TotpType.totp,
    this.counter = 0,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  factory TotpAccount.newAccount({
    required String issuer,
    required String accountName,
    required String secret,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
    int digits = 6,
    int period = 30,
    TotpType type = TotpType.totp,
    int counter = 0,
    int sortOrder = 0,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return TotpAccount(
      id: newId(),
      issuer: issuer.trim(),
      accountName: accountName.trim(),
      secret: Totp.normalizeSecret(secret),
      algorithm: algorithm,
      digits: digits,
      period: period,
      type: type,
      counter: counter,
      sortOrder: sortOrder,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory TotpAccount.fromUri(String uri) {
    final parts = Totp.parseOtpAuthUri(uri);
    if (parts == null) {
      throw const FormatException('Not a valid otpauth link');
    }
    return TotpAccount.newAccount(
      issuer: parts.issuer,
      accountName: parts.account,
      secret: parts.secret,
      algorithm: parts.algorithm,
      digits: parts.digits,
      period: parts.period,
      type: parts.type,
      counter: parts.counter,
    );
  }

  static final Random _random = Random.secure();

  static String newId() {
    final suffix = _random.nextInt(0x7fffffff).toRadixString(36);
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  final String id;
  String issuer;
  String accountName;
  String secret; // Base32, normalized
  TotpAlgorithm algorithm;
  int digits;
  int period;
  TotpType type;
  int counter;
  int sortOrder;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  String get title => issuer.isNotEmpty ? issuer : accountName;

  String get subtitle => issuer.isEmpty ? '' : accountName;

  String get otpAuthUri => Totp.buildOtpAuthUri(
    type: type,
    issuer: issuer,
    account: accountName,
    secret: secret,
    algorithm: algorithm,
    digits: digits,
    period: period,
    counter: counter,
  );

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return issuer.toLowerCase().contains(q) ||
        accountName.toLowerCase().contains(q);
  }

  bool sameIdentity(TotpAccount other) {
    return Totp.normalizeSecret(secret) == Totp.normalizeSecret(other.secret) &&
        issuer.trim().toLowerCase() == other.issuer.trim().toLowerCase() &&
        accountName.trim().toLowerCase() ==
            other.accountName.trim().toLowerCase();
  }

  /// Storage map for the namespaced SQLite table.
  Map<String, Object?> toMap() => {
    'id': id,
    'issuer': issuer,
    'account_name': accountName,
    'secret': secret,
    'algorithm': algorithm.name,
    'digits': digits,
    'period': period,
    'type': type.name,
    'counter': counter,
    'sort_order': sortOrder,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted': deleted ? 1 : 0,
  };

  /// Portable map used by backups and sync. Accepts both key styles.
  Map<String, Object?> toJson() => {
    'id': id,
    'issuer': issuer,
    'accountName': accountName,
    'secret': secret,
    'algorithm': algorithmName,
    'digits': digits,
    'period': period,
    'type': type.name,
    'counter': counter,
    'sortOrder': sortOrder,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'deleted': deleted,
  };

  String get algorithmName => Totp.algorithmName(algorithm);

  factory TotpAccount.fromMap(Map<String, dynamic> m) {
    final algorithmRaw =
        (m['algorithm'] as String?) ?? (m['algo'] as String?) ?? 'sha1';
    final typeRaw = (m['type'] as String?)?.toLowerCase();
    final createdAt =
        (m['createdAt'] as num?)?.toInt() ??
        (m['created_at'] as num?)?.toInt() ??
        0;
    final updatedAt =
        (m['updatedAt'] as num?)?.toInt() ??
        (m['updated_at'] as num?)?.toInt() ??
        createdAt;
    final deletedRaw = m['deleted'];
    return TotpAccount(
      id: (m['id'] as String?) ?? newId(),
      issuer: (m['issuer'] as String?) ?? '',
      accountName:
          (m['accountName'] as String?) ?? (m['account_name'] as String?) ?? '',
      secret: Totp.normalizeSecret((m['secret'] as String?) ?? ''),
      algorithm: Totp.algorithmFromName(algorithmRaw),
      digits: ((m['digits'] as num?)?.toInt() ?? 6).clamp(6, 8),
      period: ((m['period'] as num?)?.toInt() ?? 30).clamp(1, 3600),
      type: typeRaw == 'hotp' ? TotpType.hotp : TotpType.totp,
      counter: (m['counter'] as num?)?.toInt() ?? 0,
      sortOrder:
          (m['sortOrder'] as num?)?.toInt() ??
          (m['sort_order'] as num?)?.toInt() ??
          0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      deleted: deletedRaw == true || deletedRaw == 1,
    );
  }

  TotpAccount copy() => TotpAccount(
    id: id,
    issuer: issuer,
    accountName: accountName,
    secret: secret,
    algorithm: algorithm,
    digits: digits,
    period: period,
    type: type,
    counter: counter,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}
