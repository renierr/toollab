import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/qr_codec.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/pairing_qr_content.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../api/x_session.dart';
import '../x_pairing.dart';

/// The TV side of pairing: a QR code to scan with ToolLab on a logged-in phone.
class XPairReceiveDialog extends StatefulWidget {
  const XPairReceiveDialog({super.key});

  static Future<XSession?> show(BuildContext context) => showDialog<XSession>(
    context: context,
    builder: (_) => const XPairReceiveDialog(),
  );

  @override
  State<XPairReceiveDialog> createState() => _XPairReceiveDialogState();
}

class _XPairReceiveDialogState extends State<XPairReceiveDialog>
    with DisposeCleanup {
  XPairingReceiver? _receiver;
  Uint8List? _qr;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    onDispose(() => unawaited(_receiver?.close()));
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final receiver = await XPairingReceiver.start();
      if (!mounted) {
        await receiver.close();
        return;
      }
      _receiver = receiver;
      setState(() => _qr = QrCodec.encodePng(receiver.payload, size: 480));
      final session = await receiver.session;
      if (mounted) Navigator.of(context).pop(session);
    } catch (e) {
      errorLog('[XPairReceive] Pairing server failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qr = _qr;
    final receiver = _receiver;

    final Widget body;
    if (_failed) {
      body = Text(l10n.xFeedPairFailed);
    } else if (qr == null || receiver == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (receiver.hosts.isEmpty) {
      body = Text(l10n.xFeedPairNoNetwork);
    } else {
      body = PairingQrContent(
        hint: l10n.xFeedPairReceiveHint,
        qr: qr,
        hosts: receiver.hosts,
        port: receiver.port,
      );
    }

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(l10n.xFeedPairReceiveTitle),
      content: body,
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}
