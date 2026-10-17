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
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  String issuer;
  String accountName;
  String secret; // base32
  TotpAlgorithm algorithm;
  int digits;
  int period;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  Map<String, dynamic> toMap() => {
        'id': id,
        'issuer': issuer,
        'accountName': accountName,
        'secret': secret,
        'algorithm': algorithm.name,
        'digits': digits,
        'period': period,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  factory TotpAccount.fromMap(Map<String, dynamic> m) => TotpAccount(
        id: m['id'] as String,
        issuer: m['issuer'] as String? ?? '',
        accountName: m['accountName'] as String? ?? '',
        secret: m['secret'] as String,
        algorithm: TotpAlgorithm.values.firstWhere(
          (a) => a.name == (m['algorithm'] as String? ?? 'sha1'),
          orElse: () => TotpAlgorithm.sha1,
        ),
        digits: (m['digits'] as num?)?.toInt() ?? 6,
        period: (m['period'] as num?)?.toInt() ?? 30,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['createdAt'] as num?)?.toInt() ?? 0,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0,
        ),
        deleted: m['deleted'] == true || m['deleted'] == 1,
      );

  TotpAccount copy() => TotpAccount(
        id: id,
        issuer: issuer,
        accountName: accountName,
        secret: secret,
        algorithm: algorithm,
        digits: digits,
        period: period,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deleted: deleted,
      );
}
