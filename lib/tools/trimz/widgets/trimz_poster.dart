import 'package:material_ui/material_ui.dart';

/// A 16:9 network image with a quiet placeholder while it loads or fails.
class TrimzPoster extends StatelessWidget {
  final String? url;
  final double width;

  const TrimzPoster({super.key, required this.url, required this.width});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant),
      ),
    );
    final source = url;
    if (source == null) return placeholder;
    final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(64, 1280);
    return Image.network(
      source,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) =>
          sync || frame != null ? child : placeholder,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}
