import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../chat_ai_state.dart';
import '../deepseek/deepseek_attachment.dart';

class DeepSeekAttachmentStrip extends StatelessWidget {
  const DeepSeekAttachmentStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final files = context.select<ChatAiState, List<DeepSeekAttachment>>(
      (state) => state.deepSeekFiles,
    );
    if (files.isEmpty) return const SizedBox.shrink();
    // Many files must not push the text field off a short screen.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 132.0),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [for (final file in files) _AttachmentChip(file: file)],
          ),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final DeepSeekAttachment file;

  const _AttachmentChip({required this.file});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final failed = file.status == DeepSeekUploadStatus.failed;

    final Widget avatar = switch (file.status) {
      DeepSeekUploadStatus.uploading => const Padding(
        padding: EdgeInsets.all(3.0),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      DeepSeekUploadStatus.failed => Icon(
        Icons.error_outline,
        color: scheme.error,
      ),
      DeepSeekUploadStatus.ready when file.isImage => ClipRRect(
        borderRadius: BorderRadius.circular(4.0),
        child: Image(
          image: ResizeImage(FileImage(File(file.path)), width: 64),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
        ),
      ),
      DeepSeekUploadStatus.ready => const Icon(
        Icons.insert_drive_file_outlined,
      ),
    };

    return Tooltip(
      message: switch (file.status) {
        DeepSeekUploadStatus.uploading => l10n.chatAiFileUploading,
        DeepSeekUploadStatus.failed => l10n.chatAiFileUploadFailed,
        DeepSeekUploadStatus.ready => file.name,
      },
      child: InputChip(
        avatar: SizedBox.square(dimension: 24, child: avatar),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(file.name, overflow: TextOverflow.ellipsis),
        ),
        side: failed ? BorderSide(color: scheme.error) : null,
        onDeleted: () => context.read<ChatAiState>().removeDeepSeekFile(file),
        deleteButtonTooltipMessage: l10n.commonRemove,
      ),
    );
  }
}
