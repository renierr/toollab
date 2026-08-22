import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:intl/intl.dart';
import '../treadmill_control_state.dart';
import '../treadmill_publish_message.dart';
import 'package:tool_lab/widgets/workout/workout_session.dart';
import 'session_history_list_item.dart';
import 'package:tool_lab/widgets/workout/workout_details_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../helpers/file_save_helper.dart';
import '../../../../widgets/collapsible_section.dart';

class SessionHistoryList extends StatelessWidget {
  const SessionHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreadmillControlState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.historyTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Wrap(
              children: [
                IconButton(
                  icon: state.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  tooltip: l10n.treadmillHistorySync,
                  onPressed: state.isSyncing
                      ? null
                      : () => _syncNow(context, state),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: l10n.importHistory,
                  onPressed: () => _importBackup(context, state),
                ),
                IconButton(
                  icon: const Icon(Icons.upload),
                  tooltip: l10n.exportHistory,
                  onPressed: () => _exportBackup(context, state),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.pastSessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.treadmillHistoryEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
          )
        else
          ..._groups(context, state).map(
            (group) => CollapsibleSection(
              icon: Icons.calendar_month_outlined,
              title: group.title,
              initiallyExpanded: group.isRecent,
              child: Column(
                children: group.sessions
                    .map(
                      (session) => SessionHistoryListItem(
                        session: session,
                        onDelete: () => _confirmDelete(context, state, session),
                        onTap: () => _viewSessionDetails(context, session),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  List<_SessionGroup> _groups(
    BuildContext context,
    TreadmillControlState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final recent = <TreadmillSession>[];
    final grouped = <String, List<TreadmillSession>>{};
    for (final session in state.pastSessions) {
      final date = DateTime.fromMillisecondsSinceEpoch(session.startTime);
      if (!date.isBefore(cutoff)) {
        recent.add(session);
      } else {
        final key = DateFormat.yMMMM(
          Localizations.localeOf(context).toString(),
        ).format(date);
        grouped.putIfAbsent(key, () => []).add(session);
      }
    }
    return [
      if (recent.isNotEmpty)
        _SessionGroup(l10n.treadmillHistoryLastSevenDays, recent, true),
      ...grouped.entries.map(
        (entry) => _SessionGroup(entry.key, entry.value, false),
      ),
    ];
  }

  void _confirmDelete(
    BuildContext context,
    TreadmillControlState state,
    TreadmillSession session,
  ) {
    if (session.id == null) return;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.treadmillHistoryDeleteTitle),
        content: Text(l10n.treadmillHistoryDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              state.deleteSession(session.id!);
              Navigator.of(context).pop();
            },
            child: Text(
              l10n.commonDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow(
    BuildContext context,
    TreadmillControlState state,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await state.syncNow(force: true);
      if (!context.mounted) return;
      if (result != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.treadmillHistorySyncSuccess(
                result['pushed'] ?? 0,
                result['pulled'] ?? 0,
              ),
            ),
          ),
        );
      } else if (state.syncToHealthConnect) {
        // Backend sync is off, so the only thing that ran is the one-way push
        // to Health Connect - reporting an import here was plain wrong.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              treadmillPublishMessage(l10n, state.lastHealthConnectPublish),
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.treadmillHistorySyncDisabled)),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.treadmillHistorySyncFailed('$e'))),
      );
    }
  }

  Future<void> _exportBackup(
    BuildContext context,
    TreadmillControlState state,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (state.pastSessions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.treadmillHistoryExportEmpty)));
      return;
    }

    try {
      final jsonList = state.pastSessions.map((s) => s.toMap()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'treadmill_workouts_backup.json',
        bytes: bytes,
        successMessageAndroid: l10n.treadmillHistoryExportSaved,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.treadmillHistoryExportFailed('$e'))),
        );
      }
    }
  }

  Future<void> _importBackup(
    BuildContext context,
    TreadmillControlState state,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      const typeGroup = fs.XTypeGroup(label: 'JSON', extensions: ['json']);
      final file = await fs.openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      final content = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(content);
      final List<TreadmillSession> imported = decoded
          .map((x) => TreadmillSession.fromMap(x as Map<String, dynamic>))
          .toList();

      if (imported.isNotEmpty) {
        final importedCount = await state.importSessions(imported);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                importedCount == 0
                    ? l10n.treadmillHistoryImportNoNewWorkouts
                    : l10n.treadmillHistoryImportSuccess(importedCount),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.treadmillHistoryImportFailed('$e'))),
        );
      }
    }
  }

  void _viewSessionDetails(BuildContext context, TreadmillSession session) {
    WorkoutDetailsSheet.show(context, session);
  }
}

class _SessionGroup {
  final String title;
  final List<TreadmillSession> sessions;
  final bool isRecent;

  const _SessionGroup(this.title, this.sessions, this.isRecent);
}
