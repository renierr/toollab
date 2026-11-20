import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
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

  /// Narrower single tiles get blurred side fill instead of becoming a strip.
  static const double _minSingleWidth = 280;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final shown = media.take(4).toList();
    Widget tile(int i, {bool contain = false}) => _MediaTile(
      media: shown[i],
      onTap: () => onOpen(i),
      contain: contain,
      focusNode: focusNodes != null && i < focusNodes!.length
          ? focusNodes![i]
          : null,
    );

    final Widget grid;
    if (shown.length == 1) {
      final ratio = shown.first.aspectRatio;
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          // Very wide panoramas still get a usable height and are letterboxed.
          final height = (maxWidth / ratio.clamp(0.0, 2.4)).clamp(
            0.0,
            maxHeight,
          );
          final width = (height * ratio).clamp(
            _minSingleWidth.clamp(0.0, maxWidth),
            maxWidth,
          );
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: width,
                height: height,
                child: tile(0, contain: true),
              ),
            ),
          );
        },
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

  /// Shows the whole preview over a blurred copy instead of cropping it.
  final bool contain;

  const _MediaTile({
    required this.media,
    required this.onTap,
    required this.contain,
    this.focusNode,
  });

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
            if (contain) _BlurredBackdrop(url: media.previewUrl),
            Semantics(
              label: media.altText,
              image: true,
              child: Image.network(
                media.previewUrl,
                fit: contain ? BoxFit.contain : BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (media.isPlayable)
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
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

class _BlurredBackdrop extends StatelessWidget {
  final String url;

  const _BlurredBackdrop({required this.url});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.35),
            BlendMode.darken,
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
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
