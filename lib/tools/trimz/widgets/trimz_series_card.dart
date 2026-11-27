import 'package:material_ui/material_ui.dart';

import 'trimz_poster.dart';

/// A poster with the title and one line below; [rank] marks a top-10 row.
class TrimzSeriesCard extends StatelessWidget {
  /// Room under the poster for the title and subtitle, before text scaling.
  static const double textHeight = 62;

  final String title;
  final String? subtitle;
  final String? posterUrl;
  final String? badge;
  final int? rank;

  /// Share of the current episode watched, for a continue row.
  final double? progress;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TrimzSeriesCard({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.width,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.rank,
    this.progress,
    this.onLongPress,
  });

  static double heightFor(BuildContext context, double width) =>
      width * 9 / 16 + MediaQuery.textScalerOf(context).scale(textHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TrimzPoster(url: posterUrl, width: width),
                    if (rank != null)
                      Positioned(
                        left: 8,
                        bottom: 4,
                        child: Text(
                          '$rank',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            shadows: const [
                              Shadow(blurRadius: 8, color: Colors.black87),
                            ],
                          ),
                        ),
                      ),
                    if (badge != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (progress != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.black45,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
