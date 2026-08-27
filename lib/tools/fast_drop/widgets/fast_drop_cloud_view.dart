import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_orientation_layout.dart';

import '../fast_drop_model.dart';
import '../fast_drop_state.dart';
import 'fast_drop_list.dart';
import 'fast_drop_pending_card.dart';
import 'fast_drop_upload_panel.dart';

/// The cloud half of Fast Drop: upload panel plus the list of drops, stacked in
/// portrait and side by side in landscape.
class FastDropCloudView extends StatelessWidget {
  final FastDropState fastDropState;
  final List<SharedFile> pendingFiles;
  final bool isUploadingPending;
  final bool isActionsEnabled;
  final VoidCallback onUploadPending;
  final VoidCallback onDismissPending;
  final String retention;
  final ValueChanged<String> onRetentionChanged;
  final ValueChanged<List<XFile>> onFilesSelected;
  final VoidCallback onPasteClipboard;
  final TempFileScope tempScope;
  final ValueChanged<FastDropItem> onDelete;
  final ValueChanged<FastDropItem> onPreview;
  final ValueChanged<FastDropItem> onOpen;
  final ValueChanged<FastDropItem> onDownload;
  final ValueChanged<FastDropItem> onEditDescription;
  final ValueChanged<FastDropItem> onEditRetention;

  const FastDropCloudView({
    super.key,
    required this.fastDropState,
    required this.pendingFiles,
    required this.isUploadingPending,
    required this.isActionsEnabled,
    required this.onUploadPending,
    required this.onDismissPending,
    required this.retention,
    required this.onRetentionChanged,
    required this.onFilesSelected,
    required this.onPasteClipboard,
    required this.tempScope,
    required this.onDelete,
    required this.onPreview,
    required this.onOpen,
    required this.onDownload,
    required this.onEditDescription,
    required this.onEditRetention,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The panels below scroll, so the viewport height has to be measured
        // out here where it is still bounded.
        final shortViewport = constraints.maxHeight < 700;

        final uploadColumn = <Widget>[
          if (pendingFiles.isNotEmpty) ...[
            FastDropPendingCard(
              files: pendingFiles,
              isUploading: isUploadingPending,
              isActionsEnabled: isActionsEnabled,
              onUpload: onUploadPending,
              onDismiss: onDismissPending,
            ),
            const SizedBox(height: 16),
          ],
          FastDropUploadPanel(
            retention: retention,
            onRetentionChanged: onRetentionChanged,
            onFilesSelected: onFilesSelected,
            onPasteClipboard: onPasteClipboard,
            isActionsEnabled: isActionsEnabled,
            tempScope: tempScope,
            shortViewport: shortViewport,
          ),
        ];

        return ResponsiveOrientationLayout(
          portrait: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...uploadColumn,
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    l10n.fastDropSectionTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _list(shrinkWrap: true),
                ],
              ),
            ),
          ),
          landscape: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: uploadColumn,
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _list()),
            ],
          ),
        );
      },
    );
  }

  FastDropList _list({bool shrinkWrap = false}) => FastDropList(
    appState: fastDropState,
    shrinkWrap: shrinkWrap,
    onDelete: onDelete,
    onPreview: onPreview,
    onOpen: onOpen,
    onDownload: onDownload,
    onEditDescription: onEditDescription,
    onEditRetention: onEditRetention,
  );
}
