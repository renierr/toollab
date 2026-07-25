import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../p2p/p2p_protocol.dart';

/// Confirmation dialog shown to a receiver when a nearby peer wants to
/// send a file, with the sender's name and file details.
class FastDropIncomingRequestDialog extends StatelessWidget {
  final String senderName;
  final P2pHandshakeRequest request;

  const FastDropIncomingRequestDialog({
    super.key,
    required this.senderName,
    required this.request,
  });

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: Text(l10n.fastDropP2pIncomingTitle),
      content: Text(
        l10n.fastDropP2pIncomingMessage(
          senderName,
          request.fileName,
          _formatBytes(request.fileSize),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.fastDropP2pDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.fastDropP2pAccept),
        ),
      ],
    );
  }
}
