import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../../../core/tool_page_state.dart';
import '../../../helpers/clipboard_helper.dart';
import '../../../helpers/file_save_helper.dart';
import '../../../helpers/temp_file_manager.dart';
import 'package:tool_lab/widgets/workout/workout_colors.dart';
import '../session_pdf_bar_chart.dart';
import '../treadmill_control_state.dart';
import 'package:tool_lab/widgets/workout/workout_session.dart';
import '../../../l10n/app_localizations.dart';
import 'package:tool_lab/widgets/metric_tile.dart';
import 'session_best_card.dart';
import 'session_heart_rate_card.dart';
import 'session_weekly_chart.dart';

class SessionHistoryDashboard extends StatefulWidget {
  const SessionHistoryDashboard({super.key});

  @override
  State<SessionHistoryDashboard> createState() =>
      _SessionHistoryDashboardState();
}

class _SessionHistoryDashboardState extends State<SessionHistoryDashboard>
    with DisposeCleanup {
  final GlobalKey _screenshotKey = GlobalKey();
  late final TempFileScope _tempScope;
  bool _isCapturing = false;
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _tempScope = TempFileManager.createScope();
    onDispose(() => _tempScope.cleanTracked());
  }

  Future<Uint8List?> _captureDashboard() async {
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
      final bytes = await _captureDashboard();
      if (bytes == null || !mounted) return;
      final filename =
          'treadmill_dashboard_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.png';
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
          SnackBar(content: Text(l10n.treadmillHistoryScreenshotFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _generatePdfReport(List<TreadmillSession> sessions) async {
    if (_isGeneratingReport) return;
    setState(() => _isGeneratingReport = true);
    final l10n = AppLocalizations.of(context);
    try {
      final now = DateTime.now();
      final totalDistance = sessions.fold<double>(
        0,
        (sum, session) => sum + session.distance,
      );
      final totalDuration = sessions.fold<int>(
        0,
        (sum, session) => sum + session.elapsedTime,
      );
      final totalCalories = sessions.fold<int>(
        0,
        (sum, session) => sum + session.calories,
      );
      final averageSpeed =
          sessions.fold<double>(0, (sum, session) => sum + session.avgSpeed) /
          sessions.length;
      final longest = sessions.reduce(
        (a, b) => a.distance >= b.distance ? a : b,
      );
      final fastest = sessions.reduce(
        (a, b) => a.maxSpeed >= b.maxSpeed ? a : b,
      );
      final longestDuration = sessions.reduce(
        (a, b) => a.elapsedTime >= b.elapsedTime ? a : b,
      );
      final highestCalories = sessions.reduce(
        (a, b) => a.calories >= b.calories ? a : b,
      );
      final highestSteps = sessions.reduce(
        (a, b) => a.steps >= b.steps ? a : b,
      );
      final heartRateSessions = sessions
          .where((session) => session.avgHeartRate > 0)
          .toList();
      final averageHeartRate = heartRateSessions.isEmpty
          ? null
          : heartRateSessions.fold<double>(
                  0,
                  (sum, session) => sum + session.avgHeartRate,
                ) /
                heartRateSessions.length;
      final peakHeartRate = heartRateSessions.isEmpty
          ? null
          : heartRateSessions.fold<double>(
              0,
              (peak, session) => max(peak, session.maxHeartRate),
            );
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      final weekData = List.generate(7, (index) {
        final day = weekStart.add(Duration(days: index));
        final daySessions = sessions.where((session) {
          final date = DateTime.fromMillisecondsSinceEpoch(session.startTime);
          return date.year == day.year &&
              date.month == day.month &&
              date.day == day.day;
        }).toList();
        final distance = daySessions.fold<double>(
          0,
          (sum, session) => sum + session.distance,
        );
        final withHeartRate = daySessions
            .where((session) => session.avgHeartRate > 0)
            .toList();
        final averageHeartRate = withHeartRate.isEmpty
            ? null
            : withHeartRate.fold<double>(
                    0,
                    (sum, session) => sum + session.avgHeartRate,
                  ) /
                  withHeartRate.length;
        return (day: day, distance: distance, heartRate: averageHeartRate);
      });
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              l10n.treadmillHistoryReportTitle,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${l10n.treadmillHistoryReportGenerated}: ${DateFormat.yMMMd(Localizations.localeOf(this.context).toString()).add_Hm().format(now)}',
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              l10n.treadmillHistoryOverview,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              data: [
                [l10n.treadmillHistoryTotalWorkouts, '${sessions.length}'],
                [
                  l10n.treadmillHistoryTotalDistance,
                  '${totalDistance.toStringAsFixed(2)} km',
                ],
                [l10n.treadmillHistoryTotalDuration, _duration(totalDuration)],
                [l10n.treadmillHistoryTotalCalories, '$totalCalories kcal'],
                [
                  l10n.treadmillHistoryAverageSpeed,
                  '${averageSpeed.toStringAsFixed(1)} km/h',
                ],
              ],
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              l10n.treadmillHistoryPersonalBests,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              data: [
                [
                  l10n.treadmillHistoryLongestRun,
                  '${longest.distance.toStringAsFixed(2)} km',
                ],
                [
                  l10n.treadmillHistoryTopSpeed,
                  '${fastest.maxSpeed.toStringAsFixed(1)} km/h',
                ],
                [
                  l10n.treadmillHistoryLongestDuration,
                  _duration(longestDuration.elapsedTime),
                ],
                [
                  l10n.treadmillHistoryMostCalories,
                  '${highestCalories.calories} kcal',
                ],
                [l10n.treadmillHistoryMostSteps, '${highestSteps.steps}'],
                if (peakHeartRate != null)
                  [
                    l10n.treadmillHistoryPeakHeartRate,
                    '${peakHeartRate.round()} bpm',
                  ],
              ],
            ),
            if (averageHeartRate != null) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                l10n.treadmillHistoryHeartRate,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                data: [
                  [
                    l10n.treadmillHistoryRestingAverage,
                    '${averageHeartRate.round()} bpm',
                  ],
                  [
                    l10n.treadmillHistoryPeakHeartRate,
                    '${peakHeartRate!.round()} bpm',
                  ],
                ],
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Text(
              l10n.treadmillHistoryDistanceLastSevenDays,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            SessionPdfBarChart(
              labels: weekData
                  .map(
                    (item) => DateFormat.E(
                      Localizations.localeOf(this.context).toString(),
                    ).format(item.day),
                  )
                  .toList(),
              values: weekData.map((item) => item.distance).toList(),
              color: PdfColors.cyan700,
              unit: 'km',
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: [l10n.treadmillHistoryReportDate, l10n.distance],
              data: weekData
                  .map(
                    (item) => [
                      DateFormat.yMMMd(
                        Localizations.localeOf(this.context).toString(),
                      ).format(item.day),
                      '${item.distance.toStringAsFixed(2)} km',
                    ],
                  )
                  .toList(),
            ),
            if (weekData.any((item) => item.heartRate != null)) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                l10n.treadmillHistoryHeartRateLastSevenDays,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              SessionPdfBarChart(
                labels: weekData
                    .map(
                      (item) => DateFormat.E(
                        Localizations.localeOf(this.context).toString(),
                      ).format(item.day),
                    )
                    .toList(),
                values: weekData.map((item) => item.heartRate ?? 0).toList(),
                color: PdfColors.red600,
                unit: 'bpm',
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: [l10n.treadmillHistoryReportDate, l10n.hrLabel],
                data: weekData
                    .map(
                      (item) => [
                        DateFormat.yMMMd(
                          Localizations.localeOf(this.context).toString(),
                        ).format(item.day),
                        item.heartRate == null
                            ? '—'
                            : '${item.heartRate!.round()} bpm',
                      ],
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      );
      final bytes = await document.save();
      if (!mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName:
            'treadmill_report_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
        bytes: bytes,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.treadmillHistoryReportFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<TreadmillControlState>().pastSessions;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l10n.treadmillHistoryEmpty, textAlign: TextAlign.center),
        ),
      );
    }

    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final weekSessions = sessions.where((session) {
      return !DateTime.fromMillisecondsSinceEpoch(
        session.startTime,
      ).isBefore(weekStart);
    }).toList();
    final totalDistance = sessions.fold<double>(
      0,
      (sum, s) => sum + s.distance,
    );
    final totalDuration = sessions.fold<int>(
      0,
      (sum, s) => sum + s.elapsedTime,
    );
    final totalCalories = sessions.fold<int>(0, (sum, s) => sum + s.calories);
    final avgSpeed =
        sessions.fold<double>(0, (sum, s) => sum + s.avgSpeed) /
        sessions.length;
    final longest = sessions.reduce((a, b) => a.distance >= b.distance ? a : b);
    final fastest = sessions.reduce((a, b) => a.maxSpeed >= b.maxSpeed ? a : b);
    final longestDuration = sessions.reduce(
      (a, b) => a.elapsedTime >= b.elapsedTime ? a : b,
    );
    final highestCalories = sessions.reduce(
      (a, b) => a.calories >= b.calories ? a : b,
    );
    final highestSteps = sessions.reduce((a, b) => a.steps >= b.steps ? a : b);
    final heartRateSessions = sessions
        .where((session) => session.avgHeartRate > 0)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        key: _screenshotKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.treadmillHistoryOverview,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                PopupMenuButton<_ScreenshotAction>(
                  tooltip: l10n.treadmillHistoryScreenshot,
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
                IconButton(
                  tooltip: l10n.treadmillHistoryGenerateReport,
                  onPressed: _isGeneratingReport
                      ? null
                      : () => _generatePdfReport(sessions),
                  icon: _isGeneratingReport
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.treadmillHistoryOverviewSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 16),
            MetricGrid(
              children: [
                MetricTile(
                  label: l10n.treadmillHistoryTotalDistance,
                  value: '${totalDistance.toStringAsFixed(1)} km',
                  icon: Icons.route_outlined,
                  color: TreadmillColors.cyanMetric,
                ),
                MetricTile(
                  label: l10n.treadmillHistoryTotalDuration,
                  value: _duration(totalDuration),
                  icon: Icons.timer_outlined,
                  color: TreadmillColors.greenMetric,
                ),
                MetricTile(
                  label: l10n.treadmillHistoryTotalCalories,
                  value: '$totalCalories kcal',
                  icon: Icons.local_fire_department_outlined,
                  color: TreadmillColors.amberMetric,
                ),
                MetricTile(
                  label: l10n.treadmillHistoryAverageSpeed,
                  value: '${avgSpeed.toStringAsFixed(1)} km/h',
                  icon: Icons.speed_outlined,
                  color: TreadmillColors.redMetric,
                ),
                MetricTile(
                  label: l10n.treadmillHistoryWorkoutCount,
                  value: '${sessions.length}',
                  icon: Icons.directions_run_outlined,
                  color: TreadmillColors.greenMetric,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.treadmillHistoryDistanceLastSevenDays,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.treadmillHistoryDistanceChartSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 12),
            SessionWeeklyChart(sessions: weekSessions),
            if (heartRateSessions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                l10n.treadmillHistoryHeartRate,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SessionHeartRateCard(sessions: heartRateSessions),
            ],
            const SizedBox(height: 24),
            Text(
              l10n.treadmillHistoryPersonalBests,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SessionBestCard(
              icon: Icons.workspace_premium_outlined,
              label: l10n.treadmillHistoryLongestRun,
              value: '${longest.distance.toStringAsFixed(2)} km',
              subtitle: DateFormat.yMMMd(
                Localizations.localeOf(context).toString(),
              ).format(DateTime.fromMillisecondsSinceEpoch(longest.startTime)),
            ),
            const SizedBox(height: 8),
            SessionBestCard(
              icon: Icons.bolt_outlined,
              label: l10n.treadmillHistoryTopSpeed,
              value: '${fastest.maxSpeed.toStringAsFixed(1)} km/h',
              subtitle:
                  '${l10n.treadmillHistoryAverage}: ${fastest.avgSpeed.toStringAsFixed(1)} km/h',
            ),
            const SizedBox(height: 8),
            SessionBestCard(
              icon: Icons.timer_outlined,
              label: l10n.treadmillHistoryLongestDuration,
              value: _duration(longestDuration.elapsedTime),
              subtitle:
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(
                    DateTime.fromMillisecondsSinceEpoch(
                      longestDuration.startTime,
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            SessionBestCard(
              icon: Icons.local_fire_department_outlined,
              label: l10n.treadmillHistoryMostCalories,
              value: '${highestCalories.calories} kcal',
              subtitle:
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(
                    DateTime.fromMillisecondsSinceEpoch(
                      highestCalories.startTime,
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            SessionBestCard(
              icon: Icons.directions_walk_outlined,
              label: l10n.treadmillHistoryMostSteps,
              value: '${highestSteps.steps}',
              subtitle:
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(
                    DateTime.fromMillisecondsSinceEpoch(highestSteps.startTime),
                  ),
            ),
            if (heartRateSessions.isNotEmpty) ...[
              const SizedBox(height: 8),
              SessionBestCard(
                icon: Icons.favorite_rounded,
                label: l10n.treadmillHistoryPeakHeartRate,
                value:
                    '${heartRateSessions.map((session) => session.maxHeartRate).reduce(max).round()} bpm',
                subtitle: l10n.treadmillHistoryAllTime,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ScreenshotAction { save, copy, share }

String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
