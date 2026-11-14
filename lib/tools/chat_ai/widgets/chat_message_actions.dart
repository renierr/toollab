import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'chat_citation.dart';

/// Small copy and share buttons under a message.
class ChatMessageActions extends StatelessWidget {
  final String text;
  final Color color;

  const ChatMessageActions({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plain = CitationSyntax.strip(text).trim();
    final muted = color.withValues(alpha: 0.6);
    // Fingers need more room than a mouse pointer.
    final extent = Platform.isAndroid ? 40.0 : 32.0;
    final constraints = BoxConstraints.tightFor(width: extent, height: extent);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: plain));
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.chatAiMessageCopied)),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          color: muted,
          tooltip: l10n.commonCopy,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: constraints,
        ),
        IconButton(
          onPressed: () => SharePlus.instance.share(ShareParams(text: plain)),
          icon: const Icon(Icons.share_outlined, size: 16),
          color: muted,
          tooltip: l10n.commonShare,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: constraints,
        ),
      ],
    );
  }
}
