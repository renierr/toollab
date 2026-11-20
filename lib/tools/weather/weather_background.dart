import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/background_task_service.dart';

import 'api/station_catalog.dart';
import 'config.dart';
import 'models/weather_location.dart';
import 'weather_db_helper.dart';
import 'weather_publisher.dart';
import 'weather_repository.dart';
import 'weather_settings.dart';

/// Refreshes the saved weather while the app is closed, so opening the tool
/// shows recent data at once. Runs only the requests whose cache is stale.
class WeatherBackground {
  WeatherBackground._();

  static final BackgroundTask task = BackgroundTask(
    id: '${WeatherTool.config.id}-refresh',
    defaultInterval: const Duration(hours: 1),
    requiresNetwork: true,
    constraints: _constraints,
    run: run,
  );

  static Future<BackgroundTaskConstraints> _constraints() async {
    final s = await WeatherSettings.load();
    return BackgroundTaskConstraints(
      unmeteredNetwork: s.wifiOnly,
      batteryNotLow: s.batteryNotLow,
    );
  }

  static Future<BackgroundTaskResult> run({
    WeatherRepository? repository,
    Future<StationCatalog> Function()? catalogLoader,
    Future<WeatherSettings> Function()? settingsLoader,
    DateTime Function()? clock,
  }) async {
    final settings = await (settingsLoader ?? WeatherSettings.load)();
    if (settings.isQuietAt((clock ?? DateTime.now)().toLocal())) {
      return const BackgroundTaskResult.skipped('quiet hours');
    }
    await WeatherDbHelper.instance.pruneHistory(
      settings.historyCutoff((clock ?? DateTime.now)()),
    );
    final locations = await WeatherDbHelper.instance.getLocations();
    final targets = targetsFor(locations, settings);
    if (targets.isEmpty) return const BackgroundTaskResult.skipped('no places');

    final catalog = await (catalogLoader ?? StationCatalog.load)();
    final repo = repository ?? WeatherRepository();
    var updated = 0;
    var failed = 0;
    for (final location in targets) {
      try {
        final snapshot = await repo.load(location, catalog);
        snapshot.hasData && !snapshot.isStale ? updated++ : failed++;
      } catch (e) {
        debugLog('[WeatherBackground] ${location.name} failed: $e');
        failed++;
      }
    }
    await WeatherPublisher.publish(repository: repo, catalog: catalog);
    final detail = '$updated/${targets.length} places';
    return updated == 0 && failed > 0
        ? BackgroundTaskResult.failed(detail)
        : BackgroundTaskResult.done(detail);
  }

  static List<WeatherLocation> targetsFor(
    List<WeatherLocation> locations,
    WeatherSettings settings,
  ) {
    if (locations.isEmpty) return const [];
    if (settings.backgroundScope == WeatherBackgroundScope.allPlaces) {
      return locations;
    }
    final preferred = locations
        .where((l) => l.id == settings.defaultLocationId)
        .firstOrNull;
    return [preferred ?? locations.first];
  }
}
