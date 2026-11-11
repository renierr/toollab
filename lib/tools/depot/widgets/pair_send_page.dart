import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/widgets/pairing_scanner_content.dart';

import 'package:tool_lab/helpers/lan_pairing.dart';

enum PairSendOutcome { sent, cancelled, failed }

/// The phone side of a QR handoff: scans the other device's code and lets
/// [onScan] do the actual transfer.
class PairSendPage extends StatefulWidget {
  final PairingProtocol protocol;
  final String title;
  final String hint;
  final String invalidCode;
  final String sent;
  final String failed;
  final Color accentColor;
  final Future<PairSendOutcome> Function(BuildContext, PairingCode) onScan;

  const PairSendPage({
    super.key,
    required this.protocol,
    required this.title,
    required this.hint,
    required this.invalidCode,
    required this.sent,
    required this.failed,
    required this.accentColor,
    required this.onScan,
  });

  static Future<void> open(
    BuildContext context, {
    required PairingProtocol protocol,
    required String title,
    required String hint,
    required String invalidCode,
    required String sent,
    required String failed,
    required Color accentColor,
    required Future<PairSendOutcome> Function(BuildContext, PairingCode) onScan,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PairSendPage(
        protocol: protocol,
        title: title,
        hint: hint,
        invalidCode: invalidCode,
        sent: sent,
        failed: failed,
        accentColor: accentColor,
        onScan: onScan,
      ),
    ),
  );

  @override
  State<PairSendPage> createState() => _PairSendPageState();
}

class _PairSendPageState extends State<PairSendPage> {
  bool _sending = false;
  int _scanGeneration = 0;

  Future<void> _onDetected(String payload) async {
    if (_sending) return;
    final messenger = ScaffoldMessenger.of(context);

    final PairingCode code;
    try {
      code = PairingCode.parse(payload, protocol: widget.protocol);
    } catch (e) {
      debugLog('[PairSendPage] Invalid code: $e');
      messenger.showSnackBar(SnackBar(content: Text(widget.invalidCode)));
      setState(() => _scanGeneration++);
      return;
    }

    setState(() => _sending = true);
    var outcome = PairSendOutcome.failed;
    try {
      outcome = await widget.onScan(context, code);
    } catch (e) {
      debugLog('[PairSendPage] Sending failed: $e');
    }
    if (!mounted) return;
    if (outcome == PairSendOutcome.sent) {
      messenger.showSnackBar(SnackBar(content: Text(widget.sent)));
      Navigator.of(context).pop();
      return;
    }
    if (outcome == PairSendOutcome.failed) {
      messenger.showSnackBar(SnackBar(content: Text(widget.failed)));
    }
    // A fresh scanner, since it reports only its first code.
    setState(() {
      _sending = false;
      _scanGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: PairingScannerContent(
        hint: widget.hint,
        sending: _sending,
        scanGeneration: _scanGeneration,
        accentColor: widget.accentColor,
        onDetected: (text) => unawaited(_onDetected(text)),
      ),
    );
  }
}
