import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

class FastDropProgressIndicator extends StatelessWidget {
  final String label;
  final int sent;
  final int total;
  final DateTime? startedAt;
  final VoidCallback onCancel;

  const FastDropProgressIndicator({
    super.key,
    required this.label,
    required this.sent,
    required this.total,
    this.startedAt,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = total > 0 ? sent / total : null;
    final elapsed = startedAt == null
        ? null
        : DateTime.now().difference(startedAt!);
    final rate = elapsed == null || elapsed.inMilliseconds == 0
        ? null
        : sent * 1000 / elapsed.inMilliseconds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                l10n.fastDropProgressDetails(
                  FormatHelper.fileSize(sent),
                  total > 0 ? FormatHelper.fileSize(total) : '?',
                  rate == null
                      ? '-'
                      : (rate / (1024 * 1024)).toStringAsFixed(1),
                  elapsed == null
                      ? '0'
                      : (elapsed.inMilliseconds / 1000).toStringAsFixed(1),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.commonCancel,
                  onPressed: onCancel,
                  style: IconButton.styleFrom(
                    foregroundColor: AppTheme.statusRed,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              color: AppTheme.accentTeal,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
