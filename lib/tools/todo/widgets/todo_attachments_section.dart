import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/todo/models/todo_attachment.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/todo_state.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/tv_file_picker_dialog.dart';

class TodoAttachmentsSection extends StatefulWidget {
  final TodoTask task;

  const TodoAttachmentsSection({super.key, required this.task});

  @override
  State<TodoAttachmentsSection> createState() => _TodoAttachmentsSectionState();
}

class _TodoAttachmentsSectionState extends State<TodoAttachmentsSection>
    with DisposeCleanup {
  late final TempFileScope _scope = TempFileManager.createScope();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    onDispose(() => _scope.cleanTracked());
  }

  Future<void> _addFiles() async {
    final files = await TvFilePickerDialog.openMultipleFiles(context);
    for (final file in files) {
      await _add(file);
    }
  }

  Future<void> _takePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2560,
    );
    if (photo != null) await _add(photo);
  }

  Future<void> _add(XFile file) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<TodoState>();
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final mime = file.mimeType?.isNotEmpty == true
          ? file.mimeType!
          : MimeTypeHelper.getMimeType(
              file.name,
              bytes: bytes.take(32).toList(),
            );
      final ok = await state.addAttachment(
        widget.task,
        name: file.name,
        mimeType: mime,
        data: bytes,
      );
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.todoAttachmentTooLarge(
                FormatHelper.fileSize(TodoState.maxAttachmentBytes),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      errorLog('[TodoAttachments] add failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(TodoAttachment attachment) async {
    final data = await context.read<TodoState>().attachmentData(attachment);
    if (data == null) return;
    final safe = attachment.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final name = '${attachment.shortId}_$safe';
    final path = await _scope.createFile(name, bytes: data);
    await FileSaveHelper.openFile(path, attachment.mimeType);
  }

  Future<void> _share(TodoAttachment attachment) async {
    final data = await context.read<TodoState>().attachmentData(attachment);
    if (data == null) return;
    final safe = attachment.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = await _scope.createFile(
      '${attachment.shortId}_$safe',
      bytes: data,
    );
    await FileSaveHelper.shareFile(path, attachment.mimeType);
  }

  Future<void> _delete(TodoAttachment attachment) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<TodoState>();
    final ok = await ConfirmActionDialog.show(
      context: context,
      title: l10n.todoDeleteAttachment,
      message: attachment.name,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (ok == true) await state.deleteAttachment(attachment);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final attachments = context.watch<TodoState>().attachmentsFor(
      widget.task.shortId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in attachments)
          _AttachmentTile(
            attachment: a,
            onOpen: () => _open(a),
            onShare: () => _share(a),
            onDelete: () => _delete(a),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _addFiles,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file),
                label: Text(l10n.todoAddFile),
              ),
              if (Platform.isAndroid)
                TextButton.icon(
                  onPressed: _busy ? null : _takePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.todoTakePhoto),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final TodoAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _AttachmentTile({
    required this.attachment,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final thumb = attachment.thumbnail;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: thumb != null
              ? Image.memory(thumb, fit: BoxFit.cover, gaplessPlayback: true)
              : ColoredBox(
                  color: scheme.primaryContainer,
                  child: Icon(
                    _iconFor(attachment.mimeType),
                    color: scheme.onPrimaryContainer,
                  ),
                ),
        ),
      ),
      title: Text(
        attachment.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(FormatHelper.fileSize(attachment.size)),
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'share' ? onShare() : onDelete(),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'share', child: Text(l10n.todoShare)),
          PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
        ],
      ),
    );
  }

  static IconData _iconFor(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mime.startsWith('video/')) return Icons.movie_outlined;
    if (mime.startsWith('text/')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }
}
