import 'dart:io';

import 'package:health_connector/health_connector.dart' as hc;
import 'package:tool_lab/helpers/debug_log.dart';

import '../store/health_connect_mapper.dart';
import '../store/health_rows.dart';
import '../store/health_store.dart';
import 'health_connect_types.dart';

/// Full-history import into the typed store.
///
/// Two things make this cheap compared to the previous importer:
///
/// 1. Only enabled types are read, and each is filtered to the writers the user
///    selected via `dataOrigins`. An unselected source's rows are never handed
///    to us, so the ~1.08M Google Fit heart-rate records cost nothing to skip.
///    Filtering beats deduplicating, which is what the old path did.
/// 2. Nothing is compared against previously stored rows. Exact duplicates
///    collapse on the `health_point` primary key during insert, so the quadratic
///    candidate search is gone.
class HealthConnectImporter {
  const HealthConnectImporter();

  static const _pageSize = 5000;

  Future<void> requestAccess() async {
    if (!Platform.isAndroid) return;
    final connector = await hc.HealthConnector.create();
    await connector.requestPermissions([
      for (final readable in HealthConnectTypes.readable())
        readable.readPermission,
      hc.HealthPlatformFeature.readHealthDataHistory.permission,
    ]);
  }

  /// Imports every enabled type. [restart] ignores stored progress and re-reads
  /// from [start]; otherwise a type that has not finished resumes over the range
  /// it was already covering, so the window cannot drift with the clock.
  Future<int> import({
    required DateTime start,
    bool restart = false,
    void Function(String status, int count)? onProgress,
  }) async {
    if (!Platform.isAndroid) return 0;
    final connector = await hc.HealthConnector.create();
    const mapper = HealthConnectMapper();
    final store = HealthStore.instance;
    final enabled = await store.enabledTypes();
    final now = DateTime.now();
    var total = 0;
    var failed = 0;
    var attempted = 0;
    int? touchedFrom;
    int? touchedTo;

    for (final readable in HealthConnectTypes.readable()) {
      final typeId = HealthConnectTypes.idOf(readable);
      if (!enabled.contains(typeId)) continue;
      final row = await store.typeRow(typeId);
      final historyDone = (row?['history_done'] as int? ?? 0) == 1;
      if (historyDone && !restart) continue;
      attempted++;

      final rangeStart = restart || row?['range_start'] == null
          ? start
          : DateTime.fromMillisecondsSinceEpoch(row!['range_start'] as int);
      final rangeEnd = restart || row?['range_end'] == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(row!['range_end'] as int);
      var imported = restart ? 0 : (row?['n'] as num?)?.toInt() ?? 0;

      final packages = await store.enabledPackages(typeId);
      // Empty means "no restriction", which is also how a type looks before
      // discovery has run. Selecting nothing is expressed by disabling the type.
      final origins = [for (final package in packages) hc.DataOrigin(package)];

      try {
        // Paging follows response.nextPageRequest. This plugin exposes no page
        // token on the read response; reading one threw before the first page
        // could be written, which made a full import finish in seconds and
        // store nothing.
        dynamic request = readable.readInTimeRange(
          startTime: rangeStart,
          endTime: rangeEnd,
          pageSize: _pageSize,
          dataOrigins: origins,
        );
        do {
          final dynamic response = await connector.readRecords(request);
          final mapped = <HealthMappedRecord>[];
          for (final record
              in (response.records as List).cast<hc.HealthRecord>()) {
            final result = mapper.map(record);
            if (result.isEmpty) continue;
            mapped.add(result);
            for (final point in result.points) {
              touchedFrom = _min(touchedFrom, point.t);
              touchedTo = _max(touchedTo, point.t);
            }
            for (final interval in result.intervals) {
              touchedFrom = _min(touchedFrom, interval.t0);
              touchedTo = _max(touchedTo, interval.t1);
            }
            final session = result.session;
            if (session != null) {
              touchedFrom = _min(touchedFrom, session.t0);
              touchedTo = _max(touchedTo, session.t1);
            }
          }
          request = response.nextPageRequest;
          imported += mapped.length;
          // The page and its progress land in one transaction, so an interrupted
          // import never claims to have stored more than it did.
          await store.writeRecords(mapped);
          await store.markTypeProgress(
            type: typeId,
            count: imported,
            historyDone: request == null,
            rangeStart: rangeStart.millisecondsSinceEpoch,
            rangeEnd: rangeEnd.millisecondsSinceEpoch,
          );
          total += mapped.length;
          onProgress?.call('Importing $typeId...', total);
        } while (request != null);
      } catch (e) {
        failed++;
        errorLog('[HealthImporter] $typeId failed: $e');
      }
    }

    // Distance, energy and heart rate arrive as their own records, so a session's
    // summary can only be joined once both sides are stored.
    if (touchedFrom != null) {
      onProgress?.call('Summarising workouts...', total);
      await HealthStore.instance.refreshSessionSummaries(
        from: touchedFrom,
        to: touchedTo,
      );
    }

    // Failures are tolerated per type, which adds up to a silent no-op when they
    // hit every type - what a revoked read permission looks like.
    if (total == 0 && failed > 0 && failed == attempted) {
      throw StateError(
        'Health Connect returned no records and all $failed selected type(s) '
        'failed to read - check that the app still has read permission.',
      );
    }
    return total;
  }

  static int _min(int? current, int value) =>
      current == null || value < current ? value : current;

  static int _max(int? current, int value) =>
      current == null || value > current ? value : current;
}
