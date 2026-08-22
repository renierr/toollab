import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../core/tool_page_state.dart';
import '../../helpers/clipboard_helper.dart';
import '../../helpers/file_save_helper.dart';
import '../../helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import '../collapsible_section.dart';
import 'workout_colors.dart';
import 'workout_session.dart';
import 'workout_details_stats.dart';
import 'package:tool_lab/widgets/metric_tile.dart';
import 'workout_details_header.dart';
import 'workout_hr_zone_bar.dart';
import 'workout_incline_chart.dart';
import 'workout_session_chart.dart';
import 'workout_splits_table.dart';

class WorkoutDetailsSheet extends StatefulWidget {
  final TreadmillSession session;
  final ScrollController? controller;

  const WorkoutDetailsSheet({
    super.key,
    required this.session,
    this.controller,
  });

  static Future<void> show(BuildContext context, TreadmillSession session) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, controller) =>
            WorkoutDetailsSheet(session: session, controller: controller),
      ),
    );
  }

  @override
  State<WorkoutDetailsSheet> createState() => _WorkoutDetailsSheetState();
}

class _WorkoutDetailsSheetState extends State<WorkoutDetailsSheet>
    with DisposeCleanup {
  final GlobalKey _screenshotKey = GlobalKey();
  late final TempFileScope _tempScope;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _tempScope = TempFileManager.createScope();
    onDispose(() => _tempScope.cleanTracked());
  }

  Future<Uint8List?> _captureSheet() async {
    final boundary =
        _screenshotKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _handleScreenshot(_ScreenshotAction action) async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _captureSheet();
      if (bytes == null || !mounted) return;
      final filename =
          'treadmill_workout_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.png';
      if (action == _ScreenshotAction.copy) {
        final copied = await ClipboardHelper.copyImageBytes(bytes);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              copied
                  ? l10n.treadmillScreenshotCopied
                  : l10n.treadmillScreenshotCopyFailed,
            ),
          ),
        );
      } else if (action == _ScreenshotAction.share) {
        final path = await _tempScope.createFile(filename, bytes: bytes);
        await FileSaveHelper.shareFile(path, 'image/png');
      } else {
        await FileSaveHelper.saveFile(
          context: context,
          suggestedName: filename,
          bytes: bytes,
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.treadmillDetailsScreenshotFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final stats = WorkoutDetailsStats.from(widget.session);
    final date = DateTime.fromMillisecondsSinceEpoch(widget.session.startTime);
    final pace = widget.session.distance > 0
        ? widget.session.elapsedTime / widget.session.distance
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Text(
                  l10n.treadmillDetailsTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              PopupMenuButton<_ScreenshotAction>(
                tooltip: l10n.treadmillDetailsScreenshot,
                enabled: !_isCapturing,
                icon: _isCapturing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.screenshot_outlined),
                onSelected: _handleScreenshot,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _ScreenshotAction.save,
                    child: Text(l10n.treadmillHistorySaveScreenshot),
                  ),
                  PopupMenuItem(
                    value: _ScreenshotAction.copy,
                    child: Text(l10n.treadmillScreenshotCopy),
                  ),
                  PopupMenuItem(
                    value: _ScreenshotAction.share,
                    child: Text(l10n.treadmillHistoryShareScreenshot),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          RepaintBoundary(
            key: _screenshotKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 14),
                WorkoutDetailsHeader(
                  date: DateFormat.yMMMEd(locale).add_Hm().format(date),
                  distance: widget.session.distance.toStringAsFixed(2),
                  distanceLabel: 'km',
                  duration: formatWorkoutDuration(widget.session.elapsedTime),
                  durationLabel: l10n.treadmillDetailsDuration,
                  pace: formatPace(pace),
                  paceLabel: l10n.treadmillDetailsPaceUnit,
                ),
                const SizedBox(height: 16),
                MetricGrid(
                  children: [
                    MetricTile(
                      label: l10n.treadmillDetailsAvgSpeed,
                      value: widget.session.avgSpeed.toStringAsFixed(1),
                      unit: 'km/h',
                      icon: Icons.speed,
                      color: TreadmillColors.cyanMetric,
                      compact: true,
                    ),
                    MetricTile(
                      label: l10n.treadmillDetailsMaxSpeed,
                      value: widget.session.maxSpeed.toStringAsFixed(1),
                      unit: 'km/h',
                      icon: Icons.bolt,
                      color: TreadmillColors.cyanMetric,
                      compact: true,
                    ),
                    MetricTile(
                      label: l10n.treadmillDetailsAvgHr,
                      value: '${widget.session.avgHeartRate.round()}',
                      unit: 'bpm',
                      icon: Icons.favorite,
                      color: TreadmillColors.redMetric,
                      compact: true,
                    ),
                    MetricTile(
                      label: l10n.treadmillDetailsMaxHr,
                      value: '${widget.session.maxHeartRate.round()}',
                      unit: 'bpm',
                      icon: Icons.monitor_heart_outlined,
                      color: TreadmillColors.redMetric,
                      compact: true,
                    ),
                    MetricTile(
                      label: l10n.treadmillDetailsCalories,
                      value: '${widget.session.calories}',
                      unit: 'kcal',
                      icon: Icons.local_fire_department_outlined,
                      color: TreadmillColors.amberMetric,
                      compact: true,
                    ),
                    if (stats.minHeartRate > 0)
                      MetricTile(
                        label: l10n.treadmillDetailsMinHr,
                        value: '${stats.minHeartRate.round()}',
                        unit: 'bpm',
                        icon: Icons.arrow_downward,
                        color: TreadmillColors.greenMetric,
                        compact: true,
                      ),
                    if (widget.session.steps > 0)
                      MetricTile(
                        label: l10n.treadmillDetailsSteps,
                        value: NumberFormat.decimalPattern(
                          locale,
                        ).format(widget.session.steps),
                        icon: Icons.directions_walk,
                        color: TreadmillColors.greenMetric,
                        compact: true,
                      ),
                    if (stats.hasIncline) ...[
                      MetricTile(
                        label: l10n.treadmillDetailsAvgIncline,
                        value: stats.avgIncline.toStringAsFixed(1),
                        unit: '%',
                        icon: Icons.trending_up,
                        color: TreadmillColors.amberMetric,
                        compact: true,
                      ),
                      MetricTile(
                        label: l10n.treadmillDetailsMaxIncline,
                        value: stats.maxIncline.toStringAsFixed(1),
                        unit: '%',
                        icon: Icons.terrain_outlined,
                        color: TreadmillColors.amberMetric,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                if (widget.session.dataPoints.length < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.treadmillDetailsNoSamples,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  )
                else ...[
                  CollapsibleSection(
                    icon: Icons.show_chart,
                    iconColor: TreadmillColors.cyanMetric,
                    title: l10n.treadmillDetailsChart,
                    child: WorkoutSessionChart(
                      points: widget.session.dataPoints,
                      speedLabel: l10n.treadmillDetailsSpeed,
                      heartRateLabel: l10n.treadmillHistoryHeartRate,
                    ),
                  ),
                  if (stats.hasIncline)
                    CollapsibleSection(
                      icon: Icons.terrain_outlined,
                      iconColor: TreadmillColors.amberMetric,
                      title: l10n.treadmillDetailsIncline,
                      child: WorkoutInclineChart(
                        points: widget.session.dataPoints,
                      ),
                    ),
                  if (stats.hasZones)
                    CollapsibleSection(
                      icon: Icons.favorite_outline,
                      iconColor: TreadmillColors.redMetric,
                      title: l10n.treadmillDetailsZones,
                      child: WorkoutHrZoneBar(
                        zones: stats.zones,
                        totalSeconds: stats.zoneSeconds,
                        zoneNames: [
                          l10n.treadmillDetailsZone1,
                          l10n.treadmillDetailsZone2,
                          l10n.treadmillDetailsZone3,
                          l10n.treadmillDetailsZone4,
                          l10n.treadmillDetailsZone5,
                        ],
                      ),
                    ),
                  if (stats.splits.isNotEmpty)
                    CollapsibleSection(
                      icon: Icons.flag_outlined,
                      iconColor: TreadmillColors.greenMetric,
                      title: l10n.treadmillDetailsSplits,
                      child: WorkoutSplitsTable(
                        splits: stats.splits,
                        kmHeader: l10n.treadmillDetailsSplitKm,
                        timeHeader: l10n.treadmillDetailsSplitTime,
                        paceHeader: l10n.treadmillDetailsSplitPace,
                        heartRateHeader: l10n.treadmillDetailsSplitHr,
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonClose),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ScreenshotAction { save, copy, share }
