import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';
import '../fast_drop_state.dart';
import '../fast_drop_model.dart';
import 'fast_drop_item_card.dart';

class FastDropList extends StatelessWidget {
  final FastDropState appState;
  final bool shrinkWrap;
  final void Function(FastDropItem item) onDelete;
  final void Function(FastDropItem item) onPreview;
  final void Function(FastDropItem item) onOpen;
  final void Function(FastDropItem item) onDownload;
  final void Function(FastDropItem item) onEditDescription;
  final void Function(FastDropItem item) onEditRetention;

  const FastDropList({
    super.key,
    required this.appState,
    required this.onDelete,
    required this.onPreview,
    required this.onOpen,
    required this.onDownload,
    required this.onEditDescription,
    required this.onEditRetention,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (appState.isLoadingFastDrops && appState.fastDrops.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: CircularProgressIndicator(color: AppTheme.accentTeal),
        ),
      );
    }

    if (appState.fastDropError != null && appState.fastDrops.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: theme.colorScheme.error.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'Connection Status',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appState.fastDropError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              if (appState.fastDropError != null)
                FilledButton.icon(
                  onPressed: () => appState.loadFastDrops(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry connection'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (appState.fastDrops.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_queue_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No Drops Yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Drag and drop files or paste content from clipboard to save temporarily.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final listView = ListView.builder(
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: appState.fastDrops.length,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemBuilder: (context, index) {
        final item = appState.fastDrops[index];
        return FastDropItemCard(
          item: item,
          onDelete: () => onDelete(item),
          onPreview: () => onPreview(item),
          onOpen: () => onOpen(item),
          onDownload: () => onDownload(item),
          onEditDescription: () => onEditDescription(item),
          onEditRetention: () => onEditRetention(item),
        );
      },
    );

    if (shrinkWrap) {
      return listView;
    }

    return RefreshIndicator(
      onRefresh: () => appState.loadFastDrops(),
      color: AppTheme.accentTeal,
      child: listView,
    );
  }
}
