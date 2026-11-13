import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/paperless_upload.dart';
import '../paperless_state.dart';
import 'paperless_label_dropdown.dart';
import 'paperless_tag_selector.dart';

typedef PaperlessUploadEdit = ({
  String? title,
  DateTime? created,
  int? correspondentId,
  int? documentTypeId,
  Set<int> tagIds,
});

class PaperlessUploadEditSheet extends StatefulWidget {
  final PaperlessUpload upload;
  final PaperlessUploadOptions batch;

  const PaperlessUploadEditSheet({
    super.key,
    required this.upload,
    required this.batch,
  });

  static Future<PaperlessUploadEdit?> show(
    BuildContext context, {
    required PaperlessUpload upload,
    required PaperlessUploadOptions batch,
  }) {
    return showModalBottomSheet<PaperlessUploadEdit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PaperlessUploadEditSheet(upload: upload, batch: batch),
    );
  }

  @override
  State<PaperlessUploadEditSheet> createState() =>
      _PaperlessUploadEditSheetState();
}

class _PaperlessUploadEditSheetState extends State<PaperlessUploadEditSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.upload.title ?? '',
  );
  late DateTime? _created = widget.upload.created;
  late int? _correspondentId =
      widget.upload.correspondentId ?? widget.batch.correspondentId;
  late int? _documentTypeId =
      widget.upload.documentTypeId ?? widget.batch.documentTypeId;
  late Set<int> _tagIds = widget.upload.tagIds ?? widget.batch.tagIds;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _created ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _created = picked);
  }

  void _apply() {
    Navigator.of(context).pop<PaperlessUploadEdit>((
      title: _title.text,
      created: _created,
      correspondentId: _correspondentId,
      documentTypeId: _documentTypeId,
      tagIds: _tagIds,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<PaperlessState>();
    final created = _created;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.paperlessEditUpload, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.upload.fileName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: l10n.paperlessUploadTitle,
                hintText: widget.upload.fileName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.paperlessCreated,
                  prefixIcon: const Icon(Icons.event_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: created == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l10n.commonClear,
                          onPressed: () => setState(() => _created = null),
                        ),
                ),
                child: Text(
                  created == null
                      ? l10n.paperlessAutomatic
                      : FormatHelper.dateTime(
                          created,
                          style: DateStyle.dateOnly,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PaperlessLabelDropdown(
              label: l10n.paperlessCorrespondent,
              noneLabel: l10n.paperlessAutomatic,
              icon: Icons.person_outline,
              options: state.correspondents,
              value: _correspondentId,
              onChanged: (id) => setState(() => _correspondentId = id),
            ),
            const SizedBox(height: 12),
            PaperlessLabelDropdown(
              label: l10n.paperlessDocumentType,
              noneLabel: l10n.paperlessAutomatic,
              icon: Icons.category_outlined,
              options: state.documentTypes,
              value: _documentTypeId,
              onChanged: (id) => setState(() => _documentTypeId = id),
            ),
            const SizedBox(height: 12),
            Text(l10n.paperlessTags, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            PaperlessTagSelector(
              tags: state.tags,
              selected: _tagIds,
              onChanged: (ids) => setState(() => _tagIds = ids),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(onPressed: _apply, child: Text(l10n.commonApply)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
