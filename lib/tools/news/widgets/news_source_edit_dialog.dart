import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../news_catalog.dart';
import '../news_l10n.dart';
import '../news_source.dart';
import '../news_state.dart';
import 'news_category_dropdown.dart';

class NewsSourceEditDialog extends StatefulWidget {
  final NewsSource source;

  const NewsSourceEditDialog({super.key, required this.source});

  static Future<bool?> show(BuildContext context, NewsSource source) {
    return showDialog<bool>(
      context: context,
      builder: (_) => NewsSourceEditDialog(source: source),
    );
  }

  @override
  State<NewsSourceEditDialog> createState() => _NewsSourceEditDialogState();
}

class _NewsSourceEditDialogState extends State<NewsSourceEditDialog>
    with DisposeCleanup {
  late final TextEditingController _title;
  late final TextEditingController _url;
  late String _category;
  late bool _enabled;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.source.title);
    _url = TextEditingController(text: widget.source.feedUrl);
    _category = widget.source.category.isEmpty
        ? NewsCatalog.customCategory
        : widget.source.category;
    _enabled = widget.source.enabled;
    onDispose(() {
      _title.dispose();
      _url.dispose();
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<NewsState>();
    final url = _url.text.trim();
    final invalid = newsFeedUrlError(l10n, url);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final existing = await state.sourceByFeedUrl(url);
      if (!mounted) return;
      if (existing != null && existing.shortId != widget.source.shortId) {
        setState(() => _error = l10n.newsSourceExists);
        return;
      }
      final title = _title.text.trim();
      await state.updateSource(
        widget.source.copyWith(
          title: title.isEmpty ? widget.source.title : title,
          feedUrl: url,
          category: _category,
          enabled: _enabled,
        ),
        feedChanged: url != widget.source.feedUrl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      errorLog('[NewsSourceEdit] Failed to save source: $e');
      if (mounted) setState(() => _error = l10n.newsSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Text(l10n.newsEditSource),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: l10n.newsSourceName,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.newsSourceUrl,
              hintText: l10n.newsSourceUrlHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          NewsCategoryDropdown(
            value: _category,
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.newsSourceEnabled),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          if (_error != null)
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonSave),
        ),
      ],
    );
  }
}
