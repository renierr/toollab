import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/sync_tool_stats_card.dart';

/// What the configured backend is holding, per tool. Read-only: it reports the
/// server's own figures and never touches local data.
class SyncStatsPage extends StatefulWidget {
  const SyncStatsPage({super.key});

  @override
  State<SyncStatsPage> createState() => _SyncStatsPageState();
}

class _SyncStatsPageState extends State<SyncStatsPage> {
  SyncStats? _stats;
  bool _loading = true;
  bool _unsupported = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
      _unsupported = false;
    });

    if (appState.syncServerUrl.isEmpty) {
      setState(() {
        _loading = false;
        _error = '';
      });
      return;
    }

    try {
      final stats = await SyncService.fetchStats(appState.syncServerUrl);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _unsupported = stats == null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Server namespaces carry the configured user id as a suffix, so the local
  /// tool is matched by stripping it before the lookup.
  ToolModel? _toolFor(String namespace, String userId) {
    var id = namespace;
    if (userId.isNotEmpty && id.endsWith('-$userId')) {
      id = id.substring(0, id.length - userId.length - 1);
    }
    for (final tool in ToolRegistry.all) {
      if (tool.id == id) return tool;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.coreSyncStatsTitle),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.coreSyncStatsRefresh,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          // Full-width cards get unreadable on a desktop window.
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: _load,
            child: _buildBody(context, l10n, appState),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    AppState appState,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _StatsMessage(
        icon: Icons.error_outline,
        color: AppTheme.accentRed,
        message: _error!.isEmpty
            ? l10n.coreSyncFailedNoUrl
            : l10n.coreSyncFailed(_error!),
      );
    }
    if (_unsupported) {
      return _StatsMessage(
        icon: Icons.info_outline,
        color: AppTheme.accentAmber,
        message: l10n.coreSyncStatsUnsupported,
      );
    }

    final stats = _stats;
    if (stats == null || stats.tools.isEmpty) {
      return _StatsMessage(
        icon: Icons.cloud_off_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        message: l10n.coreSyncStatsEmpty,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stats.tools.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _StatsTotals(stats: stats);
        final tool = stats.tools[index - 1];
        return SyncToolStatsCard(
          stats: tool,
          tool: _toolFor(tool.toolId, appState.syncUserId.trim()),
        );
      },
    );
  }
}

class _StatsTotals extends StatelessWidget {
  final SyncStats stats;

  const _StatsTotals({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.coreSyncStatsTotals(stats.tools.length),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _Total(
                  label: l10n.coreSyncStatsItems,
                  value: '${stats.records}',
                ),
                _Total(
                  label: l10n.coreSyncStatsData,
                  value: FormatHelper.fileSize(stats.dataBytes),
                ),
                _Total(
                  label: l10n.coreSyncStatsBinary(stats.binaryRecords),
                  value: FormatHelper.fileSize(stats.binaryBytes),
                ),
                _Total(
                  label: l10n.coreSyncStatsTotalSize,
                  value: FormatHelper.fileSize(stats.totalBytes),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final String value;

  const _Total({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.accentBlue,
          ),
        ),
      ],
    );
  }
}

class _StatsMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _StatsMessage({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works with nothing to show.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(icon, color: color, size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
