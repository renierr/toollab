import 'package:tool_lab/services/background_work_lease.dart';

/// Keeps a user-started sync running with the screen off or the app in the
/// background. The page fills in the localized notification texts.
class DepotWorkLease {
  DepotWorkLease._();

  static String title = 'Depot';
  static String syncText = 'Syncing with Parqet…';
  static String allocationText = 'Loading allocation data…';

  static Future<T> hold<T>(String text, Future<T> Function() work) async {
    final lease = await BackgroundWorkLease.acquire(
      title: title,
      text: text,
      logPrefix: 'Depot',
    );
    try {
      return await work();
    } finally {
      await lease.release();
    }
  }
}
