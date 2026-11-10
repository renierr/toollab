import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../api/x_session.dart';

/// Manual login: the `auth_token` and `ct0` cookies copied from a browser's
/// developer tools, for Linux without WebKitGTK or any login the WebView blocks.
class XSessionDialog extends StatefulWidget {
  const XSessionDialog({super.key});

  static Future<XSession?> show(BuildContext context) => showDialog<XSession>(
    context: context,
    builder: (_) => const XSessionDialog(),
  );

  @override
  State<XSessionDialog> createState() => _XSessionDialogState();
}

class _XSessionDialogState extends State<XSessionDialog> with DisposeCleanup {
  final TextEditingController _auth = TextEditingController();
  final TextEditingController _csrf = TextEditingController();

  @override
  void initState() {
    super.initState();
    onDispose(() {
      _auth.dispose();
      _csrf.dispose();
    });
  }

  XSession? get _session => XSession.fromCookies({
    XSession.authCookie: _auth.text,
    XSession.csrfCookie: _csrf.text,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(l10n.xFeedPasteSessionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.xFeedPasteSessionHint),
          const SizedBox(height: 16),
          TextField(
            controller: _auth,
            decoration: const InputDecoration(
              labelText: XSession.authCookie,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _csrf,
            decoration: const InputDecoration(
              labelText: XSession.csrfCookie,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _session == null
              ? null
              : () => Navigator.of(context).pop(_session),
          child: Text(l10n.xFeedLogIn),
        ),
      ],
    );
  }
}
