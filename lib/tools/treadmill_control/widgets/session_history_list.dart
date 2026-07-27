import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:intl/intl.dart';
import '../treadmill_control_state.dart';
import '../treadmill_session.dart';
import '../treadmill_control_colors.dart';
import 'session_history_list_item.dart';
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout?'),
        content: const Text(
          'Are you sure you want to delete this workout session permanently?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              state.deleteSession(session.id!);
              Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
      final result = await state.syncNow();
      if (result == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.treadmillHistorySyncDisabled)),
        );
        return;
      }
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
    if (state.pastSessions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No sessions to export')));
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
        successMessageAndroid: 'Workouts backup saved to Downloads',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importBackup(
    BuildContext context,
    TreadmillControlState state,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      const typeGroup = fs.XTypeGroup(
        label: 'JSON Backup',
        extensions: ['json'],
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  void _viewSessionDetails(BuildContext context, TreadmillSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, controller) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          final int mins = session.elapsedTime ~/ 60;
          final int secs = session.elapsedTime % 60;

          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Workout Details',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Table(
                  children: [
                    _buildRow(
                      'Distance',
                      '${session.distance.toStringAsFixed(2)} km',
                    ),
                    _buildRow('Duration', '${mins}m ${secs}s'),
                    _buildRow('Calories', '${session.calories} kcal'),
                    _buildRow(
                      'Avg Speed',
                      '${session.avgSpeed.toStringAsFixed(1)} km/h',
                    ),
                    _buildRow(
                      'Max Speed',
                      '${session.maxSpeed.toStringAsFixed(1)} km/h',
                    ),
                    _buildRow(
                      'Avg Heart Rate',
                      '${session.avgHeartRate.round()} bpm',
                    ),
                    _buildRow(
                      'Max Heart Rate',
                      '${session.maxHeartRate.round()} bpm',
                    ),
                    _buildRow('Steps', '${session.steps}'),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Workout Graph',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (session.dataPoints.isEmpty)
                  const SizedBox(
                    height: 120,
                    child: Center(child: Text('No graph data available')),
                  )
                else
                  Container(
                    height: 150,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: CustomPaint(
                      painter: _ChartPainter(
                        points: session.dataPoints,
                        isDark: isDark,
                      ),
                      child: Container(),
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  TableRow _buildRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}

class _SessionGroup {
  final String title;
  final List<TreadmillSession> sessions;
  final bool isRecent;

  const _SessionGroup(this.title, this.sessions, this.isRecent);
}

class _ChartPainter extends CustomPainter {
  final List<WorkoutDataPoint> points;
  final bool isDark;

  _ChartPainter({required this.points, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintSpeed = Paint()
      ..color = TreadmillColors.cyanMetric
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintHr = Paint()
      ..color = TreadmillColors.redMetric
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintGrid = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    double maxSpeed = 12.0;
    double maxHr = 180.0;
    double minHr = 60.0;

    for (final p in points) {
      if (p.speed > maxSpeed) {
        maxSpeed = p.speed;
      }
      if (p.heartRate > maxHr) {
        maxHr = p.heartRate.toDouble();
      }
      if (p.heartRate > 0 && p.heartRate < minHr) {
        minHr = p.heartRate.toDouble();
      }
    }

    final double hrRange = max(40.0, maxHr - minHr);

    final speedPoints = <Offset>[];
    final hrPoints = <Offset>[];

    final double dx = points.length > 1
        ? size.width / (points.length - 1)
        : size.width;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = i * dx;

      final ySpeed = size.height - (p.speed / maxSpeed) * size.height;
      speedPoints.add(Offset(x, ySpeed));

      if (p.heartRate > 0) {
        final yHr =
            size.height - ((p.heartRate - minHr) / hrRange) * size.height;
        hrPoints.add(Offset(x, yHr));
      }
    }

    if (speedPoints.length > 1) {
      final path = Path()..moveTo(speedPoints[0].dx, speedPoints[0].dy);
      for (int i = 1; i < speedPoints.length; i++) {
        path.lineTo(speedPoints[i].dx, speedPoints[i].dy);
      }
      canvas.drawPath(path, paintSpeed);
    }

    if (hrPoints.length > 1) {
      final path = Path()..moveTo(hrPoints[0].dx, hrPoints[0].dy);
      for (int i = 1; i < hrPoints.length; i++) {
        path.lineTo(hrPoints[i].dx, hrPoints[i].dy);
      }
      canvas.drawPath(path, paintHr);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isDark != isDark;
  }
}
