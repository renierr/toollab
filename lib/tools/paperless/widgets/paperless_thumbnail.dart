import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../paperless_state.dart';

class PaperlessThumbnail extends StatefulWidget {
  final int documentId;
  final double width;
  final double height;

  const PaperlessThumbnail({
    super.key,
    required this.documentId,
    this.width = 48,
    this.height = 64,
  });

  @override
  State<PaperlessThumbnail> createState() => _PaperlessThumbnailState();
}

class _PaperlessThumbnailState extends State<PaperlessThumbnail> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = context.read<PaperlessState>().thumbnail(widget.documentId);
  }

  @override
  void didUpdateWidget(PaperlessThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _bytes = context.read<PaperlessState>().thumbnail(widget.documentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: theme.colorScheme.surfaceContainerHighest,
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return Icon(
                snapshot.connectionState == ConnectionState.done
                    ? Icons.description_outlined
                    : Icons.hourglass_empty,
                color: theme.hintColor,
                size: widget.width / 2,
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
              cacheWidth: (widget.width * 3).round(),
              errorBuilder: (_, _, _) =>
                  Icon(Icons.broken_image_outlined, color: theme.hintColor),
            );
          },
        ),
      ),
    );
  }
}
