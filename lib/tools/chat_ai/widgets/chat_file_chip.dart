import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/image_preview_dialog.dart';

import '../chat_models.dart';
import '../deepseek/deepseek_api.dart';

/// A file of a message; once DeepSeek's copy is known, images show a
/// thumbnail and every file can be opened or saved.
class ChatFileChip extends StatelessWidget {
  final ChatFile file;
  final bool fromUser;

  const ChatFileChip({super.key, required this.file, required this.fromUser});

  Future<File?> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).chatAiFileDownloadFailed;
    try {
      final target = File(await TempFileManager.createFile(file.name));
      await DeepSeekApi.downloadFile(file.signedPath!, target);
      return target;
    } catch (e) {
      errorLog('[ChatFileChip] Download of ${file.name} failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return null;
    }
  }

  Future<void> _open(BuildContext context) async {
    final signedPath = file.signedPath!;
    if (file.isImage) {
      await ImagePreviewDialog.show(
        context: context,
        image: NetworkImage(
          DeepSeekApi.fileUri(
            signedPath,
            DeepSeekFileVariant.preview,
          ).toString(),
        ),
        label: file.name,
      );
      return;
    }
    final local = await _download(context);
    if (local == null || !context.mounted) return;
    await FileSaveHelper.showOpenChooser(
      context: context,
      path: local.path,
      mimeType: DeepSeekApi.mimeTypeFor(file.name),
    );
  }

  Future<void> _save(BuildContext context) async {
    final local = await _download(context);
    if (local == null || !context.mounted) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: file.name,
      sourcePath: local.path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = fromUser ? scheme.onPrimaryContainer : scheme.onSurface;
    final signedPath = file.signedPath;
    final available = signedPath != null;

    final Widget leading = file.isImage && available
        ? ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: Image.network(
              DeepSeekApi.fileUri(
                signedPath,
                DeepSeekFileVariant.thumbnail,
              ).toString(),
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.image_outlined, color: foreground),
            ),
          )
        : Icon(
            file.isImage
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined,
            color: fromUser ? scheme.onPrimaryContainer : scheme.primary,
          );

    return Material(
      color: fromUser
          ? scheme.onPrimaryContainer.withValues(alpha: 0.1)
          : scheme.onSurface.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: fromUser
              ? scheme.onPrimaryContainer.withValues(alpha: 0.2)
              : scheme.outline.withValues(alpha: 0.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: available ? () => _open(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 8.0),
              Flexible(
                child: Text(
                  file.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (available)
                IconButton(
                  onPressed: () => _save(context),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  color: foreground,
                  tooltip: l10n.commonSave,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
