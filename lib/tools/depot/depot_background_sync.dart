import 'package:tool_lab/core/background_task.dart';

import 'config.dart';
import 'depot_parqet_sync.dart';
import 'parqet/parqet_exception.dart';

class DepotBackgroundSync {
  DepotBackgroundSync._();

  static final BackgroundTask task = BackgroundTask(
    id: '${DepotTool.config.id}-parqet-sync',
    defaultInterval: const Duration(hours: 1),
    requiresNetwork: true,
    run: _run,
  );

  static Future<BackgroundTaskResult> _run() async {
    if (!await DepotParqetSync.isConnected()) {
      return const BackgroundTaskResult.skipped('Parqet not connected');
    }
    try {
      return BackgroundTaskResult.done(await DepotParqetSync.run());
    } on ParqetException catch (e) {
      // A platform retry cannot log in again; wait for the user instead.
      if (e.needsLogin) return BackgroundTaskResult.skipped('$e');
      return BackgroundTaskResult.failed('$e');
    }
  }
}
