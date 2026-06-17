import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Shows a decoded scan result with quick actions (open / copy / share) and a
/// button to resume scanning.
class QrResultCard extends StatelessWidget {
  final String text;
  final Color accentColor;
  final TempFileScope scope;
  final VoidCallback onScanAgain;

  const QrResultCard({
    super.key,
    required this.text,
    required this.accentColor,
    required this.scope,
    required this.onScanAgain,
  });

  _ScanKind _detectKind() {
    final t = text.trim();
    final lower = t.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return _ScanKind.link;
    }
    if (lower.startsWith('wifi:')) return _ScanKind.wifi;
    if (lower.startsWith('mailto:')) return _ScanKind.email;
    if (lower.startsWith('tel:')) return _ScanKind.phone;
    if (lower.startsWith('smsto:') || lower.startsWith('sms:')) {
      return _ScanKind.sms;
    }
    if (lower.startsWith('geo:')) return _ScanKind.location;
    if (lower.startsWith('begin:vcard')) return _ScanKind.contact;
    return _ScanKind.text;
  }

  /// The URI url_launcher should open, or null when the content is not openable.
  Uri? _launchUri() {
    final t = text.trim();
    switch (_detectKind()) {
      case _ScanKind.link:
      case _ScanKind.email:
      case _ScanKind.phone:
      case _ScanKind.location:
        return Uri.tryParse(t);
      case _ScanKind.sms:
        if (t.toLowerCase().startsWith('smsto:')) {
          final rest = t.substring(6);
          final idx = rest.indexOf(':');
          final number = idx >= 0 ? rest.substring(0, idx) : rest;
          final body = idx >= 0 ? rest.substring(idx + 1) : '';
          return Uri(
            scheme: 'sms',
            path: number,
            queryParameters: body.isEmpty ? null : {'body': body},
          );
        }
        return Uri.tryParse(t);
      case _ScanKind.wifi:
      case _ScanKind.contact:
      case _ScanKind.text:
        return null;
    }
  }

  String _kindLabel(AppLocalizations l10n) {
    switch (_detectKind()) {
      case _ScanKind.link:
        return l10n.qrKindLink;
      case _ScanKind.wifi:
        return l10n.qrKindWifi;
      case _ScanKind.email:
        return l10n.qrKindEmail;
      case _ScanKind.phone:
        return l10n.qrKindPhone;
      case _ScanKind.sms:
        return l10n.qrKindSms;
      case _ScanKind.location:
        return l10n.qrKindLocation;
      case _ScanKind.contact:
        return l10n.qrKindContact;
      case _ScanKind.text:
        return l10n.qrKindText;
    }
  }

  IconData _kindIcon() {
    switch (_detectKind()) {
      case _ScanKind.link:
        return Icons.link_outlined;
      case _ScanKind.wifi:
        return Icons.wifi_outlined;
      case _ScanKind.email:
        return Icons.mail_outline;
      case _ScanKind.phone:
        return Icons.phone_outlined;
      case _ScanKind.sms:
        return Icons.sms_outlined;
      case _ScanKind.location:
        return Icons.place_outlined;
      case _ScanKind.contact:
        return Icons.contact_page_outlined;
      case _ScanKind.text:
        return Icons.notes_outlined;
    }
  }

  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uri = _launchUri();
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.qrOpenFailed)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.qrOpenFailed)));
      }
    }
  }

  Future<void> _copy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await ClipboardHelper.setText(text);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.qrCopied)));
    }
  }

  Future<void> _share(BuildContext context) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    final path = await scope.createFile('qr_content.txt', bytes: bytes);
    if (!context.mounted) return;
    await FileSaveHelper.showShareChooser(
      context: context,
      path: path,
      mimeType: 'text/plain',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final canOpen = _launchUri() != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_kindIcon(), color: accentColor, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        _kindLabel(l10n),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      text,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canOpen)
                        FilledButton.icon(
                          onPressed: () => _open(context),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text(l10n.qrResultOpen),
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _copy(context),
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        label: Text(l10n.qrActionCopy),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _share(context),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: Text(l10n.qrActionShare),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onScanAgain,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: Text(l10n.qrScanAgain),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ScanKind { link, wifi, email, phone, sms, location, contact, text }
