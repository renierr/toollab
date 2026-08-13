import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/theme/theme.dart';

/// One tool's server-side storage figures. [tool] is null when the backend
/// holds a namespace this build has no tool for - data pushed by the web
/// toolkit, or by a tool that has since been removed.
class SyncToolStatsCard extends StatelessWidget {
  final SyncToolStats stats;
  final ToolModel? tool;

  const SyncToolStatsCard({super.key, required this.stats, this.tool});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = tool?.accentColor ?? theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(tool?.icon ?? Icons.cloud_outlined, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool?.localizedName(l10n) ?? stats.toolId,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stats.toolId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  FormatHelper.fileSize(stats.totalBytes),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Wrap rather than a Row: four metrics do not fit a phone width.
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _Metric(
                  label: l10n.coreSyncStatsItems,
                  value: '${stats.records}',
                ),
                if (stats.deleted > 0)
                  _Metric(
                    label: l10n.coreSyncStatsDeleted,
                    value: '${stats.deleted}',
                    color: AppTheme.statusAmber,
                  ),
                _Metric(
                  label: l10n.coreSyncStatsData,
                  value: FormatHelper.fileSize(stats.dataBytes),
                ),
                if (stats.binaryRecords > 0)
                  _Metric(
                    label: l10n.coreSyncStatsBinary(stats.binaryRecords),
                    value: FormatHelper.fileSize(stats.binaryBytes),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              stats.lastUpdatedAt == null
                  ? l10n.coreSyncNeverSynced
                  : l10n.coreSyncLastSynced(
                      FormatHelper.epoch(
                        stats.lastUpdatedAt!,
                        style: DateStyle.dateAndTime,
                      ),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Metric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
