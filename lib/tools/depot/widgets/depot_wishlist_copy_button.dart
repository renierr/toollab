import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Copies the current wishlist list as a PNG image.
class DepotWishlistCopyButton extends StatefulWidget {
  final GlobalKey captureKey;

  const DepotWishlistCopyButton({super.key, required this.captureKey});

  @override
  State<DepotWishlistCopyButton> createState() =>
      _DepotWishlistCopyButtonState();
}

class _DepotWishlistCopyButtonState extends State<DepotWishlistCopyButton> {
  bool _busy = false;

  Future<void> _copy() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    setState(() => _busy = true);
    var copied = false;
    final boundary =
        widget.captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary != null) {
      ui.Image? image;
      try {
        image = await boundary.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          copied = await ClipboardHelper.copyImageBytes(
            data.buffer.asUint8List(),
          );
        }
      } catch (e) {
        errorLog('[DepotWishlistCopyButton] Copy failed: $e');
      } finally {
        image?.dispose();
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          copied ? l10n.depotWishlistCopied : l10n.depotWishlistCopyFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.copy_rounded),
      tooltip: l10n.depotWishlistCopy,
      onPressed: _busy ? null : _copy,
    );
  }
}
