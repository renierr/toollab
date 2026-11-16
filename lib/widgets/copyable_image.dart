import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/focus_outline.dart';

class CopyableImage extends StatelessWidget {
  final ImageProvider image;
  final Widget child;
  final Future<bool> Function(ui.Image image)? copyImage;

  /// Makes the image a remote focus stop: OK runs [onTap], holding OK copies.
  final bool focusable;
  final VoidCallback? onTap;

  const CopyableImage({
    super.key,
    required this.image,
    required this.child,
    this.copyImage,
    this.focusable = false,
    this.onTap,
  });

  static bool get supported =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  Future<void> _copy(BuildContext context) =>
      copy(context, image, copyImage: copyImage);

  /// Copies [image] to the clipboard and reports the result in a snack bar.
  static Future<void> copy(
    BuildContext context,
    ImageProvider image, {
    Future<bool> Function(ui.Image image)? copyImage,
  }) async {
    final l10n = AppLocalizations.of(context);
    final stream = image.resolve(createLocalImageConfiguration(context));
    final completer = Completer<ImageInfo>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(info);
        } else {
          info.dispose();
        }
      },
      onError: (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    var copied = false;
    try {
      final info = await completer.future;
      try {
        copied = await (copyImage ?? ClipboardHelper.setImagePng)(info.image);
      } finally {
        info.dispose();
      }
    } catch (e) {
      errorLog('[CopyableImage] Failed to copy image: $e');
    } finally {
      stream.removeListener(listener);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copied ? l10n.widgetImageCopied : l10n.widgetImageCopyFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (focusable) {
      final copy = supported ? () => _copy(context) : null;
      return FocusOutline(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: copy,
        child: InkWell(
          onTap: onTap,
          onLongPress: copy,
          onSecondaryTap: copy,
          child: child,
        ),
      );
    }
    if (!supported) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _copy(context),
      onSecondaryTap: () => _copy(context),
      child: child,
    );
  }
}
