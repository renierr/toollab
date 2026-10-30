import 'dart:convert';

import 'totp_account.dart';
import 'totp_crypto.dart';

enum TotpExportFormat { encryptedBackup, plainBackup, otpAuthLinks }

extension TotpExportFormatInfo on TotpExportFormat {
  String get fileExtension => switch (this) {
    TotpExportFormat.encryptedBackup => 'totpbackup',
    TotpExportFormat.plainBackup => 'json',
    TotpExportFormat.otpAuthLinks => 'txt',
  };

  String get mimeType => switch (this) {
    TotpExportFormat.encryptedBackup => 'application/octet-stream',
    TotpExportFormat.plainBackup => 'application/json',
    TotpExportFormat.otpAuthLinks => 'text/plain',
  };
}

/// Builds the app's own backup files and interoperable `otpauth://` exports.
class TotpBackup {
  TotpBackup._();

  static const formatId = 'tool-lab-totp-backup';
  static const formatVersion = 1;

  static String plain(List<TotpAccount> accounts) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': formatId,
      'version': formatVersion,
      'encrypted': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'accounts': accounts.map((a) => a.toJson()).toList(),
    });
  }

  static Future<String> encrypted(
    List<TotpAccount> accounts,
    String password,
  ) async {
    final payload = jsonEncode({
      'accounts': accounts.map((a) => a.toJson()).toList(),
    });
    final encryptedPayload = await TotpCrypto.encrypt(payload, password);
    return const JsonEncoder.withIndent('  ').convert({
      'format': formatId,
      'version': formatVersion,
      'encrypted': true,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'payload': encryptedPayload,
    });
  }

  static String otpAuthLinks(List<TotpAccount> accounts) {
    return accounts.map((a) => a.otpAuthUri).join('\n');
  }

  static String suggestedFileName(TotpExportFormat format) {
    final now = DateTime.now();
    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'tool-lab-totp-$stamp.${format.fileExtension}';
  }

  static Future<String> build(
    List<TotpAccount> accounts,
    TotpExportFormat format, {
    String? password,
  }) async {
    final active = accounts.where((a) => !a.deleted).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    switch (format) {
      case TotpExportFormat.encryptedBackup:
        if (password == null || password.isEmpty) {
          throw ArgumentError('Encrypted export needs a password');
        }
        return encrypted(active, password);
      case TotpExportFormat.plainBackup:
        return plain(active);
      case TotpExportFormat.otpAuthLinks:
        return otpAuthLinks(active);
    }
  }
}
