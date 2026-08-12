import 'dart:convert';
import 'dart:io';

import 'package:health_connector/health_connector.dart' as hc;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import '../config.dart';
import '../store/health_connect_mapper.dart';
import '../store/health_rows.dart';
import '../store/health_store.dart';
import 'health_connect_types.dart';

class HealthDiffResult {
  final int upserted;
  final int deleted;

  /// True when no token existed and one was just established. Health Connect
  /// returns no records in that case - it only marks a starting point - so this
  /// is not a failure and must not be reported as "nothing changed".
  final bool baselineEstablished;

  /// True when the token was rejected and a full import is the only way back.
  final bool needsFullImport;

  const HealthDiffResult({
    this.upserted = 0,
    this.deleted = 0,
    this.baselineEstablished = false,
    this.needsFullImport = false,
  });
}

/// Incremental Health Connect sync built on the platform's own change tracking.
///
/// This replaces re-reading a trailing time window, which could not be correct:
///
/// - A watch that uploads Tuesday's data on Thursday writes records behind any
///   watermark, so a window either misses them or has to be permanently wide.
/// - A window cannot observe deletions at all. Data removed in Health Connect
///   stayed in our database forever.
///
/// The token is scoped to a type list. Changing the selection invalidates it, so
/// [sync] rebuilds the baseline whenever the scope no longer matches - and the
/// newly enabled type gets its history from the full importer, not from here.
class HealthConnectDiff {
  const HealthConnectDiff();

  static const _tokenKey = 'hc_sync_token';
  static const _tokenScopeKey = 'hc_sync_token_scope';
  static const _maxRounds = 50;

  Future<HealthDiffResult> sync({
    void Function(String status, int count)? onProgress,
  }) async {
    if (!Platform.isAndroid) return const HealthDiffResult();
    final store = HealthStore.instance;
    final enabled = await store.enabledTypes();
    if (enabled.isEmpty) return const HealthDiffResult();
    final dataTypes = HealthConnectTypes.resolve(enabled);
    if (dataTypes.isEmpty) return const HealthDiffResult();

    final scope = (enabled.toList()..sort()).join(',');
    final storedScope = await _setting(_tokenScopeKey);
    final token = storedScope == scope ? await _readToken() : null;
    if (token == null) {
      // Either first run or the selection changed. Establishing a baseline
      // returns nothing by design; history comes from the full importer.
      final established = await _establish(dataTypes, scope);
      return HealthDiffResult(baselineEstablished: established);
    }

    final connector = await hc.HealthConnector.create();
    const mapper = HealthConnectMapper();
    var upserted = 0;
    var deleted = 0;
    int? touchedFrom;
    int? touchedTo;
    var current = token;
    var rounds = 0;
    // Resolved once per type, not per record: the exclusion set is a database
    // read and a change round can carry thousands of records of one type.
    final excludedByType = <String, Set<String>>{};

    try {
      while (rounds < _maxRounds) {
        rounds++;
        final result = await connector.synchronize(
          dataTypes: dataTypes,
          syncToken: current,
        );
        final mapped = <HealthMappedRecord>[];
        for (final record in result.upsertedRecords) {
          // `synchronize()` takes no dataOrigins filter, so a writer the user
          // switched off would otherwise come straight back in here on every
          // open - the full importer's filter does not cover this path.
          final typeId = HealthConnectTypes.idOfRecord(record);
          final excluded = excludedByType[typeId] ??= await store
              .excludedPackages(typeId);
          final row = mapper.map(record);
          if (row.isEmpty || excluded.contains(row.package)) continue;
          mapped.add(row);
          for (final point in row.points) {
            touchedFrom = _min(touchedFrom, point.t);
            touchedTo = _max(touchedTo, point.t);
          }
          for (final interval in row.intervals) {
            touchedFrom = _min(touchedFrom, interval.t0);
            touchedTo = _max(touchedTo, interval.t1);
          }
          final session = row.session;
          if (session != null) {
            touchedFrom = _min(touchedFrom, session.t0);
            touchedTo = _max(touchedTo, session.t1);
          }
        }
        await store.writeRecords(mapped);
        upserted += mapped.length;

        // Sessions are the only rows carrying the Health Connect record id, so
        // they are the only ones a deletion can be matched against. Deleted
        // dense measurements are reconciled by a windowed re-import instead -
        // storing a 36-byte id on every one of three million samples would cost
        // more than the schema saves.
        final ids = result.deletedRecordIds
            .map((id) => id.value)
            .toList(growable: false);
        if (ids.isNotEmpty) {
          await store.deleteSessionsByOrigin(ids);
          await store.deleteIntervalsByOrigin(ids);
          deleted += ids.length;
        }

        final next = result.nextSyncToken;
        if (next != null) {
          current = next;
          await _writeToken(next, scope);
        }
        onProgress?.call('Syncing changes...', upserted);
        if (!result.hasMore || next == null) break;
      }
    } on hc.InvalidArgumentException catch (e) {
      // Expired, or scoped to a type list that no longer matches. Neither is
      // recoverable from here: the baseline is reset and history has to be
      // re-read by the full importer.
      errorLog('[HealthDiff] Sync token rejected, full import needed: $e');
      await _clearToken();
      return const HealthDiffResult(needsFullImport: true);
    }

    if (touchedFrom != null) {
      await store.refreshSessionSummaries(from: touchedFrom, to: touchedTo);
    }
    return HealthDiffResult(upserted: upserted, deleted: deleted);
  }

  Future<bool> _establish(
    List<hc.HealthDataType> dataTypes,
    String scope,
  ) async {
    try {
      final connector = await hc.HealthConnector.create();
      final result = await connector.synchronize(
        dataTypes: dataTypes,
        syncToken: null,
      );
      final token = result.nextSyncToken;
      if (token == null) return false;
      await _writeToken(token, scope);
      return true;
    } catch (e) {
      errorLog('[HealthDiff] Could not establish sync baseline: $e');
      return false;
    }
  }

  Future<hc.HealthDataSyncToken?> _readToken() async {
    final raw = await _setting(_tokenKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return hc.HealthDataSyncToken.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // A token written by a build whose plugin knew a type this one does not
      // throws on parse. Dropping it re-establishes a baseline.
      debugLog('[HealthDiff] Stored token unreadable, dropping it: $e');
      return null;
    }
  }

  Future<void> _writeToken(hc.HealthDataSyncToken token, String scope) async {
    await DatabaseService.instance.setSetting(
      HealthDashboardTool.config.id,
      _tokenKey,
      jsonEncode(token.toJson()),
    );
    await DatabaseService.instance.setSetting(
      HealthDashboardTool.config.id,
      _tokenScopeKey,
      scope,
    );
  }

  /// Drops the stored token so the next [sync] rebuilds the baseline. Needed
  /// after a restore: the token describes changes against a dataset that is no
  /// longer the one we hold.
  Future<void> clearSyncBaseline() => _clearToken();

  Future<void> _clearToken() async {
    await DatabaseService.instance.deleteSetting(
      HealthDashboardTool.config.id,
      _tokenKey,
    );
    await DatabaseService.instance.deleteSetting(
      HealthDashboardTool.config.id,
      _tokenScopeKey,
    );
  }

  Future<String?> _setting(String key) =>
      DatabaseService.instance.getSetting(HealthDashboardTool.config.id, key);

  static int _min(int? current, int value) =>
      current == null || value < current ? value : current;

  static int _max(int? current, int value) =>
      current == null || value > current ? value : current;
}
