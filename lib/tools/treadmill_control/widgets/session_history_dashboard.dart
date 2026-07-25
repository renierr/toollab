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
import '../../../helpers/file_save_helper.dart';
import '../../../helpers/temp_file_manager.dart';
import '../treadmill_control_colors.dart';
import '../treadmill_control_state.dart';
import '../treadmill_session.dart';
import '../../../l10n/app_localizations.dart';

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

  Future<void> _handleScreenshot(bool share) async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _captureDashboard();
      if (bytes == null || !mounted) return;
      final filename =
          'treadmill_dashboard_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.png';
      if (share) {
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
            _PdfBarChart(
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
              _PdfBarChart(
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
                PopupMenuButton<bool>(
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
                      value: false,
                      child: Text(l10n.treadmillHistorySaveScreenshot),
                    ),
                    PopupMenuItem(
                      value: true,
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
            _MetricGrid(
              children: [
                _Metric(
                  label: l10n.treadmillHistoryTotalDistance,
                  value: '${totalDistance.toStringAsFixed(1)} km',
                  icon: Icons.route_outlined,
                  color: TreadmillColors.cyanMetric,
                ),
                _Metric(
                  label: l10n.treadmillHistoryTotalDuration,
                  value: _duration(totalDuration),
                  icon: Icons.timer_outlined,
                  color: TreadmillColors.greenMetric,
                ),
                _Metric(
                  label: l10n.treadmillHistoryTotalCalories,
                  value: '$totalCalories kcal',
                  icon: Icons.local_fire_department_outlined,
                  color: TreadmillColors.amberMetric,
                ),
                _Metric(
                  label: l10n.treadmillHistoryAverageSpeed,
                  value: '${avgSpeed.toStringAsFixed(1)} km/h',
                  icon: Icons.speed_outlined,
                  color: TreadmillColors.redMetric,
                ),
                _Metric(
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
            _WeeklyChart(sessions: weekSessions),
            if (heartRateSessions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                l10n.treadmillHistoryHeartRate,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _HeartRateCard(sessions: heartRateSessions),
            ],
            const SizedBox(height: 24),
            Text(
              l10n.treadmillHistoryPersonalBests,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _BestCard(
              icon: Icons.workspace_premium_outlined,
              label: l10n.treadmillHistoryLongestRun,
              value: '${longest.distance.toStringAsFixed(2)} km',
              subtitle: DateFormat.yMMMd(
                Localizations.localeOf(context).toString(),
              ).format(DateTime.fromMillisecondsSinceEpoch(longest.startTime)),
            ),
            const SizedBox(height: 8),
            _BestCard(
              icon: Icons.bolt_outlined,
              label: l10n.treadmillHistoryTopSpeed,
              value: '${fastest.maxSpeed.toStringAsFixed(1)} km/h',
              subtitle:
                  '${l10n.treadmillHistoryAverage}: ${fastest.avgSpeed.toStringAsFixed(1)} km/h',
            ),
            const SizedBox(height: 8),
            _BestCard(
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
            _BestCard(
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
            _BestCard(
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
              _BestCard(
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

class _PdfBarChart extends pw.StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final PdfColor color;
  final String unit;

  _PdfBarChart({
    required this.labels,
    required this.values,
    required this.color,
    required this.unit,
  });

  @override
  pw.Widget build(pw.Context context) {
    final maxValue = max(1.0, values.reduce(max));
    return pw.SizedBox(
      height: 150,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: List.generate(
          values.length,
          (index) => pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    '${values[index].toStringAsFixed(unit == 'bpm' ? 0 : 1)} $unit',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    height: max(3, 100 * values[index] / maxValue),
                    decoration: pw.BoxDecoration(
                      color: color,
                      borderRadius: const pw.BorderRadius.vertical(
                        top: pw.Radius.circular(3),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    labels[index],
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';

class _MetricGrid extends StatelessWidget {
  final List<_Metric> children;
  const _MetricGrid({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children
          .map(
            (child) => SizedBox(
              width: constraints.maxWidth < 500
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 36) / 4,
              child: child,
            ),
          )
          .toList(),
    ),
  );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  const _BestCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: TreadmillColors.amberMetric),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
  );
}

class _HeartRateCard extends StatelessWidget {
  final List<TreadmillSession> sessions;

  const _HeartRateCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final totalDuration = sessions.fold<int>(
      0,
      (sum, session) => sum + session.elapsedTime,
    );
    final weightedAverage = totalDuration == 0
        ? sessions.fold<double>(
                0,
                (sum, session) => sum + session.avgHeartRate,
              ) /
              sessions.length
        : sessions.fold<double>(
                0,
                (sum, session) =>
                    sum + session.avgHeartRate * session.elapsedTime,
              ) /
              totalDuration;
    final peak = sessions.fold<double>(
      0,
      (maxHeartRate, session) => max(maxHeartRate, session.maxHeartRate),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TreadmillColors.redMetric.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: TreadmillColors.redMetric,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.treadmillHistoryHeartRateSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _HeartRateValue(
                    label: l10n.treadmillHistoryRestingAverage,
                    value: '${weightedAverage.round()} bpm',
                  ),
                ),
                Container(width: 1, height: 42, color: theme.dividerColor),
                Expanded(
                  child: _HeartRateValue(
                    label: l10n.treadmillHistoryPeakHeartRate,
                    value: '${peak.round()} bpm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _HeartRateTrend(sessions: sessions),
          ],
        ),
      ),
    );
  }
}

class _HeartRateValue extends StatelessWidget {
  final String label;
  final String value;

  const _HeartRateValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: TreadmillColors.redMetric,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _HeartRateTrend extends StatelessWidget {
  final List<TreadmillSession> sessions;

  const _HeartRateTrend({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index)),
    );
    final values = days.map((day) {
      final daySessions = sessions.where((session) {
        final date = DateTime.fromMillisecondsSinceEpoch(session.startTime);
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).toList();
      if (daySessions.isEmpty) return null;
      return daySessions.fold<double>(
            0,
            (sum, session) => sum + session.avgHeartRate,
          ) /
          daySessions.length;
    }).toList();
    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _HeartRateTrendPainter(
          values: values,
          lineColor: TreadmillColors.redMetric,
          gridColor: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        DateFormat.E(
                          Localizations.localeOf(context).toString(),
                        ).format(day),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _HeartRateTrendPainter extends CustomPainter {
  final List<double?> values;
  final Color lineColor;
  final Color gridColor;

  const _HeartRateTrendPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 18.0;
    const axisWidth = 36.0;
    final chartHeight = size.height - labelHeight;
    final knownValues = values.whereType<double>().toList();
    if (knownValues.isEmpty) return;
    final minValue = max(40, knownValues.reduce(min) - 10).toDouble();
    final maxValue = max(
      minValue + 20,
      knownValues.reduce(max) + 10,
    ).toDouble();
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 1; index < 4; index++) {
      final y = chartHeight * index / 4;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), gridPaint);
    }
    final labelStyle = TextStyle(color: gridColor, fontSize: 10);
    for (final fraction in [0.0, 0.5, 1.0]) {
      final value = maxValue - (maxValue - minValue) * fraction;
      final label = TextPainter(
        text: TextSpan(text: '${value.round()}', style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 2);
      label.paint(canvas, Offset(0, chartHeight * fraction - label.height / 2));
    }
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = lineColor;
    final points = <Offset?>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        points.add(null);
        continue;
      }
      final x =
          axisWidth + (size.width - axisWidth) * index / (values.length - 1);
      final y =
          chartHeight -
          (value - minValue) / (maxValue - minValue) * chartHeight;
      points.add(Offset(x, y));
    }
    for (var index = 0; index < points.length; index++) {
      final start = points[index];
      if (start == null || (index > 0 && points[index - 1] != null)) continue;
      final path = Path()..moveTo(start.dx, start.dy);
      var pointIndex = index + 1;
      while (pointIndex < points.length && points[pointIndex] != null) {
        final end = points[pointIndex]!;
        final previous = points[pointIndex - 1]!;
        final controlX = (previous.dx + end.dx) / 2;
        path.cubicTo(controlX, previous.dy, controlX, end.dy, end.dx, end.dy);
        pointIndex++;
      }
      canvas.drawPath(path, linePaint);
    }
    for (final point in points.whereType<Offset>()) {
      canvas.drawCircle(point, 3.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeartRateTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<TreadmillSession> sessions;
  const _WeeklyChart({required this.sessions});
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index)),
    );
    final distances = days
        .map(
          (day) => sessions
              .where((session) {
                final date = DateTime.fromMillisecondsSinceEpoch(
                  session.startTime,
                );
                return date.year == day.year &&
                    date.month == day.month &&
                    date.day == day.day;
              })
              .fold<double>(0, (sum, session) => sum + session.distance),
        )
        .toList();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        child: SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _DistanceChartPainter(
              values: distances,
              barColor: TreadmillColors.cyanMetric,
              lineColor: TreadmillColors.greenMetric,
              gridColor: theme.dividerColor.withValues(alpha: 0.45),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            DateFormat.E(
                              Localizations.localeOf(context).toString(),
                            ).format(day),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistanceChartPainter extends CustomPainter {
  final List<double> values;
  final Color barColor;
  final Color lineColor;
  final Color gridColor;

  const _DistanceChartPainter({
    required this.values,
    required this.barColor,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const axisWidth = 36.0;
    const labelHeight = 20.0;
    const valueLabelHeight = 18.0;
    final chartHeight = size.height - labelHeight - valueLabelHeight;
    final maxValue = max(1.0, values.reduce(max));
    final axisMaximum = (maxValue * 1.2).ceilToDouble();
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: gridColor, fontSize: 10);
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = valueLabelHeight + chartHeight * fraction;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), gridPaint);
      final value = axisMaximum * (1 - fraction);
      final label = TextPainter(
        text: TextSpan(
          text: '${value.toStringAsFixed(0)} km',
          style: labelStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 2);
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    final step = (size.width - axisWidth) / values.length;
    final barPaint = Paint()..color = barColor.withValues(alpha: 0.6);
    final pointPaint = Paint()..color = lineColor;
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final centerX = axisWidth + step * (index + 0.5);
      final barHeight = chartHeight * value / axisMaximum;
      final y = valueLabelHeight + chartHeight - barHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - step * 0.22, y, step * 0.44, barHeight),
          const Radius.circular(5),
        ),
        barPaint,
      );
      final valueLabel = TextPainter(
        text: TextSpan(
          text: value == 0 ? '0' : value.toStringAsFixed(1),
          style: TextStyle(
            color: barColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      valueLabel.paint(
        canvas,
        Offset(
          centerX - valueLabel.width / 2,
          max(0, y - valueLabel.height - 3),
        ),
      );
      points.add(Offset(centerX, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final point = points[index];
      final controlX = (previous.dx + point.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        point.dy,
        point.dx,
        point.dy,
      );
    }
    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DistanceChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.barColor != barColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
