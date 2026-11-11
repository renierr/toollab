import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/pairing_scanner_content.dart';

import '../api/x_session.dart';
import '../x_pairing.dart';

/// The phone side of pairing: scan the TV's code and send this login to it.
class XPairSendPage extends StatefulWidget {
  final XSession session;

  const XPairSendPage({super.key, required this.session});

  static Future<void> open(BuildContext context, XSession session) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => XPairSendPage(session: session),
        ),
      );

  @override
  State<XPairSendPage> createState() => _XPairSendPageState();
}

class _XPairSendPageState extends State<XPairSendPage> {
  bool _sending = false;
  int _scanGeneration = 0;

  Future<void> _onDetected(String payload) async {
    if (_sending) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    var sent = false;
    try {
      sent = await XPairingReceiver.send(payload, widget.session);
    } catch (e) {
      debugLog('[XPairSend] Invalid code: $e');
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(sent ? l10n.xFeedPairSent : l10n.xFeedPairSendFailed),
      ),
    );
    if (sent) {
      Navigator.of(context).pop();
    } else {
      // A fresh scanner, since it reports only its first code.
      setState(() {
        _sending = false;
        _scanGeneration++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.xFeedPairSendTitle)),
      body: PairingScannerContent(
        hint: l10n.xFeedPairSendHint,
        sending: _sending,
        scanGeneration: _scanGeneration,
        accentColor: AppTheme.accentBlue,
        onDetected: (text) => unawaited(_onDetected(text)),
      ),
    );
  }
}
