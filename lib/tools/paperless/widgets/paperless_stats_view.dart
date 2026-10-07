import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/metric_tile.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../models/paperless_label.dart';
import '../paperless_state.dart';
import 'paperless_count_card.dart';
import 'paperless_error_view.dart';

class PaperlessStatsView extends StatelessWidget {
  const PaperlessStatsView({super.key});

  static const _topCount = 5;

  static List<PaperlessCountEntry> _top(List<PaperlessLabel> labels) {
    final sorted = labels.where((l) => l.documentCount > 0).toList()
      ..sort((a, b) => b.documentCount.compareTo(a.documentCount));
    return [
      for (final label in sorted.take(_topCount))
        (label: label.name, count: label.documentCount, color: label.color),
    ];
  }

  static String _mimeLabel(String mimeType) {
    final slash = mimeType.indexOf('/');
    final subtype = slash < 0 ? mimeType : mimeType.substring(slash + 1);
    return subtype.replaceFirst(RegExp(r'^(x-|vnd\.)'), '').toUpperCase();
  }

  Future<void> _refresh(PaperlessState state) =>
      Future.wait([state.refreshStatistics(), state.loadLabels()]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<PaperlessState>();
    final stats = state.statistics;
    final number = NumberFormat.decimalPattern(l10n.localeName);

    final List<Widget> children;
    if (stats == null) {
      children = [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Center(
            child: state.statisticsError != null
                ? PaperlessErrorView(
                    error: state.statisticsError!,
                    onRetry: () => _refresh(state),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      ];
    } else {
      final correspondents = _top(state.correspondents);
      final tags = _top(state.tags);
      final types = _top(state.documentTypes);
      children = [
        MetricGrid(
          wideColumns: 3,
          children: [
            MetricTile(
              label: l10n.paperlessStatDocuments,
              value: number.format(stats.documentsTotal),
              icon: Icons.description_outlined,
              color: AppTheme.accentTeal,
            ),
            if (stats.documentsInbox != null)
              MetricTile(
                label: l10n.paperlessStatInbox,
                value: number.format(stats.documentsInbox),
                icon: Icons.inbox_outlined,
                color: AppTheme.accentAmber,
              ),
            MetricTile(
              label: l10n.paperlessStatCorrespondents,
              value: number.format(
                stats.correspondentCount ?? state.correspondents.length,
              ),
              icon: Icons.person_outline,
              color: AppTheme.accentBlue,
            ),
            MetricTile(
              label: l10n.paperlessStatDocumentTypes,
              value: number.format(
                stats.documentTypeCount ?? state.documentTypes.length,
              ),
              icon: Icons.category_outlined,
              color: AppTheme.accentPurple,
            ),
            MetricTile(
              label: l10n.paperlessStatTags,
              value: number.format(stats.tagCount ?? state.tags.length),
              icon: Icons.label_outline,
              color: AppTheme.accentGreen,
            ),
            if (stats.characterCount != null)
              MetricTile(
                label: l10n.paperlessStatCharacters,
                value: NumberFormat.compact(
                  locale: l10n.localeName,
                ).format(stats.characterCount),
                icon: Icons.text_fields,
                color: AppTheme.accentRed,
              ),
          ],
        ),
        if (stats.fileTypes.isNotEmpty)
          PaperlessCountCard(
            icon: Icons.insert_drive_file_outlined,
            title: l10n.paperlessStatFileTypes,
            entries: [
              for (final type in stats.fileTypes)
                (
                  label: _mimeLabel(type.mimeType),
                  count: type.count,
                  color: null,
                ),
            ],
          ),
        if (correspondents.isNotEmpty)
          PaperlessCountCard(
            icon: Icons.person_outline,
            title: l10n.paperlessStatTopCorrespondents,
            entries: correspondents,
          ),
        if (types.isNotEmpty)
          PaperlessCountCard(
            icon: Icons.category_outlined,
            title: l10n.paperlessStatTopDocumentTypes,
            entries: types,
          ),
        if (tags.isNotEmpty)
          PaperlessCountCard(
            icon: Icons.label_outline,
            title: l10n.paperlessStatTopTags,
            entries: tags,
          ),
      ];
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(state),
      child: ReadableWidth(
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, index) => children[index],
        ),
      ),
    );
  }
}
