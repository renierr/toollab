import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// The kinds of structured payloads the QR creator can encode.
enum QrContentType { text, url, wifi, email, phone, sms, geo, vcard }

/// Supported Wi-Fi authentication schemes for the [QrContentType.wifi] payload.
enum QrWifiEncryption { wpa, wep, none }

extension QrContentTypeMeta on QrContentType {
  IconData get icon {
    switch (this) {
      case QrContentType.text:
        return Icons.notes_outlined;
      case QrContentType.url:
        return Icons.link_outlined;
      case QrContentType.wifi:
        return Icons.wifi_outlined;
      case QrContentType.email:
        return Icons.mail_outline;
      case QrContentType.phone:
        return Icons.phone_outlined;
      case QrContentType.sms:
        return Icons.sms_outlined;
      case QrContentType.geo:
        return Icons.place_outlined;
      case QrContentType.vcard:
        return Icons.contact_page_outlined;
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case QrContentType.text:
        return l10n.qrTypeText;
      case QrContentType.url:
        return l10n.qrTypeUrl;
      case QrContentType.wifi:
        return l10n.qrTypeWifi;
      case QrContentType.email:
        return l10n.qrTypeEmail;
      case QrContentType.phone:
        return l10n.qrTypePhone;
      case QrContentType.sms:
        return l10n.qrTypeSms;
      case QrContentType.geo:
        return l10n.qrTypeGeo;
      case QrContentType.vcard:
        return l10n.qrTypeVcard;
    }
  }
}

/// Pure functions that turn user input into the canonical QR payload string for
/// each [QrContentType]. Returns an empty string when the required fields are
/// blank so the caller can disable generation.
class QrPayloadBuilder {
  QrPayloadBuilder._();

  static String text(String value) => value.trim();

  static String url(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(v);
    return hasScheme ? v : 'https://$v';
  }

  static String wifi({
    required String ssid,
    required String password,
    required QrWifiEncryption encryption,
    required bool hidden,
  }) {
    final s = ssid.trim();
    if (s.isEmpty) return '';
    final t = switch (encryption) {
      QrWifiEncryption.wpa => 'WPA',
      QrWifiEncryption.wep => 'WEP',
      QrWifiEncryption.none => 'nopass',
    };
    final pwd = encryption == QrWifiEncryption.none ? '' : password;
    return 'WIFI:T:$t;S:${_escape(s)};P:${_escape(pwd)};H:$hidden;;';
  }

  static String email({
    required String address,
    required String subject,
    required String body,
  }) {
    final addr = address.trim();
    if (addr.isEmpty) return '';
    final params = <String>[];
    if (subject.trim().isNotEmpty) {
      params.add('subject=${Uri.encodeComponent(subject.trim())}');
    }
    if (body.trim().isNotEmpty) {
      params.add('body=${Uri.encodeComponent(body.trim())}');
    }
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return 'mailto:$addr$query';
  }

  static String phone(String number) {
    final n = number.trim();
    return n.isEmpty ? '' : 'tel:$n';
  }

  static String sms({required String number, required String message}) {
    final n = number.trim();
    if (n.isEmpty) return '';
    final m = message.trim();
    return m.isEmpty ? 'SMSTO:$n:' : 'SMSTO:$n:$m';
  }

  static String geo({required String latitude, required String longitude}) {
    final lat = latitude.trim();
    final lng = longitude.trim();
    if (lat.isEmpty || lng.isEmpty) return '';
    return 'geo:$lat,$lng';
  }

  static String vcard({
    required String name,
    required String phone,
    required String email,
    required String organization,
    required String url,
  }) {
    if (name.trim().isEmpty && phone.trim().isEmpty && email.trim().isEmpty) {
      return '';
    }
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('N:${name.trim()}')
      ..writeln('FN:${name.trim()}');
    if (organization.trim().isNotEmpty) {
      buffer.writeln('ORG:${organization.trim()}');
    }
    if (phone.trim().isNotEmpty) buffer.writeln('TEL:${phone.trim()}');
    if (email.trim().isNotEmpty) buffer.writeln('EMAIL:${email.trim()}');
    if (url.trim().isNotEmpty) buffer.writeln('URL:${url.trim()}');
    buffer.write('END:VCARD');
    return buffer.toString();
  }

  /// Escapes the reserved characters inside Wi-Fi SSID / password values.
  static String _escape(String value) {
    return value.replaceAllMapped(
      RegExp(r'[\\;,:"]'),
      (m) => '\\${m.group(0)}',
    );
  }
}
