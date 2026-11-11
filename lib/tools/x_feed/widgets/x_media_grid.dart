import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/focus_outline.dart';

import '../models/x_media.dart';

/// One to four media tiles in X's familiar arrangement.
class XMediaGrid extends StatelessWidget {
  final List<XMedia> media;
  final ValueChanged<int> onOpen;

  /// Taller previews for the focused post of a thread.
  final double maxHeight;

  /// With nodes each tile is its own outlined focus stop, so a keyboard or
  /// remote can reach a video.
  final List<FocusNode>? focusNodes;

  const XMediaGrid({
    super.key,
    required this.media,
    required this.onOpen,
    this.maxHeight = 420,
    this.focusNodes,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final shown = media.take(4).toList();
    Widget tile(int i) => _MediaTile(
      media: shown[i],
      onTap: () => onOpen(i),
      focusNode: focusNodes != null && i < focusNodes!.length
          ? focusNodes![i]
          : null,
    );

    final Widget grid;
    if (shown.length == 1) {
      final ratio = shown.first.aspectRatio.clamp(0.6, 2.4);
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = (constraints.maxWidth / ratio).clamp(0.0, maxHeight);
            return SizedBox(
              width: constraints.maxWidth,
              height: height,
              child: tile(0),
            );
          },
        ),
      );
    } else if (shown.length == 2) {
      grid = Row(
        children: [
          Expanded(child: tile(0)),
          const SizedBox(width: 2),
          Expanded(child: tile(1)),
        ],
      );
    } else if (shown.length == 3) {
      grid = Row(
        children: [
          Expanded(child: tile(0)),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(child: tile(1)),
                const SizedBox(height: 2),
                Expanded(child: tile(2)),
              ],
            ),
          ),
        ],
      );
    } else {
      grid = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: tile(0)),
                const SizedBox(width: 2),
                Expanded(child: tile(1)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: tile(2)),
                const SizedBox(width: 2),
                Expanded(child: tile(3)),
              ],
            ),
          ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(aspectRatio: 16 / 9, child: grid),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final XMedia media;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const _MediaTile({required this.media, required this.onTap, this.focusNode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tile = Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        focusNode: focusNode,
        focusColor: Colors.transparent,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: media.altText,
              image: true,
              child: Image.network(
                media.previewUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (media.isPlayable)
              Center(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            if (media.isPlayable)
              Positioned(
                left: 8,
                bottom: 8,
                child: _Badge(
                  label: media.type == XMediaType.gif
                      ? l10n.xFeedGifBadge
                      : _duration(media.durationMs),
                ),
              ),
          ],
        ),
      ),
    );
    if (focusNode == null) return tile;
    return FocusOutline(
      borderRadius: BorderRadius.circular(10),
      glow: false,
      child: tile,
    );
  }

  static String _duration(int? ms) {
    if (ms == null) return '';
    final d = Duration(milliseconds: ms);
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$seconds';
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
