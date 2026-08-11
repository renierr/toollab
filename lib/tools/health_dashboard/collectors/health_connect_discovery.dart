import 'dart:io';

import 'package:health_connector/health_connector.dart' as hc;
import 'package:tool_lab/helpers/debug_log.dart';

import '../store/health_connect_mapper.dart';
import '../store/health_store.dart';
import 'health_connect_types.dart';

/// Probes Health Connect to find which types hold data and which apps wrote it.
///
/// Bounded on purpose: it reads a recent window with a page cap, so it finishes
/// in seconds instead of the hours a full read costs. It exists to populate the
/// selection screens - the user cannot choose sources they have never been shown.
///
/// It never changes an existing selection. A source the user switched off stays
/// off when it is rediscovered.
class HealthConnectDiscovery {
  const HealthConnectDiscovery();

  // Wide enough that a writer which only contributes occasionally still shows
  // up, small enough to finish in seconds. The probe is a hint either way: the
  // import filter only excludes what the user switched off, so a writer this
  // misses is still imported.
  static const _maxPagesPerType = 6;
  static const _pageSize = 500;

  Future<int> run({
    Duration window = const Duration(days: 365),
    void Function(String status, int count)? onProgress,
  }) async {
    if (!Platform.isAndroid) return 0;
    final connector = await hc.HealthConnector.create();
    final end = DateTime.now();
    final start = end.subtract(window);
    var found = 0;
    for (final readable in HealthConnectTypes.readable()) {
      final typeId = HealthConnectTypes.idOf(readable);
      await HealthStore.instance.registerType(
        typeId,
        defaultEnabled: HealthConnectTypes.defaults.contains(typeId),
      );
      onProgress?.call('Scanning $typeId...', found);
      try {
        final counts = <String, int>{};
        final lastSeen = <String, int>{};
        dynamic request = readable.readInTimeRange(
          startTime: start,
          endTime: end,
          pageSize: _pageSize,
        );
        var pages = 0;
        do {
          final dynamic response = await connector.readRecords(request);
          for (final record
              in (response.records as List).cast<hc.HealthRecord>()) {
            // Same resolution the mapper uses, so the debug generator shows up
            // as its own source on the selection screens rather than hiding
            // inside this app's own package.
            final package = HealthConnectMapper.packageOf(record);
            counts[package] = (counts[package] ?? 0) + 1;
            final time = switch (record) {
              hc.InstantHealthRecord(:final time) => time,
              hc.IntervalHealthRecord(:final endTime) => endTime,
            }.millisecondsSinceEpoch;
            if (time > (lastSeen[package] ?? 0)) lastSeen[package] = time;
          }
          request = response.nextPageRequest;
          pages++;
        } while (request != null && pages < _maxPagesPerType);
        for (final entry in counts.entries) {
          await HealthStore.instance.recordDiscoveredApp(
            type: typeId,
            package: entry.key,
            count: entry.value,
            lastSeen: lastSeen[entry.key],
          );
          found++;
        }
      } catch (e) {
        // A type this Health Connect build cannot read is normal and must not
        // abort discovery of the rest.
        debugLog('[HealthDiscovery] $typeId unavailable: $e');
      }
    }
    onProgress?.call('Discovery finished', found);
    return found;
  }
}
