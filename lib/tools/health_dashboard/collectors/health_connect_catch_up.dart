import 'dart:io';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import '../config.dart';
import 'health_connect_diff.dart';
import 'health_connect_importer.dart';

/// One Health Connect catch-up: the change-token sync plus whatever repair the
/// token's verdict calls for.
///
/// Shared rather than kept in the dashboard state because the backend sync
/// delegate needs exactly the same work when the tool was never opened. A copy
/// that only knew how to *report* a rejected token is what left Health Connect
/// data un-imported for anyone syncing from the settings screen.
class HealthConnectCatchUp {
  const HealthConnectCatchUp();

  /// How far back a recovery re-reads. Health Connect expires a change token
  /// after roughly a month, so nothing older than this can have been missed by
  /// one - and a window costs a fraction of re-reading a decade.
  static const _catchUpDays = 35;

  /// The tool's own refresh runs a catch-up and then kicks off backend sync,
  /// whose delegate would otherwise read the same window again seconds later.
  static const _cooldown = Duration(minutes: 1);

  /// Persisted instead of held in memory: a scheduled background run happens in
  /// its own isolate, where a static knows nothing about what the open app did a
  /// moment ago.
  static const _lastRunKey = 'hc_catch_up_last_run';

  /// [force] belongs to user-initiated runs, which must report what they found
  /// even if an opportunistic one just finished. Unforced callers inside the
  /// cooldown skip the read and report an empty result.
  ///
  /// Never asks for permissions: this also runs from background sync, where a
  /// system consent sheet has no user in front of it. A missing grant simply
  /// reads nothing.
  Future<HealthDiffResult> run({
    bool force = true,
    void Function(String status, int count)? onProgress,
  }) async {
    if (!Platform.isAndroid) return const HealthDiffResult();
    if (!force && await _withinCooldown()) return const HealthDiffResult();
    await _markRun();

    final result = await const HealthConnectDiff().sync(onProgress: onProgress);
    if (result.needsFullImport) return _recover(onProgress);

    // The change feed is the source of truth, but a watch that uploads Tuesday's
    // data on Thursday writes behind a token that has already moved past it. A
    // trailing re-read is the net under that, and a freshly established baseline
    // reports no records at all, so it is the only thing covering that open too.
    try {
      final stored = await const HealthConnectImporter().importRecent(
        onProgress: onProgress,
      );
      if (stored == 0) return result;
      return HealthDiffResult(
        upserted: result.upserted + stored,
        deleted: result.deleted,
        baselineEstablished: result.baselineEstablished,
      );
    } catch (e) {
      errorLog('[HealthCatchUp] Recent safeguard read failed: $e');
      return result;
    }
  }

  Future<bool> _withinCooldown() async {
    final stored = int.tryParse(
      await DatabaseService.instance.getSetting(
            HealthDashboardTool.config.id,
            _lastRunKey,
          ) ??
          '',
    );
    if (stored == null) return false;
    final last = DateTime.fromMillisecondsSinceEpoch(stored);
    return DateTime.now().difference(last) < _cooldown;
  }

  Future<void> _markRun() => DatabaseService.instance.setSetting(
    HealthDashboardTool.config.id,
    _lastRunKey,
    '${DateTime.now().millisecondsSinceEpoch}',
  );

  /// Brings the store back up to date after the change token was rejected.
  ///
  /// This is deliberately **not** the restart import: that wipes every data
  /// table first, so recovering from an expired token would cost the user their
  /// history. It is not the resuming full import either - that one owns the
  /// per-type progress flags, and a month-wide pass through it would mark a
  /// decade of history done. A plain windowed re-read touches neither.
  ///
  /// The new baseline is taken *before* the read, so anything written while the
  /// window is being imported is reported by the next sync rather than falling
  /// into the gap between the two.
  Future<HealthDiffResult> _recover(
    void Function(String status, int count)? onProgress,
  ) async {
    errorLog('[HealthCatchUp] Sync token rejected; re-reading recent history');
    try {
      final baseline = await const HealthConnectDiff().sync();
      final stored = await const HealthConnectImporter().importRecent(
        window: const Duration(days: _catchUpDays),
        onProgress: onProgress,
      );
      debugLog('[HealthCatchUp] Token recovery stored $stored records');
      return baseline.recoveredWith(stored);
    } catch (e) {
      errorLog('[HealthCatchUp] Token recovery failed: $e');
      return const HealthDiffResult(needsFullImport: true);
    }
  }
}
