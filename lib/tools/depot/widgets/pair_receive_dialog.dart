import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/qr_codec.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/pairing_qr_content.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import 'package:tool_lab/helpers/lan_pairing.dart';

/// The device side of a QR handoff: shows the code a phone scans and completes
/// [onReceived] with what the phone sent back.
class PairReceiveDialog<T> extends StatefulWidget {
  final PairingProtocol protocol;
  final Map<String, Object?> fields;
  final Future<T> Function(Map<String, dynamic> data) onReceived;
  final String title;
  final String hint;
  final String noNetwork;
  final String failed;

  const PairReceiveDialog({
    super.key,
    required this.protocol,
    required this.onReceived,
    required this.title,
    required this.hint,
    required this.noNetwork,
    required this.failed,
    this.fields = const {},
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required PairingProtocol protocol,
    required Future<T> Function(Map<String, dynamic> data) onReceived,
    required String title,
    required String hint,
    required String noNetwork,
    required String failed,
    Map<String, Object?> fields = const {},
  }) => showDialog<T>(
    context: context,
    builder: (_) => PairReceiveDialog<T>(
      protocol: protocol,
      onReceived: onReceived,
      title: title,
      hint: hint,
      noNetwork: noNetwork,
      failed: failed,
      fields: fields,
    ),
  );

  @override
  State<PairReceiveDialog<T>> createState() => _PairReceiveDialogState<T>();
}

class _PairReceiveDialogState<T> extends State<PairReceiveDialog<T>>
    with DisposeCleanup {
  PairingReceiver? _receiver;
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
      final receiver = await PairingReceiver.start(protocol: widget.protocol);
      if (!mounted) {
        await receiver.close();
        return;
      }
      _receiver = receiver;
      setState(
        () =>
            _qr = QrCodec.encodePng(receiver.payload(widget.fields), size: 480),
      );
      final result = await widget.onReceived(await receiver.received);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      errorLog('[PairReceiveDialog] Pairing failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    final receiver = _receiver;

    final Widget body;
    if (_failed) {
      body = Text(widget.failed);
    } else if (qr == null || receiver == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (receiver.hosts.isEmpty) {
      body = Text(widget.noNetwork);
    } else {
      body = PairingQrContent(
        hint: widget.hint,
        qr: qr,
        hosts: receiver.hosts,
        port: receiver.port,
      );
    }

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: body,
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
      ],
    );
  }
}
