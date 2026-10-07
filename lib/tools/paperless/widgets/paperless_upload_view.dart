import 'package:file_selector/file_selector.dart'
    show XFile, XTypeGroup, openFiles;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/widgets/file_name_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../config.dart';
import '../models/paperless_upload.dart';
import '../paperless_state.dart';
import 'paperless_upload_options_card.dart';
import 'paperless_upload_tile.dart';
import 'paperless_upload_toolbar.dart';

class PaperlessUploadView extends StatelessWidget {
  final TempFileScope scope;
  final VoidCallback onOpenSettings;

  const PaperlessUploadView({
    super.key,
    required this.scope,
    required this.onOpenSettings,
  });

  void _add(BuildContext context, List<XFile> files) {
    context.read<PaperlessState>().addUploadFiles([
      for (final file in files) (path: file.path, name: file.name),
    ]);
  }

  Future<void> _pickMore(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: l10n.paperlessUploadTypeLabel,
          extensions: PaperlessTool.uploadExtensions,
          mimeTypes: PaperlessTool.uploadMimeTypes,
        ),
      ],
    );
    if (files.isNotEmpty && context.mounted) _add(context, files);
  }

  Future<void> _rename(BuildContext context, PaperlessUpload upload) async {
    final l10n = AppLocalizations.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (_) => FileNameDialog(
        title: l10n.paperlessUploadTitle,
        initialValue: upload.displayTitle,
      ),
    );
    if (title != null && context.mounted) {
      context.read<PaperlessState>().renameUpload(upload.id, title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<PaperlessState>();
    final uploads = state.uploads;

    if (uploads.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: FileDropZone(
          onFilesSelected: (files) => _add(context, files),
          multiple: true,
          allowedExtensions: PaperlessTool.uploadExtensions,
          allowedMimeTypes: PaperlessTool.uploadMimeTypes,
          useAndroidStreamingPicker: true,
          tempScope: scope,
          typeLabel: l10n.paperlessUploadTypeLabel,
          accentColor: PaperlessTool.config.accentColor,
          title: l10n.paperlessUploadDropTitle,
          subtitle: l10n.paperlessUploadDropSubtitle,
          icon: Icons.upload_file_outlined,
        ),
      );
    }

    final hasPending = state.pendingUploadCount > 0;
    return Column(
      children: [
        PaperlessUploadToolbar(
          pendingCount: state.pendingUploadCount,
          isConfigured: state.isConfigured,
          isUploading: state.isUploading,
          canClear: state.hasFinishedUploads,
          onAdd: () => _pickMore(context),
          onClear: state.clearFinishedUploads,
          onUpload: state.startUploads,
          onOpenSettings: onOpenSettings,
        ),
        Expanded(
          child: ReadableWidth(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: uploads.length + (hasPending ? 1 : 0),
              itemBuilder: (context, index) {
                if (hasPending && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: PaperlessUploadOptionsCard(
                      options: state.uploadOptions,
                      onChanged: state.setUploadOptions,
                    ),
                  );
                }
                final upload = uploads[index - (hasPending ? 1 : 0)];
                return PaperlessUploadTile(
                  key: ValueKey(upload.id),
                  upload: upload,
                  onRename: () => _rename(context, upload),
                  onRemove: () => state.removeUpload(upload.id),
                  onRetry: () => state.retryUpload(upload.id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
