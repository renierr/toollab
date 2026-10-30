import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/totp_auth/totp.dart';

Uint8List _seed(String ascii) => Uint8List.fromList(utf8.encode(ascii));

String _code(String seed, TotpAlgorithm algorithm) {
  return Totp.formatCode(
    Totp.generate(
      secret: _seed(seed),
      timeSeconds: 59,
      digits: 8,
      algorithm: algorithm,
    ),
    8,
  );
}

void main() {
  group('RFC 6238 vectors', () {
    test('SHA1, eight digits', () {
      expect(_code('12345678901234567890', TotpAlgorithm.sha1), '94287082');
    });

    test('SHA256, eight digits', () {
      expect(
        _code('12345678901234567890123456789012', TotpAlgorithm.sha256),
        '46119246',
      );
    });

    test('SHA512, eight digits', () {
      expect(
        _code(
          '1234567890123456789012345678901234567890'
          '123456789012345678901234',
          TotpAlgorithm.sha512,
        ),
        '90693936',
      );
    });
  });

  test('grouped code keeps every digit', () {
    expect(Totp.groupedCode('123456'), '123 456');
    expect(Totp.groupedCode('12345678'), '1234 5678');
    expect(Totp.groupedCode('1234567'), '1234 567');
  });

  test('secret normalization strips spaces and padding', () {
    expect(Totp.normalizeSecret(' jbsw y3dp ehpk 3pxp== '), 'JBSWY3DPEHPK3PXP');
    expect(Totp.isValidSecret('JBSWY3DPEHPK3PXP'), isTrue);
    expect(Totp.isValidSecret('not-base32!'), isFalse);
  });
}
