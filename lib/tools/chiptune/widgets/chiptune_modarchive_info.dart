import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chiptune_colors.dart';
import '../modarchive_service.dart';

/// Displays a [ModArchiveTune]'s scraped metadata plus a tappable link back to
/// its source page on modarchive.org. Used both in the fetch modal (with the
/// full credits paragraph) and inline in the player while in random mode.
class ChiptuneModArchiveInfo extends StatelessWidget {
  final ModArchiveTune tune;

  /// When true, includes the longer attribution/credits paragraph.
  final bool showCredits;

  const ChiptuneModArchiveInfo({
    super.key,
    required this.tune,
    this.showCredits = false,
  });

  Future<void> _openSource() async {
    await launchUrl(
      Uri.parse(tune.pageUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tune.title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: ChiptuneColors.accentBright,
          ),
        ),
        Text(
          tune.fileName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChiptuneDetailChip(
              label: l10n.chipMetricFormat,
              value: tune.format,
            ),
            if (tune.channels != null)
              ChiptuneDetailChip(
                label: l10n.chipMetricChannels,
                value: '${tune.channels}',
              ),
            if (tune.genre != null)
              ChiptuneDetailChip(
                label: l10n.chipMetricGenre,
                value: tune.genre!,
              ),
            if (tune.sizeText != null)
              ChiptuneDetailChip(
                label: l10n.chipMetricSize,
                value: tune.sizeText!,
              ),
          ],
        ),
        if (showCredits) ...[
          const Divider(height: 24),
          Text(
            l10n.chipRandomCredits,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: _openSource,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_new, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.chipRandomSourceLink(tune.moduleId),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ChiptuneColors.accent,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small labelled value chip used to present a tune's scraped metadata fields.
class ChiptuneDetailChip extends StatelessWidget {
  final String label;
  final String value;

  const ChiptuneDetailChip({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ChiptuneColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
