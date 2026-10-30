import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/totp_auth/totp.dart';
import 'package:tool_lab/tools/totp_auth/totp_account.dart';
import 'package:tool_lab/tools/totp_auth/totp_backup.dart';
import 'package:tool_lab/tools/totp_auth/totp_crypto.dart';
import 'package:tool_lab/tools/totp_auth/totp_import.dart';

TotpAccount _account({
  String issuer = 'GitHub',
  String account = 'user',
  String secret = 'JBSWY3DPEHPK3PXP',
  TotpAlgorithm algorithm = TotpAlgorithm.sha1,
  int digits = 6,
  int period = 30,
  TotpType type = TotpType.totp,
  int counter = 0,
}) {
  return TotpAccount.newAccount(
    issuer: issuer,
    accountName: account,
    secret: secret,
    algorithm: algorithm,
    digits: digits,
    period: period,
    type: type,
    counter: counter,
  );
}

List<int> _varint(int value) {
  final out = <int>[];
  var v = value;
  while (v >= 0x80) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return out;
}

List<int> _field(int number, int wire, List<int> payload) {
  return [
    ..._varint((number << 3) | wire),
    ..._varint(payload.length),
    ...payload,
  ];
}

String _migrationUri() {
  final secret = Totp.decodeBase32('JBSWY3DPEHPK3PXP');
  final entry = <int>[
    ..._field(1, 2, secret),
    ..._field(2, 2, utf8.encode('user@example.com')),
    ..._field(3, 2, utf8.encode('Example')),
    ..._varint((4 << 3) | 0),
    ..._varint(2), // SHA256
    ..._varint((5 << 3) | 0),
    ..._varint(2), // eight digits
    ..._varint((6 << 3) | 0),
    ..._varint(2), // TOTP
  ];
  final payload = _field(1, 2, entry);
  return 'otpauth-migration://offline?data=${base64Encode(payload)}';
}

Future<String> _encryptedTwoFas(List<Map<String, dynamic>> services) async {
  final salt = List<int>.generate(16, (i) => i + 1);
  final nonce = List<int>.generate(12, (i) => i + 20);
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 10000,
    bits: 256,
  ).deriveKeyFromPassword(password: 'secret123', nonce: salt);
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode({'services': services})),
    secretKey: key,
    nonce: nonce,
  );
  final cipher = [...box.cipherText, ...box.mac.bytes];
  return '${base64Encode(cipher)}:${base64Encode(salt)}:${base64Encode(nonce)}';
}

void main() {
  group('otpauth parsing', () {
    test('reads issuer, account and parameters', () {
      final parts = Totp.parseOtpAuthUri(
        'otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP'
        '&issuer=GitHub&algorithm=SHA256&digits=8&period=60',
      );
      expect(parts, isNotNull);
      expect(parts!.issuer, 'GitHub');
      expect(parts.account, 'alice');
      expect(parts.algorithm, TotpAlgorithm.sha256);
      expect(parts.digits, 8);
      expect(parts.period, 60);
      expect(parts.type, TotpType.totp);
    });

    test('reads HOTP counter', () {
      final parts = Totp.parseOtpAuthUri(
        'otpauth://hotp/Example:bob?secret=JBSWY3DPEHPK3PXP&counter=4',
      );
      expect(parts!.type, TotpType.hotp);
      expect(parts.counter, 4);
    });

    test('rejects non-otp payloads', () {
      expect(Totp.parseOtpAuthUri('https://example.com'), isNull);
      expect(Totp.parseOtpAuthUri('otpauth://totp/x?secret=!!!'), isNull);
    });

    test('round-trips through account links', () {
      final account = _account(algorithm: TotpAlgorithm.sha512, digits: 7);
      final parsed = TotpAccount.fromUri(account.otpAuthUri);
      expect(parsed.issuer, account.issuer);
      expect(parsed.accountName, account.accountName);
      expect(parsed.secret, account.secret);
      expect(parsed.algorithm, TotpAlgorithm.sha512);
      expect(parsed.digits, 7);
    });
  });

  group('import formats', () {
    test('andOTP entry list', () async {
      final result = await TotpImporter.parseText(
        jsonEncode([
          {
            'type': 'TOTP',
            'secret': 'JBSWY3DPEHPK3PXP',
            'label': 'alice',
            'issuer': 'GitLab',
            'algorithm': 'SHA1',
            'digits': 6,
            'period': 30,
          },
        ]),
      );
      expect(result.accounts, hasLength(1));
      expect(result.accounts.single.issuer, 'GitLab');
      expect(result.accounts.single.accountName, 'alice');
    });

    test('Aegis plaintext database', () async {
      final result = await TotpImporter.parseText(
        jsonEncode({
          'version': 1,
          'db': {
            'entries': [
              {
                'type': 'totp',
                'name': 'bob',
                'issuer': 'Aegis',
                'info': {
                  'secret': 'JBSWY3DPEHPK3PXP',
                  'algo': 'SHA1',
                  'digits': 6,
                  'period': 30,
                },
              },
            ],
          },
        }),
      );
      expect(result.format, 'Aegis');
      expect(result.accounts.single.accountName, 'bob');
    });

    test('Aegis encrypted export is rejected clearly', () async {
      await expectLater(
        TotpImporter.parseText(
          jsonEncode({
            'header': {'slots': []},
            'db': 'ciphertext',
          }),
        ),
        throwsA(
          isA<TotpImportException>().having(
            (e) => e.code,
            'code',
            TotpImportErrorCode.encryptedUnsupported,
          ),
        ),
      );
    });

    test('2FAS plaintext services', () async {
      final result = await TotpImporter.parseText(
        jsonEncode({
          'services': [
            {
              'name': '2FAS Service',
              'secret': 'JBSWY3DPEHPK3PXP',
              'otp': {
                'account': 'carol',
                'digits': 6,
                'period': 30,
                'algorithm': 'SHA1',
                'tokenType': 'TOTP',
              },
            },
          ],
          'schemaVersion': 4,
        }),
      );
      expect(result.format, '2FAS');
      expect(result.accounts.single.issuer, '2FAS Service');
      expect(result.accounts.single.accountName, 'carol');
    });

    test('2FAS encrypted services', () async {
      final payload = await _encryptedTwoFas([
        {
          'name': 'Encrypted',
          'secret': 'JBSWY3DPEHPK3PXP',
          'otp': {'account': 'dave'},
        },
      ]);
      await expectLater(
        TotpImporter.parseText(jsonEncode({'servicesEncrypted': payload})),
        throwsA(
          isA<TotpImportException>().having(
            (e) => e.code,
            'code',
            TotpImportErrorCode.passwordRequired,
          ),
        ),
      );
      final result = await TotpImporter.parseText(
        jsonEncode({'servicesEncrypted': payload}),
        password: 'secret123',
      );
      expect(result.accounts.single.accountName, 'dave');
    });

    test('2FAS wrong password', () async {
      final payload = await _encryptedTwoFas([
        {'name': 'X', 'secret': 'JBSWY3DPEHPK3PXP'},
      ]);
      await expectLater(
        TotpImporter.parseText(
          jsonEncode({'servicesEncrypted': payload}),
          password: 'nope',
        ),
        throwsA(
          isA<TotpImportException>().having(
            (e) => e.code,
            'code',
            TotpImportErrorCode.wrongPassword,
          ),
        ),
      );
    });

    test('Google Authenticator migration URI', () async {
      final result = await TotpImporter.parseText(_migrationUri());
      expect(result.format, 'Google Authenticator');
      final account = result.accounts.single;
      expect(account.issuer, 'Example');
      expect(account.accountName, 'user@example.com');
      expect(account.algorithm, TotpAlgorithm.sha256);
      expect(account.digits, 8);
      expect(account.secret, 'JBSWY3DPEHPK3PXP');
    });

    test('Bitwarden item with otpauth link', () async {
      final result = await TotpImporter.parseText(
        jsonEncode({
          'items': [
            {
              'name': 'Vault entry',
              'login': {
                'username': 'erin',
                'totp': 'otpauth://totp/Vault:erin?secret=JBSWY3DPEHPK3PXP',
              },
            },
          ],
        }),
      );
      expect(result.accounts.single.issuer, 'Vault');
      expect(result.accounts.single.accountName, 'erin');
    });

    test('plain otpauth link list', () async {
      final result = await TotpImporter.parseText(
        '${_account(issuer: 'A', account: 'a').otpAuthUri}\n'
        '${_account(issuer: 'B', account: 'b').otpAuthUri}',
      );
      expect(result.accounts, hasLength(2));
    });

    test('unknown JSON is reported as empty', () async {
      await expectLater(
        TotpImporter.parseText(jsonEncode({'hello': 'world'})),
        throwsA(
          isA<TotpImportException>().having(
            (e) => e.code,
            'code',
            TotpImportErrorCode.empty,
          ),
        ),
      );
    });
  });

  group('own backups', () {
    test('encrypted backup round-trips', () async {
      final accounts = [
        _account(issuer: 'One', account: 'a'),
        _account(
          issuer: 'Two',
          account: 'b',
          algorithm: TotpAlgorithm.sha256,
          digits: 8,
          period: 60,
        ),
      ];
      final payload = await TotpBackup.build(
        accounts,
        TotpExportFormat.encryptedBackup,
        password: 'correct horse',
      );
      final result = await TotpImporter.parseText(
        payload,
        password: 'correct horse',
      );
      expect(result.format, 'ToolLab');
      expect(result.accounts, hasLength(2));
      expect(result.accounts[0].accountName, 'a');
      expect(result.accounts[1].accountName, 'b');
      expect(result.accounts[1].algorithm, TotpAlgorithm.sha256);
      expect(result.accounts[1].period, 60);
    });

    test('plain backup round-trips', () async {
      final accounts = [_account(issuer: 'Plain', account: 'p')];
      final payload = await TotpBackup.build(
        accounts,
        TotpExportFormat.plainBackup,
      );
      final result = await TotpImporter.parseText(payload);
      expect(result.accounts.single.issuer, 'Plain');
      expect(result.accounts.single.accountName, 'p');
    });

    test('otpauth export is importable', () async {
      final accounts = [_account(issuer: 'Links', account: 'l')];
      final payload = await TotpBackup.build(
        accounts,
        TotpExportFormat.otpAuthLinks,
      );
      final result = await TotpImporter.parseText(payload);
      expect(result.accounts.single.issuer, 'Links');
    });

    test('legacy raw encrypted export still imports', () async {
      final payload = await TotpCrypto.encrypt(
        jsonEncode([_account(issuer: 'Legacy', account: 'old').toJson()]),
        'legacy-password',
      );
      final result = await TotpImporter.parseText(
        payload,
        password: 'legacy-password',
      );
      expect(result.accounts.single.issuer, 'Legacy');
    });

    test('wrong password is reported', () async {
      final payload = await TotpBackup.build(
        [_account()],
        TotpExportFormat.encryptedBackup,
        password: 'right-password',
      );
      await expectLater(
        TotpImporter.parseText(payload, password: 'wrong-password'),
        throwsA(
          isA<TotpImportException>().having(
            (e) => e.code,
            'code',
            TotpImportErrorCode.wrongPassword,
          ),
        ),
      );
    });
  });
}
