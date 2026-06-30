import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chiptune_colors.dart';
import '../modarchive_service.dart';

/// Modal that fetches a random tune from The Mod Archive, shows its details
/// and source credits, and returns the [ModArchiveTune] when the user plays it.
///
/// Returns the chosen tune via `Navigator.pop`, or `null` if cancelled.
class ModArchiveFetchDialog extends StatefulWidget {
  final ModArchiveService service;

  const ModArchiveFetchDialog({super.key, required this.service});

  static Future<ModArchiveTune?> show(
    BuildContext context,
    ModArchiveService service,
  ) {
    return showDialog<ModArchiveTune>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ModArchiveFetchDialog(service: service),
    );
  }

  @override
  State<ModArchiveFetchDialog> createState() => _ModArchiveFetchDialogState();
}

class _ModArchiveFetchDialogState extends State<ModArchiveFetchDialog> {
  ModArchiveTune? _tune;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _tune = null;
    });
    try {
      final tune = await widget.service.fetchRandom();
      if (!mounted) return;
      setState(() {
        _tune = tune;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openSource() async {
    final tune = _tune;
    if (tune == null) return;
    final uri = Uri.parse(tune.pageUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      icon: const Icon(Icons.casino_outlined, color: ChiptuneColors.accent),
      title: Text(l10n.chipRandomTitle),
      scrollable: true,
      content: _buildContent(l10n),
      actions: _buildActions(l10n),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    if (_loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(color: ChiptuneColors.accent),
          ),
          Text(l10n.chipRandomFetching, textAlign: TextAlign.center),
        ],
      );
    }
    if (_error != null) {
      return Text(l10n.chipRandomFetchFailed(_error!));
    }
    return _ModArchiveTuneDetails(tune: _tune!, onOpenSource: _openSource);
  }

  List<Widget> _buildActions(AppLocalizations l10n) {
    if (_loading) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ];
    }
    if (_error != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _fetch, child: Text(l10n.chipRandomRetry)),
      ];
    }
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.commonCancel),
      ),
      TextButton(onPressed: _fetch, child: Text(l10n.chipRandomShuffleAgain)),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_tune),
        child: Text(l10n.chipPlayTooltip),
      ),
    ];
  }
}

/// Renders the fetched tune's metadata and a tappable source attribution.
class _ModArchiveTuneDetails extends StatelessWidget {
  final ModArchiveTune tune;
  final VoidCallback onOpenSource;

  const _ModArchiveTuneDetails({
    required this.tune,
    required this.onOpenSource,
  });

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
            _DetailChip(label: l10n.chipMetricFormat, value: tune.format),
            if (tune.channels != null)
              _DetailChip(
                label: l10n.chipMetricChannels,
                value: '${tune.channels}',
              ),
            if (tune.genre != null)
              _DetailChip(label: l10n.chipMetricGenre, value: tune.genre!),
            if (tune.sizeText != null)
              _DetailChip(label: l10n.chipMetricSize, value: tune.sizeText!),
          ],
        ),
        const Divider(height: 24),
        Text(
          l10n.chipRandomCredits,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onOpenSource,
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

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;

  const _DetailChip({required this.label, required this.value});

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
