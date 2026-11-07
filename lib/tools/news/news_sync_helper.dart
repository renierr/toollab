import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/providers/app_state.dart';

import 'config.dart';
import 'news_sync_delegate.dart';

/// Source edits are small and infrequent, so they push immediately instead of
/// waiting for the next global sync. `AppState` owns the per-tool gate.
Future<void> syncNewsSources(AppState appState) async {
  if (appState.syncServerUrl.isEmpty) return;
  if (!appState.isToolSyncEnabled(NewsTool.config.id)) return;
  try {
    await appState.syncWithBackend([NewsSyncDelegate()]);
  } catch (e) {
    debugLog('[News] Source sync failed: $e');
  }
}
