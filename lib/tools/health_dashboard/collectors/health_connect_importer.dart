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

  /// Asks for every read permission the tool uses, and reports whether anything
  /// is actually granted afterwards. False means a read would return nothing, so
  /// callers offer the Health Connect screen instead of silently importing zero
  /// records.
  Future<bool> requestAccess() async {
    if (!Platform.isAndroid) return false;
    final connector = await hc.HealthConnector.create();
    final results = await connector.requestPermissions([
      for (final readable in HealthConnectTypes.readable())
        readable.readPermission,
      hc.HealthPlatformFeature.readHealthDataHistory.permission,
      hc.HealthPlatformFeature.readHealthDataInBackground.permission,
    ]);
    if (results.any((result) => result.status == hc.PermissionStatus.granted)) {
      return true;
    }
    // The request sheet can close without a result of its own, so the granted
    // set decides rather than the sheet's return value.
    try {
      return (await connector.getGrantedPermissions()).isNotEmpty;
    } catch (e) {
      errorLog('[HealthImporter] Reading granted permissions failed: $e');
      return false;
    }
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
    final store = HealthStore.instance;
    final enabled = await store.enabledTypes();
    final now = DateTime.now();
    var total = 0;
    var failed = 0;
    var attempted = 0;
    final touched = _TouchedRange();

    for (final readable in HealthConnectTypes.readable()) {
      final typeId = HealthConnectTypes.idOf(readable);
      if (!enabled.contains(typeId)) continue;
      final row = await store.typeRow(typeId);
      if ((row?.historyDone ?? false) && !restart) continue;
      attempted++;

      final pendingStart = restart ? null : row?.rangeStart;
      final pendingEnd = restart ? null : row?.rangeEnd;
      final rangeStart = pendingStart == null
          ? start
          : DateTime.fromMillisecondsSinceEpoch(pendingStart);
      final rangeEnd = pendingEnd == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(pendingEnd);
      var imported = restart ? 0 : (row?.count ?? 0);

      // Health Connect only understands dataOrigins as an allowlist, and the
      // list can only name writers discovery attributed to this type. Since
      // discovery probes a bounded window, an empty filter deliberately means
      // "no restriction" rather than dropping every writer it did not see. The
      // gap that leaves: a writer switched off globally that discovery never saw
      // under this type is not in the list, so its records arrive anyway and
      // have to be dropped here - exactly what the change sync does, since
      // synchronize() takes no origin filter at all.
      final packages = await store.dataOriginFilter(typeId);
      final origins = [for (final package in packages) hc.DataOrigin(package)];
      final excluded = await store.excludedPackages(typeId);

      try {
        await _readPages(
          connector: connector,
          readable: readable,
          start: rangeStart,
          end: rangeEnd,
          origins: origins,
          excluded: excluded,
          touched: touched,
          onPage: (page, last) async {
            imported += page.length;
            // The page and its progress land in one transaction, so an
            // interrupted import never claims to have stored more than it did.
            await store.writeRecords(page);
            await store.markTypeProgress(
              type: typeId,
              count: imported,
              historyDone: last,
              rangeStart: rangeStart.millisecondsSinceEpoch,
              rangeEnd: rangeEnd.millisecondsSinceEpoch,
            );
            total += page.length;
            onProgress?.call('Importing $typeId...', total);
          },
        );
      } catch (e) {
        failed++;
        errorLog('[HealthImporter] $typeId failed: $e');
      }
    }

    // Distance, energy and heart rate arrive as their own records, so a session's
    // summary can only be joined once both sides are stored.
    if (!touched.isEmpty) {
      onProgress?.call('Summarising workouts...', total);
      await store.refreshSessionSummaries(from: touched.from!, to: touched.to);
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

  /// Re-reads a trailing [window] and returns the rows it actually stored.
  ///
  /// Deliberately blind to the per-type import bookkeeping: it neither skips a
  /// finished type nor records progress, so a window read can never move a
  /// pagination cursor or mark a decade of history done after covering a month.
  /// Re-reading is safe because it is idempotent - a measurement already stored
  /// collapses on the primary key - which is also why the count comes from the
  /// store rather than from what Health Connect handed over.
  Future<int> importRecent({
    Duration window = const Duration(days: 2),
    void Function(String status, int count)? onProgress,
  }) async {
    if (!Platform.isAndroid) return 0;
    final connector = await hc.HealthConnector.create();
    final store = HealthStore.instance;
    final enabled = await store.enabledTypes();
    final now = DateTime.now();
    final rangeStart = now.subtract(window);
    var stored = 0;
    final touched = _TouchedRange();

    for (final readable in HealthConnectTypes.readable()) {
      final typeId = HealthConnectTypes.idOf(readable);
      if (!enabled.contains(typeId)) continue;

      final packages = await store.dataOriginFilter(typeId);
      final origins = [for (final package in packages) hc.DataOrigin(package)];
      final excluded = await store.excludedPackages(typeId);

      try {
        await _readPages(
          connector: connector,
          readable: readable,
          start: rangeStart,
          end: now,
          origins: origins,
          excluded: excluded,
          touched: touched,
          onPage: (page, last) async {
            if (page.isNotEmpty) stored += await store.writeRecords(page);
            onProgress?.call('Reading recent $typeId...', stored);
          },
        );
      } catch (e) {
        errorLog('[HealthImporter] Recent read for $typeId failed: $e');
      }
    }

    if (!touched.isEmpty) {
      await store.refreshSessionSummaries(from: touched.from!, to: touched.to);
    }
    return stored;
  }

  /// Pages one type over a range, handing each page to [onPage] along with
  /// whether it was the last. Paging follows `response.nextPageRequest`: this
  /// plugin exposes no page token on the read response, and reading one threw
  /// before the first page could be written, which made a full import finish in
  /// seconds and store nothing.
  Future<void> _readPages({
    required hc.HealthConnector connector,
    required ReadableHealthType readable,
    required DateTime start,
    required DateTime end,
    required List<hc.DataOrigin> origins,
    required Set<String> excluded,
    required _TouchedRange touched,
    required Future<void> Function(List<HealthMappedRecord> page, bool last)
    onPage,
  }) async {
    const mapper = HealthConnectMapper();
    dynamic request = readable.readInTimeRange(
      startTime: start,
      endTime: end,
      pageSize: _pageSize,
      dataOrigins: origins,
    );
    do {
      final dynamic response = await connector.readRecords(request);
      final page = <HealthMappedRecord>[];
      for (final record in (response.records as List).cast<hc.HealthRecord>()) {
        final result = mapper.map(record);
        // Exclusion is checked on the writer the row would be stored under, not
        // on the raw data origin, so switching a source off matches what the
        // tables actually hold.
        if (result.isEmpty || excluded.contains(result.package)) continue;
        page.add(result);
        touched.add(result);
      }
      request = response.nextPageRequest;
      await onPage(page, request == null);
    } while (request != null);
  }
}

/// The span the written rows cover, which is all the session summaries need to
/// know to recompute the right days.
class _TouchedRange {
  int? from;
  int? to;

  bool get isEmpty => from == null;

  void add(HealthMappedRecord record) {
    for (final point in record.points) {
      _widen(point.t, point.t);
    }
    for (final interval in record.intervals) {
      _widen(interval.t0, interval.t1);
    }
    final session = record.session;
    if (session != null) _widen(session.t0, session.t1);
    final nutrition = record.nutrition;
    if (nutrition != null) _widen(nutrition.t0, nutrition.t1);
  }

  void _widen(int t0, int t1) {
    if (from == null || t0 < from!) from = t0;
    if (to == null || t1 > to!) to = t1;
  }
}
